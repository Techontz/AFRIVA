<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuditLogController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $q = AuditLog::with('user:id,name,email,staff_role');
        if ($action = $request->query('action')) {
            $q->where('action', 'like', str_replace(['%', '_'], ['\%', '\_'], $action).'%');
        }
        if ($userId = $request->query('user_id')) {
            $q->where('user_id', $userId);
        }
        if ($type = $request->query('subject_type')) {
            $q->where('subject_type', $type);
        }
        $page = $q->latest('id')->paginate($this->perPage(50));

        return $this->ok($page->getCollection()->map(fn (AuditLog $l) => [
            'id' => $l->id,
            'action' => $l->action,
            'subject_type' => $l->subject_type,
            'subject_id' => $l->subject_id,
            'summary' => $l->summary,
            'changes' => $l->changes,
            'ip' => $l->ip,
            'user' => $l->user ? ['id' => $l->user->id, 'name' => $l->user->name, 'email' => $l->user->email, 'staff_role' => $l->user->staff_role] : null,
            'created_at' => $l->created_at?->toIso8601String(),
        ])->values(), [
            'current_page' => $page->currentPage(), 'last_page' => $page->lastPage(), 'per_page' => $page->perPage(), 'total' => $page->total(),
        ]);
    }
}
