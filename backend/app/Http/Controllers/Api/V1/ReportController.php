<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ContentReport;
use App\Models\Drama;
use App\Support\Viewer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** POST /dramas/{id}/report (auth optional): "Ripoti ukiukaji": copyright or content problems with a series. */
class ReportController extends Controller
{
    public function store(Request $request, int $id): JsonResponse
    {
        $drama = Drama::published()->findOrFail($id);
        $data = $request->validate([
            'reason' => ['required', Rule::in(ContentReport::REASONS)],
            'episode_id' => ['nullable', 'integer', Rule::exists('episodes', 'id')->where('drama_id', $drama->id)],
            'details' => ['required_if:reason,copyright', 'nullable', 'string', 'max:3000'],
            'contact' => ['nullable', 'string', 'max:190'],
        ]);

        $report = ContentReport::create($data + ['drama_id' => $drama->id, 'user_id' => Viewer::user()?->id, 'status' => 'open']);

        return $this->ok([
            'id' => $report->id,
            'message' => 'Asante. Ripoti yako imepokelewa na timu ya AFRIVA itaikagua.',
        ], null, 201);
    }
}
