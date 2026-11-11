<?php

namespace Tests\Feature;

class LocalizationTest extends ApiTestCase
{
    public function test_validation_messages_default_to_english(): void
    {
        $this->postJson('/api/v1/auth/register', ['name' => 'Neema', 'email' => 'neema@example.com'])
            ->assertStatus(422)
            ->assertJsonPath('code', 'validation_error')
            ->assertJsonPath('errors.password.0', 'The password field is required.')
            ->assertHeader('Content-Language', 'en');
    }

    public function test_validation_messages_in_kiswahili(): void
    {
        $this->withHeaders(['Accept-Language' => 'sw-TZ,sw;q=0.9,en;q=0.8'])
            ->postJson('/api/v1/auth/register', ['name' => 'Neema', 'email' => 'neema@example.com'])
            ->assertStatus(422)
            ->assertJsonPath('code', 'validation_error')
            ->assertJsonPath('errors.password.0', 'Sehemu ya nenosiri inahitajika.')
            ->assertJsonPath('message', 'Sehemu ya nenosiri inahitajika.')
            ->assertHeader('Content-Language', 'sw');
    }

    public function test_api_exception_message_in_kiswahili_keeps_code(): void
    {
        $ep = $this->episode(5);

        $this->withHeaders(['Accept-Language' => 'sw'])->getJson("/api/v1/episodes/{$ep->id}/play")
            ->assertStatus(402)
            ->assertJsonPath('code', 'episode_locked')
            ->assertJsonPath('message', 'Sehemu hii imefungwa. Ingia kwenye akaunti, kisha jiunge na VIP au ifungue kwa sarafu.');

        $this->withHeaders(['Accept-Language' => 'sw'])
            ->postJson('/api/v1/auth/login', ['login' => 'nobody@example.com', 'password' => 'wrong-password'])
            ->assertStatus(401)
            ->assertJsonPath('code', 'invalid_credentials')
            ->assertJsonPath('message', 'Taarifa hizi za kuingia hazilingani na kumbukumbu zetu.');
    }

    public function test_api_exception_message_defaults_to_english(): void
    {
        $ep = $this->episode(5);

        $this->getJson("/api/v1/episodes/{$ep->id}/play")
            ->assertStatus(402)
            ->assertJsonPath('code', 'episode_locked')
            ->assertJsonPath('message', 'This episode is locked. Log in and subscribe or unlock it with coins.');
    }

    public function test_unsupported_language_falls_back_to_english(): void
    {
        $this->withHeaders(['Accept-Language' => 'fr-FR,fr;q=0.9'])->getJson('/api/v1/auth/me')
            ->assertStatus(401)
            ->assertJsonPath('code', 'unauthenticated')
            ->assertJsonPath('message', 'Unauthenticated.');
    }

    public function test_handler_messages_are_localized(): void
    {
        $this->withHeaders(['Accept-Language' => 'sw'])->getJson('/api/v1/auth/me')
            ->assertStatus(401)
            ->assertJsonPath('code', 'unauthenticated')
            ->assertJsonPath('message', 'Hujaingia. Tafadhali ingia kwenye akaunti yako.');

        // Unknown route: never reaches the api middleware group, still localized.
        $this->withHeaders(['Accept-Language' => 'sw'])->getJson('/api/v1/does-not-exist')
            ->assertNotFound()
            ->assertJsonPath('code', 'not_found')
            ->assertJsonPath('message', 'Hatukupata ulichokuwa unatafuta.');
    }

    public function test_responses_vary_on_accept_language(): void
    {
        $vary = $this->getJson('/api/v1/plans')->assertOk()->headers->get('Vary');

        $this->assertStringContainsString('Accept-Language', (string) $vary);
    }

    public function test_home_section_titles_are_localized(): void
    {
        $this->getJson('/api/v1/home')->assertOk()->assertJsonPath('data.sections.0.title', 'Must-Watch');
        $this->withHeaders(['Accept-Language' => 'sw'])->getJson('/api/v1/home')
            ->assertOk()->assertJsonPath('data.sections.0.title', 'Usikose Kutazama');
    }
}
