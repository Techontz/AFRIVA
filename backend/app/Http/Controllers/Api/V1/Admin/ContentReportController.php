<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\ContentReport;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Viewer reports (copyright / content problems) for staff to resolve. */
class ContentReportController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $q = ContentReport::with(['drama:id,title,slug,poster_url,status', 'episode:id,number', 'user:id,name,email', 'resolver:id,name']);
        if ($status = $request->query('status', 'open')) {
            if ($status !== 'all') {
                $q->where('status', $status);
            }
        }
        $page = $q->latest()->paginate($this->perPage(25));

        return $this->ok($page->getCollection()->map(fn (ContentReport $r) => $this->row($r))->values(), [
            'current_page' => $page->currentPage(), 'last_page' => $page->lastPage(), 'per_page' => $page->perPage(), 'total' => $page->total(),
            'open' => ContentReport::where('status', 'open')->count(),
        ]);
    }

    /** PUT /admin/reports/{id} {status: resolved|dismissed, resolution_notes?} */
    public function update(Request $request, int $report): JsonResponse
    {
        $data = $request->validate([
            'status' => ['required', 'in:open,resolved,dismissed'],
            'resolution_notes' => ['nullable', 'string', 'max:3000'],
        ]);
        $model = ContentReport::findOrFail($report);
        $model->fill($data);
        $model->resolved_by = $data['status'] === 'open' ? null : $request->user()->id;
        $model->resolved_at = $data['status'] === 'open' ? null : now();
        $model->save();
        AuditLog::record('report.'.$data['status'], $model, ['reason' => $model->reason], $model->drama?->title);

        return $this->ok($this->row($model->load(['drama', 'episode', 'user', 'resolver'])));
    }

    /** @return array<string,mixed> */
    protected function row(ContentReport $r): array
    {
        return [
            'id' => $r->id,
            'reason' => $r->reason,
            'details' => $r->details,
            'contact' => $r->contact,
            'status' => $r->status,
            'drama' => $r->drama ? ['id' => $r->drama->id, 'title' => $r->drama->title, 'slug' => $r->drama->slug, 'poster_url' => $r->drama->poster_url, 'status' => $r->drama->status] : null,
            'episode_number' => $r->episode?->number,
            'user' => $r->user ? ['id' => $r->user->id, 'name' => $r->user->name, 'email' => $r->user->email] : null,
            'resolution_notes' => $r->resolution_notes,
            'resolved_by' => $r->resolver?->name,
            'resolved_at' => $r->resolved_at?->toIso8601String(),
            'created_at' => $r->created_at?->toIso8601String(),
        ];
    }
}
