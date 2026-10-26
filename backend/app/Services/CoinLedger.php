<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\CoinTransaction;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * The only place users.coins changes. Every change writes a coin_transactions row with the new balance.
 */
class CoinLedger
{
    /**
     * @param  array{payment_id?:int|null,episode_id?:int|null,actor_id?:int|null}  $refs
     */
    public function credit(User $user, int $amount, string $type, array $refs = [], ?string $description = null): CoinTransaction
    {
        return $this->apply($user, abs($amount), $type, $refs, $description);
    }

    /**
     * Fails with insufficient_coins unless $clamp, in which case it takes what is left (used by refunds).
     *
     * @param  array{payment_id?:int|null,episode_id?:int|null,actor_id?:int|null}  $refs
     */
    public function debit(User $user, int $amount, string $type, array $refs = [], ?string $description = null, bool $clamp = false): CoinTransaction
    {
        return $this->apply($user, -abs($amount), $type, $refs, $description, $clamp);
    }

    /**
     * @param  array{payment_id?:int|null,episode_id?:int|null,actor_id?:int|null}  $refs
     */
    protected function apply(User $user, int $amount, string $type, array $refs, ?string $description, bool $clamp = false): CoinTransaction
    {
        return DB::transaction(function () use ($user, $amount, $type, $refs, $description, $clamp) {
            $locked = User::whereKey($user->id)->lockForUpdate()->firstOrFail();
            $balance = (int) $locked->coins;

            if ($amount < 0 && $balance + $amount < 0) {
                if (! $clamp) {
                    throw new ApiException('Huna coins za kutosha.', 'insufficient_coins', 402);
                }
                $amount = -$balance;
            }

            $locked->coins = $balance + $amount;
            $locked->save();
            $user->coins = $locked->coins;

            return CoinTransaction::create([
                'user_id' => $user->id,
                'amount' => $amount,
                'balance_after' => $locked->coins,
                'type' => $type,
                'payment_id' => $refs['payment_id'] ?? null,
                'episode_id' => $refs['episode_id'] ?? null,
                'actor_id' => $refs['actor_id'] ?? null,
                'description' => $description,
            ]);
        });
    }
}
