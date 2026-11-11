<?php

namespace App\Payments;

/**
 * Tanzanian mobile money numbers: normalising and telling the network from the prefix, so a viewer only
 * types their number and the right gateway is picked for them.
 */
final class MobileNetwork
{
    /** Number prefix after 255 (e.g. 74 in 255 74x xxx xxx) => payment method code. */
    public const PREFIXES = [
        '74' => 'mpesa', '75' => 'mpesa', '76' => 'mpesa', '79' => 'mpesa',
        '68' => 'airtelmoney', '69' => 'airtelmoney', '78' => 'airtelmoney',
        '65' => 'tigopesa', '67' => 'tigopesa', '71' => 'tigopesa', '77' => 'tigopesa',
        '61' => 'halopesa', '62' => 'halopesa',
        '73' => 'tpesa',
    ];

    /** "0754 123 456", "+255754123456", "754123456" => "255754123456"; null when it is not a TZ mobile number. */
    public static function normalize(?string $phone): ?string
    {
        $digits = preg_replace('/\D+/', '', (string) $phone);
        if (preg_match('/^0(\d{9})$/', $digits, $m)) {
            $digits = '255'.$m[1];
        } elseif (preg_match('/^\d{9}$/', $digits)) {
            $digits = '255'.$digits;
        }

        return preg_match('/^255[67]\d{8}$/', $digits) ? $digits : null;
    }

    /** Payment method code for a normalised number, or null for an unknown prefix. */
    public static function methodFor(string $normalized): ?string
    {
        return self::PREFIXES[substr($normalized, 3, 2)] ?? null;
    }
}
