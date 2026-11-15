<?php

namespace App\Services\Infra\Providers;

/**
 * Hetzner Cloud API (docs.hetzner.cloud): server type, status and the type's LIST price for the server's
 * location. Hetzner has no billing API, so the price is an estimate, not an invoice.
 */
class HetznerProvider extends Provider
{
    public const BASE = 'https://api.hetzner.cloud/v1';

    public function key(): string
    {
        return 'hetzner';
    }

    public function source(): string
    {
        return 'Hetzner Cloud API';
    }

    public function configured(): bool
    {
        return filled(config('infra.hetzner.token')) && filled(config('infra.hetzner.server_id'));
    }

    public function requiredEnv(): array
    {
        return ['HETZNER_API_TOKEN', 'HETZNER_SERVER_ID'];
    }

    public function collect(): array
    {
        $api = $this->http()->withToken((string) config('infra.hetzner.token'));
        $server = $api->get(self::BASE.'/servers/'.rawurlencode((string) config('infra.hetzner.server_id')))
            ->throw()->json('server') ?? [];

        $type = $server['server_type'] ?? [];
        // server.location replaced server.datacenter.location (removed by Hetzner on 2026-10-01); accept both.
        $location = $server['location']['name'] ?? $server['datacenter']['location']['name'] ?? null;
        $price = collect($type['prices'] ?? [])->firstWhere('location', $location) ?? ($type['prices'][0] ?? null);
        $monthlyGross = isset($price['price_monthly']['gross']) ? (float) $price['price_monthly']['gross'] : null;
        $monthlyNet = isset($price['price_monthly']['net']) ? (float) $price['price_monthly']['net'] : null;

        $backups = ! empty($server['backup_window']);
        $backupPercent = (float) config('infra.hetzner.backup_percent', 20);
        if ($backups) {
            try {
                $pct = $api->get(self::BASE.'/pricing')->throw()->json('pricing.server_backup.percentage');
                $backupPercent = is_numeric($pct) ? (float) $pct : $backupPercent;
            } catch (\Throwable) {
                // keep the configured percentage
            }
        }

        return [
            'name' => $server['name'] ?? null,
            'status' => $server['status'] ?? null,
            'server_type' => $type['name'] ?? null,
            'cores' => $type['cores'] ?? null,
            'memory_gb' => $type['memory'] ?? null,
            'disk_gb' => $type['disk'] ?? null,
            'location' => $location,
            'backups_enabled' => $backups,
            'backup_percent' => $backups ? $backupPercent : 0,
            'currency' => 'EUR',
            'price_monthly_net_eur' => $monthlyNet,
            'price_monthly_gross_eur' => $monthlyGross,
            'included_traffic_tb' => isset($price['included_traffic']) ? round($price['included_traffic'] / 1_000_000_000_000, 1) : null,
        ];
    }
}
