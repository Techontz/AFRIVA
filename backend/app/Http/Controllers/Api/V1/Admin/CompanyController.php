<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\StoreCompanyRequest;
use App\Http\Requests\UpdateCompanyRequest;
use App\Http\Resources\CompanyResource;
use App\Models\ApplicationSample;
use App\Models\Company;
use App\Models\Setting;
use App\Models\StudioApplication;
use App\Models\User;
use App\Services\BunnyStream;
use App\Services\ContentService;
use App\Services\StatsService;
use App\Support\MediaStorage;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Response;

class CompanyController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $q = Company::query()->withCount('dramas')->with(['users', 'application.user', 'application.samples'])
            ->withSum('dramas as total_views', 'views')
            ->withSum('earnings as total_earnings', 'amount');
        if ($s = $request->query('q')) {
            $q->where(fn ($w) => $w->where('name', 'like', "%{$s}%")->orWhere('email', 'like', "%{$s}%"));
        }
        if ($status = $request->query('status')) {
            $q->where('status', $status);
        }

        // Applications waiting for review come first.
        $q->orderByRaw("CASE WHEN status = 'pending' THEN 0 ELSE 1 END");

        return $this->paginated($q->orderBy('name')->paginate($this->perPage(50)), CompanyResource::class);
    }

    public function store(StoreCompanyRequest $request, ContentService $content): JsonResponse
    {
        $data = $request->validated();

        $company = DB::transaction(function () use ($data, $request, $content) {
            $slug = $data['slug'] ?? Str::slug($data['name']);
            $base = $slug;
            $i = 2;
            while (Company::where('slug', $slug)->exists()) {
                $slug = $base.'-'.$i++;
            }

            $company = Company::create([
                'name' => $data['name'],
                'slug' => $slug,
                'email' => $data['email'] ?? $data['owner_email'],
                'phone' => $data['phone'] ?? null,
                'country' => isset($data['country']) ? strtoupper($data['country']) : 'TZ',
                'logo_url' => $request->hasFile('logo') ? $content->storeFile($request->file('logo'), 'logos') : ($data['logo_url'] ?? null),
                'revenue_share_percent' => $data['revenue_share_percent'] ?? Setting::creatorShare(),
                'status' => $data['status'] ?? 'active',
                'description' => $data['description'] ?? null,
            ]);

            User::create([
                'name' => $data['owner_name'],
                'email' => $data['owner_email'],
                'phone' => $data['owner_phone'] ?? null,
                'password' => $data['owner_password'],
                'role' => User::ROLE_COMPANY,
                'company_id' => $company->id,
                'status' => 'active',
            ]);

            return $company;
        });

        return $this->ok(new CompanyResource($company->load('users')->loadCount('dramas')), null, 201);
    }

    public function show(Company $company): JsonResponse
    {
        return $this->ok(new CompanyResource($company->load(['users', 'application.user', 'application.samples'])->loadCount('dramas')));
    }

    public function update(UpdateCompanyRequest $request, Company $company, ContentService $content, BunnyStream $bunny): JsonResponse
    {
        $data = $request->validated();
        $application = $company->application()->with('samples')->first();
        if ($application?->status === 'pending' && isset($data['status']) && $data['status'] !== $company->status) {
            // Approval needs 10 ready samples of the right length; rejection needs a reason the applicant sees.
            if ($data['status'] === 'active' && ! $application->readyForReview()) {
                throw new ApiException(__('api.samples_incomplete'), 'samples_incomplete', 422);
            }
            if ($data['status'] === 'rejected' && blank($data['rejection_reason'] ?? null)) {
                throw ValidationException::withMessages(['rejection_reason' => __('validation.required', ['attribute' => __('validation.attributes.rejection_reason')])]);
            }
        }
        $company->fill(collect($data)->except(['owner_password', 'logo', 'rejection_reason'])->all());
        if (isset($data['country'])) {
            $company->country = strtoupper($data['country']);
        }
        if ($request->hasFile('logo')) {
            $company->logo_url = $content->storeFile($request->file('logo'), 'logos');
        }
        $company->save();

        if (! empty($data['owner_password'])) {
            $company->users()->where('role', User::ROLE_COMPANY)->each(fn (User $u) => $u->update(['password' => $data['owner_password']]));
        }
        if (isset($data['status'])) {
            DB::transaction(fn () => $this->applyStatus($company, $data['status'], $request->user(), $data['rejection_reason'] ?? null));
            // Rejected samples are removed from Bunny (best effort); approved ones are kept for the admin.
            if ($data['status'] === 'rejected' && $application) {
                $application->load('samples');
                $bunny->deleteVideos($application->samples->pluck('bunny_video_id'));
                $application->samples()->delete();
            }
        }

        return $this->ok(new CompanyResource($company->load(['users', 'application.user', 'application.samples'])->loadCount('dramas')));
    }

    /**
     * Status change: company logins follow it. Approving a request (active) marks the application approved and,
     * when a viewer applied from their own account, turns that account into the studio owner. Rejecting marks it rejected.
     */
    protected function applyStatus(Company $company, string $status, User $admin, ?string $reason = null): void
    {
        $company->users()->update(['status' => $status]);
        if ($status === 'rejected') {
            $company->users()->each(fn (User $u) => $u->tokens()->delete());
        }

        $application = $company->application()->first();
        if (! $application || ! in_array($status, ['active', 'rejected'], true)) {
            return;
        }
        if ($status === 'active' && $application->status !== 'approved') {
            $application->update(['status' => 'approved', 'reviewed_at' => now(), 'reviewed_by' => $admin->id]);
            $owner = $application->user;
            if ($application->existing_user && $owner && $owner->role === User::ROLE_VIEWER) {
                $owner->update(['role' => User::ROLE_COMPANY, 'company_id' => $company->id, 'status' => 'active']);
            }
        }
        if ($status === 'rejected' && $application->status === 'pending') {
            $application->update(['status' => 'rejected', 'rejection_reason' => $reason, 'reviewed_at' => now(), 'reviewed_by' => $admin->id]);
        }
    }

    /** Super admin only: the request's sample videos with short-lived signed playback URLs. */
    public function samples(Company $company, BunnyStream $bunny): JsonResponse
    {
        $application = $company->application()->with('samples')->first();
        abort_unless($application, 404);

        return $this->ok([
            'review_status' => $application->reviewStatus(),
            'samples_summary' => $application->samplesSummary(),
            'samples' => $application->samples->map(fn (ApplicationSample $s) => $s->toPublicArray() + [
                'playback_url' => $s->status === 'ready' && $s->bunny_video_id && $bunny->cdnHostname() !== ''
                    ? $bunny->signedPlaylistUrl($s->bunny_video_id) : null,
            ])->values(),
        ]);
    }

    /**
     * Super admin only: the uploaded ID photo of a request to post (private disk, never public).
     * Local disk: streamed through the API as before. Cloud disk (private R2 bucket): a signed URL that expires
     * after PRIVATE_DOCUMENT_URL_TTL_MINUTES (default 10), as a 302 redirect, or as JSON with ?as=url so the
     * admin page can show it in an <img>/<iframe> without needing CORS on the bucket.
     */
    public function idDocument(Request $request, Company $company): Response
    {
        $path = $company->application()->value('id_document_path');
        $diskName = StudioApplication::disk();
        $disk = Storage::disk($diskName);
        abort_unless($path && $disk->exists($path), 404);

        $filename = 'id-document-'.$company->id.'.'.pathinfo($path, PATHINFO_EXTENSION);
        $noStore = ['Cache-Control' => 'private, no-store, max-age=0', 'X-Content-Type-Options' => 'nosniff'];

        if (MediaStorage::isLocal($diskName)) {
            return $disk->response($path, $filename, $noStore);
        }

        $ttl = MediaStorage::privateUrlTtlMinutes();
        $expires = now()->addMinutes($ttl);
        $url = $disk->temporaryUrl($path, $expires, [
            'ResponseContentDisposition' => 'inline; filename="'.$filename.'"',
            'ResponseCacheControl' => 'private, no-store, max-age=0',
        ]);

        if ($request->query('as') === 'url') {
            return $this->ok([
                'url' => $url,
                'expires_at' => $expires->toIso8601String(),
                'pdf' => strtolower(pathinfo($path, PATHINFO_EXTENSION)) === 'pdf',
            ])->withHeaders($noStore);
        }

        return redirect()->away($url)->withHeaders($noStore);
    }

    public function destroy(Company $company): JsonResponse
    {
        DB::transaction(function () use ($company) {
            $company->users()->where('role', User::ROLE_COMPANY)->each(function (User $u) {
                $u->tokens()->delete();
                $u->delete();
            });
            $paths = $company->application()->whereNotNull('id_document_path')->pluck('id_document_path')->all();
            $guids = ApplicationSample::whereIn('studio_application_id', $company->application()->select('id'))->pluck('bunny_video_id')->all();
            app(BunnyStream::class)->deleteVideos($guids);
            $company->delete();
            if ($paths) {
                Storage::disk(StudioApplication::disk())->delete($paths);
            }
        });

        return $this->ok(['deleted' => true]);
    }

    public function stats(Company $company, StatsService $stats): JsonResponse
    {
        return $this->ok($stats->companyStats($company));
    }
}
