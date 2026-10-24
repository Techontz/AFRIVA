<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\CategoryRequest;
use App\Http\Resources\CategoryResource;
use App\Models\Category;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Str;

class CategoryController extends Controller
{
    public function index(): JsonResponse
    {
        return $this->ok(CategoryResource::collection(Category::withCount('dramas')->orderBy('sort_order')->orderBy('name')->get()));
    }

    public function store(CategoryRequest $request): JsonResponse
    {
        $data = $request->validated();
        $data['slug'] = $data['slug'] ?? Str::slug($data['name']);
        abort_if(Category::where('slug', $data['slug'])->exists(), 409, 'A category with this slug already exists.');
        $category = Category::create($data);

        return $this->ok(new CategoryResource($category), null, 201);
    }

    public function show(Category $category): JsonResponse
    {
        return $this->ok(new CategoryResource($category->loadCount('dramas')));
    }

    public function update(CategoryRequest $request, Category $category): JsonResponse
    {
        $category->update($request->validated());

        return $this->ok(new CategoryResource($category));
    }

    public function destroy(Category $category): JsonResponse
    {
        $category->delete();

        return $this->ok(['deleted' => true]);
    }
}
