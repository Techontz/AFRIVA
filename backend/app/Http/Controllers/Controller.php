<?php

namespace App\Http\Controllers;

use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Http\JsonResponse;

abstract class Controller
{
    /** Standard envelope: { data, meta? } */
    protected function ok(mixed $data, ?array $meta = null, int $status = 200): JsonResponse
    {
        $body = ['data' => $data];
        if ($meta !== null) {
            $body['meta'] = $meta;
        }

        return response()->json($body, $status);
    }

    /** Paginated envelope: { data: [...], meta: { current_page, last_page, per_page, total } } */
    protected function paginated(LengthAwarePaginator $paginator, string $resourceClass, array $extraMeta = []): JsonResponse
    {
        return $this->ok($resourceClass::collection($paginator->getCollection()), array_merge([
            'current_page' => $paginator->currentPage(),
            'last_page' => $paginator->lastPage(),
            'per_page' => $paginator->perPage(),
            'total' => $paginator->total(),
        ], $extraMeta));
    }

    protected function perPage(int $default = 20, int $max = 100): int
    {
        return max(1, min($max, (int) request('per_page', $default)));
    }
}
