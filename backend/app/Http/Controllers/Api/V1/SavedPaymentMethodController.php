<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\SavedPaymentMethodResource;
use App\Models\PaymentMethod;
use App\Models\SavedPaymentMethod;
use App\Payments\MobileNetwork;
use App\Payments\PaymentManager;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * The viewer's saved ways to pay, and what checkout can offer right now.
 */
class SavedPaymentMethodController extends Controller
{
    public function __construct(protected PaymentManager $manager) {}

    /** GET /checkout/options (public): which channels can take payments, and the networks behind mobile money. */
    public function options(): JsonResponse
    {
        $methods = PaymentMethod::where('is_enabled', true)->whereIn('type', ['mobile_money', 'card'])->orderBy('sort_order')->get();
        $describe = fn (PaymentMethod $m) => ['code' => $m->code, 'name' => $m->name, 'available' => $this->manager->isAvailable($m->code)];
        $mobile = $methods->where('type', 'mobile_money')->map($describe)->values();
        $cards = $methods->where('type', 'card')->map($describe)->values();

        return $this->ok([
            'mobile_money' => ['available' => $mobile->contains('available', true), 'networks' => $mobile],
            'card' => ['available' => $cards->contains('available', true), 'brands' => $cards],
            'demo' => (bool) config('payments.sandbox.auto_approve'),
        ]);
    }

    public function index(Request $request): JsonResponse
    {
        $items = SavedPaymentMethod::with('method')->where('user_id', $request->user()->id)
            ->orderByDesc('is_default')->orderByDesc('last_used_at')->orderByDesc('id')->get();

        return $this->ok(SavedPaymentMethodResource::collection($items));
    }

    /** POST /me/payment-methods: add a mobile money number. Cards are saved when a payment with them succeeds. */
    public function store(Request $request): JsonResponse
    {
        $request->validate(['phone' => ['required', 'string', 'max:32']]);
        $phone = MobileNetwork::normalize($request->input('phone'))
            ?? throw ValidationException::withMessages(['phone' => [__('payments.phone_invalid')]]);
        $code = MobileNetwork::methodFor($phone)
            ?? throw ValidationException::withMessages(['phone' => [__('payments.network_unknown')]]);

        $saved = SavedPaymentMethod::remember($request->user(), ['type' => 'mobile_money', 'method_code' => $code, 'phone' => $phone]);

        return $this->ok(new SavedPaymentMethodResource($saved->load('method')), null, 201);
    }

    /** PATCH /me/payment-methods/{id}: make it the default. */
    public function update(Request $request, int $id): JsonResponse
    {
        $saved = $this->owned($request, $id);
        $saved->makeDefault();

        return $this->ok(new SavedPaymentMethodResource($saved->fresh('method')));
    }

    public function destroy(Request $request, int $id): JsonResponse
    {
        $saved = $this->owned($request, $id);
        $wasDefault = $saved->is_default;
        $saved->delete();
        if ($wasDefault) {
            SavedPaymentMethod::where('user_id', $request->user()->id)->orderByDesc('last_used_at')->first()?->makeDefault();
        }

        return $this->ok(['deleted' => true]);
    }

    protected function owned(Request $request, int $id): SavedPaymentMethod
    {
        return SavedPaymentMethod::where('user_id', $request->user()->id)->findOrFail($id);
    }
}
