<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\StudioApplicationRequest;
use App\Models\Company;
use App\Models\Setting;
use App\Models\StudioApplication;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * "Request to post" (self-service studio sign-up). Creates a pending company plus its application.
 * Guests get a pending company login; viewers keep their account and become the studio owner on approval.
 * A super admin approves or rejects in Admin > Companies.
 */
class StudioApplicationController extends Controller
{
    /** Public: the current revenue split shown in the creator guidelines. */
    public function guidelines(): JsonResponse
    {
        return $this->ok(Setting::revenueSplit());
    }

    public function store(StudioApplicationRequest $request): JsonResponse
    {
        $auth = $request->authUser();
        if ($auth && $auth->role !== User::ROLE_VIEWER) {
            throw new ApiException(__('api.creator_already_studio'), 'already_studio', 422);
        }
        $viewer = $request->viewerAccount();
        $data = $request->validated();
        $share = Setting::creatorShare();
        $documentPath = $request->hasFile('id_document')
            ? $request->file('id_document')->store('id-documents', StudioApplication::disk())
            : null;

        try {
            [$company, $application] = DB::transaction(function () use ($data, $viewer, $share, $documentPath) {
                $name = trim((string) ($data['studio_name'] ?? '')) ?: $data['full_name'];
                $base = Str::slug($name) ?: 'studio';
                $slug = $base;
                for ($i = 2; Company::where('slug', $slug)->exists(); $i++) {
                    $slug = $base.'-'.$i;
                }
                $description = trim(($data['description'] ?? '').(! empty($data['portfolio_url']) ? "\n\n".$data['portfolio_url'] : ''));
                $mobile = $data['payout_method'] === 'mobile_money';

                $company = Company::create([
                    'name' => $name,
                    'slug' => $slug,
                    'email' => $viewer?->email ?? $data['email'],
                    'phone' => $data['phone'],
                    'country' => strtoupper($data['country'] ?? 'TZ'),
                    'revenue_share_percent' => $share,
                    'status' => 'pending',
                    'description' => $description ?: null,
                    'payout_method' => $data['payout_method'],
                    'payout_provider' => $mobile ? $data['payout_provider'] : null,
                    'payout_bank_name' => $mobile ? null : $data['payout_bank_name'],
                    'payout_account_name' => $data['payout_account_name'],
                    'payout_account_number' => $data['payout_account_number'],
                ]);

                $user = $viewer ?? User::create([
                    'name' => $data['full_name'],
                    'email' => $data['email'],
                    'phone' => User::where('phone', $data['phone'])->exists() ? null : $data['phone'],
                    'password' => $data['password'],
                    'role' => User::ROLE_COMPANY,
                    'company_id' => $company->id,
                    'status' => 'pending',
                ]);

                $application = StudioApplication::create([
                    'company_id' => $company->id,
                    'user_id' => $user->id,
                    'existing_user' => $viewer !== null,
                    'full_name' => $data['full_name'],
                    'id_type' => $data['id_type'],
                    'id_number' => isset($data['id_number']) ? strtoupper(trim($data['id_number'])) : null,
                    'id_document_path' => $documentPath,
                    'phone' => $data['phone'],
                    'guidelines_accepted_at' => now(),
                    'creator_share_percent' => $share,
                    'status' => 'pending',
                ]);

                return [$company, $application];
            });
        } catch (\Throwable $e) {
            if ($documentPath) {
                Storage::disk(StudioApplication::disk())->delete($documentPath);
            }
            throw $e;
        }

        return $this->ok([
            'status' => 'pending',
            'existing_user' => $application->existing_user,
            'company' => ['id' => $company->id, 'name' => $company->name],
        ], ['message' => __('api.studio_application_received')], 201);
    }
}
