<?php

namespace Tests\Feature;

use Tests\TestCase;

class QuoteApiTest extends TestCase
{
    public function test_it_returns_a_quote(): void
    {
        $response = $this->postJson('/api/quotes', [
            'year' => 2014,
            'body_type' => 'sedan',
            'condition' => 'not_running',
            'mileage' => 150000,
            'zip' => '48201',
        ]);

        $response->assertCreated()
            ->assertJsonStructure(['id', 'offer', 'currency', 'breakdown', 'valid_until'])
            ->assertJsonPath('currency', 'USD');
    }

    public function test_it_rejects_invalid_input(): void
    {
        $this->postJson('/api/quotes', ['year' => 1800, 'body_type' => 'boat'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['year', 'body_type', 'condition', 'mileage']);
    }

    public function test_info_endpoint_reports_version(): void
    {
        $this->getJson('/api/info')
            ->assertOk()
            ->assertJsonStructure(['app', 'version', 'region', 'php', 'laravel']);
    }

    public function test_health_endpoint_is_up(): void
    {
        $this->get('/up')->assertOk();
    }
}
