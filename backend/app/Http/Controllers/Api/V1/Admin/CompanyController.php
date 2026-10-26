<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreCompanyRequest;
use App\Http\Requests\UpdateCompanyRequest;
use App\Http\Resources\CompanyResource;
use App\Models\AuditLog;
use App\Models\Company;
use App\Models\User;
use App\Services\ContentService;
use App\Services\StatsService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class CompanyController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $q = Company::query()->withCount('dramas')->with('users')
            ->withSum('dramas as total_views', 'views')
            ->withSum('earnings as total_earnings', 'amount');
        if ($s = $request->query('q')) {
            $q->where(fn ($w) => $w->where('name', 'like', "%{$s}%")->orWhere('email', 'like', "%{$s}%"));
        }
        if ($status = $request->query('status')) {
            $q->where('status', $status);
        }

        return $this->paginated($q->orderByRaw("status = 'pending' DESC")->orderBy('name')->paginate($this->perPage(50)), CompanyResource::class, [
            'pending' => Company::where('status', 'pending')->count(),
        ]);
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
                'revenue_share_percent' => $data['revenue_share_percent'] ?? 70,
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

        AuditLog::record('creator.create', $company, null, $company->name);

        return $this->ok(new CompanyResource($company->load('users')->loadCount('dramas')), null, 201);
    }

    public function show(Company $company): JsonResponse
    {
        return $this->ok(new CompanyResource($company->load('users')->loadCount('dramas')));
    }

    public function update(UpdateCompanyRequest $request, Company $company, ContentService $content): JsonResponse
    {
        $data = $request->validated();
        $company->fill(collect($data)->except(['owner_password', 'logo'])->all());
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
        // Creator accounts follow suspension; a pending creator can still log in and prepare drafts.
        if (in_array($data['status'] ?? null, ['active', 'suspended'], true)) {
            $company->users()->update(['status' => $data['status']]);
        }
        if ($diff = AuditLog::diff($company, ['name', 'status', 'revenue_share_percent'])) {
            AuditLog::record(isset($diff['status']) && $diff['status']['to'] === 'active' ? 'creator.approve' : 'creator.update', $company, $diff, $company->name);
        }

        return $this->ok(new CompanyResource($company->load('users')->loadCount('dramas')));
    }

    public function destroy(Company $company): JsonResponse
    {
        DB::transaction(function () use ($company) {
            $company->users()->where('role', User::ROLE_COMPANY)->each(function (User $u) {
                $u->tokens()->delete();
                $u->delete();
            });
            $company->delete();
        });
        AuditLog::record('creator.delete', $company, null, $company->name);

        return $this->ok(['deleted' => true]);
    }

    public function stats(Company $company, StatsService $stats): JsonResponse
    {
        return $this->ok($stats->companyStats($company));
    }
}
