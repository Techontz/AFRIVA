<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Support\Str;

class Tag extends Model
{
    protected $fillable = ['name', 'slug'];

    public function dramas(): BelongsToMany
    {
        return $this->belongsToMany(Drama::class);
    }

    /** @param  array<int,string>  $names
     *  @return array<int,int> tag ids */
    public static function idsFor(array $names): array
    {
        $ids = [];
        foreach ($names as $name) {
            $name = trim((string) $name);
            if ($name === '') {
                continue;
            }
            $ids[] = static::firstOrCreate(['slug' => Str::slug($name)], ['name' => $name])->id;
        }

        return array_values(array_unique($ids));
    }
}
