<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\Company;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * POST /creator/apply: a viewer becomes a creator ("Wasilisha Kazi Yako").
 * The account can prepare drafts at once; AFRIVA approves the creator before anything can be submitted.
 */
class CreatorController extends Controller
{
    public function apply(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        if ($user->isCompany()) {
            throw new ApiException('Tayari wewe ni mtayarishaji.', 'already_creator', 409);
        }
        if ($user->isSuperAdmin()) {
            throw new ApiException('Akaunti ya msimamizi haiwezi kuwa mtayarishaji.', 'forbidden', 403);
        }
        $data = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'phone' => ['nullable', 'string', 'max:32'],
            'email' => ['nullable', 'email', 'max:190'],
            'country' => ['nullable', 'string', 'size:2'],
            'description' => ['nullable', 'string', 'max:2000'],
        ]);

        DB::transaction(function () use ($user, $data) {
            $base = Str::slug($data['name']) ?: 'mtayarishaji';
            $slug = $base;
            $i = 2;
            while (Company::where('slug', $slug)->exists()) {
                $slug = $base.'-'.$i++;
            }
            $company = Company::create([
                'name' => $data['name'],
                'slug' => $slug,
                'email' => $data['email'] ?? $user->email,
                'phone' => $data['phone'] ?? $user->phone,
                'country' => strtoupper($data['country'] ?? 'TZ'),
                'description' => $data['description'] ?? null,
                'status' => 'pending',
            ]);
            $user->forceFill(['role' => User::ROLE_COMPANY, 'company_id' => $company->id])->save();
        });

        return $this->ok([
            'user' => new UserResource($user->fresh('company')),
            'message' => 'Ombi lako limepokelewa. Unaweza kuanza kuandaa kazi zako; utaweza kuzituma kwa ukaguzi baada ya AFRIVA kuidhinisha akaunti yako.',
        ], null, 201);
    }
}
