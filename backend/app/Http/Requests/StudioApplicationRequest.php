<?php

namespace App\Http\Requests;

use App\Models\Company;
use App\Models\StudioApplication;
use App\Models\User;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

/**
 * "Request to post": one short form for everyone.
 * Logged-in viewers send no email/password. Guests send email + password; if that email is an existing
 * viewer account, its password must match and the application is attached to that account.
 */
class StudioApplicationRequest extends FormRequest
{
    private ?User $existing = null;

    public function authorize(): bool
    {
        return true;
    }

    /** The logged-in user (bearer token is optional on this endpoint). */
    public function authUser(): ?User
    {
        $user = auth('sanctum')->user();

        return $user instanceof User ? $user : null;
    }

    /** The viewer account the application attaches to (logged in, or matched by email + password). */
    public function viewerAccount(): ?User
    {
        return $this->authUser() ?? $this->existing;
    }

    protected function prepareForValidation(): void
    {
        // Older clients sent owner_name / company_name.
        $this->merge([
            'full_name' => $this->input('full_name', $this->input('owner_name')),
            'studio_name' => $this->input('studio_name', $this->input('company_name')),
            'email' => is_string($this->input('email')) ? strtolower(trim($this->input('email'))) : $this->input('email'),
        ]);
    }

    public function rules(): array
    {
        $guest = $this->authUser() === null;

        return [
            'full_name' => ['required', 'string', 'min:3', 'max:150'],
            'studio_name' => ['nullable', 'string', 'max:150'],
            'id_type' => ['required', Rule::in(StudioApplication::ID_TYPES)],
            'id_number' => ['nullable', 'required_without:id_document', 'string', 'min:4', 'max:40', 'regex:/^[A-Za-z0-9\- ]+$/'],
            'id_document' => ['nullable', 'required_without:id_number', 'file', 'mimes:jpg,jpeg,png,pdf', 'max:8192'],
            'phone' => ['required', 'string', 'min:9', 'max:32', 'regex:/^\+?[0-9 ]+$/'],
            'payout_method' => ['required', Rule::in(Company::PAYOUT_METHODS)],
            'payout_provider' => ['nullable', 'required_if:payout_method,mobile_money', Rule::in(Company::PAYOUT_PROVIDERS)],
            'payout_bank_name' => ['nullable', 'required_if:payout_method,bank', 'string', 'max:120'],
            'payout_account_name' => ['required', 'string', 'max:150'],
            'payout_account_number' => ['required', 'string', 'max:60', 'regex:/^[A-Za-z0-9\- +]+$/'],
            'guidelines_accepted' => ['accepted'],
            'country' => ['nullable', 'string', 'size:2'],
            'description' => ['nullable', 'string', 'max:2000'],
            'portfolio_url' => ['nullable', 'url', 'max:500'],
            'email' => $guest ? ['required', 'email', 'max:190'] : ['prohibited'],
            'password' => $guest ? ['required', 'string', 'min:8', 'max:190'] : ['prohibited'],
        ];
    }

    public function messages(): array
    {
        return [
            'id_number.required_without' => __('api.creator_id_required'),
            'id_document.required_without' => __('api.creator_id_required'),
            'guidelines_accepted.accepted' => __('api.creator_guidelines_required'),
        ];
    }

    public function after(): array
    {
        return [function (Validator $validator) {
            if ($validator->errors()->isNotEmpty()) {
                return;
            }
            $viewer = $this->authUser();
            if (! $viewer) {
                $match = User::where('email', $this->input('email'))->first();
                if ($match) {
                    if ($match->role !== User::ROLE_VIEWER || $match->status !== 'active') {
                        $validator->errors()->add('email', __('api.creator_email_taken'));

                        return;
                    }
                    if (! Hash::check((string) $this->input('password'), $match->password)) {
                        $validator->errors()->add('password', __('api.creator_password_mismatch'));

                        return;
                    }
                    $this->existing = $viewer = $match;
                }
            }
            if ($viewer && StudioApplication::where('user_id', $viewer->id)->where('status', 'pending')->exists()) {
                $validator->errors()->add('full_name', __('api.creator_application_exists'));
            }
        }];
    }
}
