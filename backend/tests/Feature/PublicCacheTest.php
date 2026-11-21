<?php

namespace Tests\Feature;

class PublicCacheTest extends ApiTestCase
{
    public function test_anonymous_catalogue_answers_are_publicly_cacheable(): void
    {
        $res = $this->getJson('/api/v1/home')->assertOk();
        $this->assertStringContainsString('public', $res->headers->get('Cache-Control'));
        $this->assertStringContainsString('max-age=60', $res->headers->get('Cache-Control'));
        $this->assertStringContainsString('Authorization', (string) $res->headers->get('Vary'));
    }

    public function test_signed_in_answers_and_playback_stay_private(): void
    {
        $token = $this->tokenFor($this->viewer());
        $res = $this->withToken($token)->getJson('/api/v1/home')->assertOk();
        $this->assertStringNotContainsString('public', (string) $res->headers->get('Cache-Control'));

        $play = $this->getJson('/api/v1/episodes/'.$this->episode(1)->id.'/play');
        $this->assertStringNotContainsString('public', (string) $play->headers->get('Cache-Control'));
    }

    public function test_lang_query_selects_the_language(): void
    {
        $this->getJson('/api/v1/categories?lang=sw')->assertOk()->assertHeader('Content-Language', 'sw');
        $this->getJson('/api/v1/categories?lang=en', ['Accept-Language' => 'sw'])->assertHeader('Content-Language', 'en');
        $this->getJson('/api/v1/categories', ['Accept-Language' => 'sw'])->assertHeader('Content-Language', 'sw');
    }
}
