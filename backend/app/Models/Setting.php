<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Setting extends Model
{
    protected $fillable = ['key', 'value'];

    public const DEFAULTS = [
        'platform_name' => 'Afriva',
        'support_email' => 'support@afriva.com',
        'default_currency' => 'TZS',
        'coin_value_tzs' => '10',
        'default_free_episodes' => '8',
        'default_coins_per_episode' => '30',
        // Streaming cost estimate: average delivered bitrate × watch time × price per GB.
        'streaming_avg_kbps' => '1200',
        'streaming_cost_per_gb_tzs' => '230',
        // Month-to-date costs (estimated streaming + entered operating costs) above this raise an alert; 0 = off.
        'cost_alert_monthly_tzs' => '0',
        'creator_agreement_version' => '2026-1',
        'creator_agreement_text' => "Mkataba wa Mapato wa Watayarishaji wa AFRIVA\n\n1. Unathibitisha kuwa una haki zote (umiliki au leseni) za kila series, episode, picha, muziki na trailer unazotuma.\n2. AFRIVA itakagua kila kazi kabla ya kuichapisha, na inaweza kuomba marekebisho au kuikataa.\n3. Mapato ya episode zinazofunguliwa kwa coins, vifurushi vya episodes na sehemu ya VIP yanagawanywa kwa asilimia ya mgao iliyo kwenye akaunti yako.\n4. Malipo kwa mtayarishaji hufanywa baada ya kutoa refunds na ada za watoa huduma za malipo.\n5. Ukiukaji wa haki za wengine unaweza kusababisha kazi kuondolewa na akaunti kusimamishwa.",
    ];

    public static function get(string $key, mixed $default = null): mixed
    {
        $value = static::where('key', $key)->value('value');

        return $value ?? ($default ?? (self::DEFAULTS[$key] ?? null));
    }

    public static function put(string $key, mixed $value): void
    {
        static::updateOrCreate(['key' => $key], ['value' => is_scalar($value) || $value === null ? $value : json_encode($value)]);
    }

    /** @return array<string,mixed> */
    public static function allAsArray(): array
    {
        return array_merge(self::DEFAULTS, static::pluck('value', 'key')->all());
    }
}
