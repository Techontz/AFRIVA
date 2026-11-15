<?php

namespace App\Services\Infra\Providers;

use Throwable;

/**
 * Cloudflare R2 (developers.cloudflare.com). Account storage from GET /accounts/{id}/r2/metrics, per bucket
 * storage and this month's operations from the GraphQL Analytics API (r2StorageAdaptiveGroups,
 * r2OperationsAdaptiveGroups). Token permissions: Account Analytics Read and Workers R2 Storage Read.
 */
class R2Provider extends Provider
{
    public const API = 'https://api.cloudflare.com/client/v4';

    /** Class A (mutating/listing) operations per the R2 pricing page; other non-free actions count as Class B. */
    public const CLASS_A = ['ListBuckets', 'PutBucket', 'ListObjects', 'PutObject', 'CopyObject', 'CompleteMultipartUpload',
        'CreateMultipartUpload', 'LifecycleStorageTierTransition', 'ListMultipartUploads', 'UploadPart', 'UploadPartCopy',
        'ListParts', 'PutBucketEncryption', 'PutBucketCors', 'PutBucketLifecycleConfiguration'];

    public const FREE = ['DeleteObject', 'DeleteBucket', 'AbortMultipartUpload', 'DeleteObjects'];

    public function key(): string
    {
        return 'r2';
    }

    public function source(): string
    {
        return 'Cloudflare API';
    }

    public function configured(): bool
    {
        return filled(config('infra.r2.api_token')) && filled(config('infra.r2.account_id'));
    }

    public function requiredEnv(): array
    {
        return ['CLOUDFLARE_API_TOKEN', 'CLOUDFLARE_ACCOUNT_ID'];
    }

    public function collect(): array
    {
        $account = (string) config('infra.r2.account_id');
        $api = $this->http()->withToken((string) config('infra.r2.api_token'));

        $metrics = $api->get(self::API.'/accounts/'.rawurlencode($account).'/r2/metrics')->throw()->json('result') ?? [];
        $storage = 0;
        $objects = 0;
        foreach (['standard', 'infrequentAccess'] as $class) {
            $published = $metrics[$class]['published'] ?? [];
            $storage += (int) ($published['payloadSize'] ?? 0) + (int) ($published['metadataSize'] ?? 0);
            $objects += (int) ($published['objects'] ?? 0);
        }

        $out = [
            'storage_bytes' => $storage,
            'object_count' => $objects,
            'buckets' => [],
            'class_a_month' => null,
            'class_b_month' => null,
        ];

        try {
            $out = array_merge($out, $this->graphql($api, $account));
        } catch (Throwable $e) {
            $out['partial_errors'] = ['analytics' => class_basename($e)];
        }

        return $out;
    }

    /** @return array<string,mixed> */
    protected function graphql($api, string $account): array
    {
        $query = <<<'GQL'
query R2Usage($accountTag: string!, $since: Time, $until: Time, $monthStart: Time) {
  viewer {
    accounts(filter: { accountTag: $accountTag }) {
      storage: r2StorageAdaptiveGroups(limit: 1000, filter: { datetime_geq: $since, datetime_leq: $until }, orderBy: [datetime_DESC]) {
        max { objectCount payloadSize metadataSize }
        dimensions { bucketName datetime }
      }
      operations: r2OperationsAdaptiveGroups(limit: 1000, filter: { datetime_geq: $monthStart, datetime_leq: $until }) {
        sum { requests }
        dimensions { actionType }
      }
    }
  }
}
GQL;
        $res = $api->post(self::API.'/graphql', [
            'query' => $query,
            'variables' => [
                'accountTag' => $account,
                'since' => now()->subDay()->utc()->toIso8601ZuluString(),
                'until' => now()->utc()->toIso8601ZuluString(),
                'monthStart' => now()->startOfMonth()->utc()->toIso8601ZuluString(),
            ],
        ])->throw()->json();
        if (! empty($res['errors'])) {
            throw new \RuntimeException('GraphQL error');
        }
        $acc = $res['data']['viewer']['accounts'][0] ?? [];

        // Latest sample per bucket (rows are newest first).
        $buckets = [];
        foreach ($acc['storage'] ?? [] as $row) {
            $name = $row['dimensions']['bucketName'] ?? null;
            if ($name === null || isset($buckets[$name])) {
                continue;
            }
            $buckets[$name] = [
                'name' => $name,
                'storage_bytes' => (int) ($row['max']['payloadSize'] ?? 0) + (int) ($row['max']['metadataSize'] ?? 0),
                'object_count' => (int) ($row['max']['objectCount'] ?? 0),
            ];
        }
        $wanted = (array) config('infra.r2.buckets', []);
        if ($wanted) {
            // Configured buckets first (an empty bucket has no analytics rows yet), then any others.
            $ordered = [];
            foreach ($wanted as $name) {
                $ordered[$name] = $buckets[$name] ?? ['name' => $name, 'storage_bytes' => 0, 'object_count' => 0];
            }
            $buckets = $ordered + $buckets;
        }

        $classA = 0;
        $classB = 0;
        foreach ($acc['operations'] ?? [] as $row) {
            $action = (string) ($row['dimensions']['actionType'] ?? '');
            $n = (int) ($row['sum']['requests'] ?? 0);
            if (in_array($action, self::FREE, true)) {
                continue;
            }
            in_array($action, self::CLASS_A, true) ? $classA += $n : $classB += $n;
        }

        return ['buckets' => array_values($buckets), 'class_a_month' => $classA, 'class_b_month' => $classB];
    }
}
