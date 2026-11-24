<?php

namespace Tests\Unit;

use App\Services\QuoteEstimator;
use PHPUnit\Framework\TestCase;

class QuoteEstimatorTest extends TestCase
{
    private QuoteEstimator $estimator;

    protected function setUp(): void
    {
        $this->estimator = new QuoteEstimator;
    }

    public function test_new_running_truck_gets_full_base_price(): void
    {
        $quote = $this->estimator->estimate(2026, 'truck', 'running', 0, currentYear: 2026);

        $this->assertSame(1500, $quote['offer']);
    }

    public function test_condition_reduces_offer(): void
    {
        $running = $this->estimator->estimate(2015, 'sedan', 'running', 120_000, currentYear: 2026);
        $scrap = $this->estimator->estimate(2015, 'sedan', 'scrap', 120_000, currentYear: 2026);

        $this->assertGreaterThan($scrap['offer'], $running['offer']);
    }

    public function test_offer_never_drops_below_minimum(): void
    {
        $quote = $this->estimator->estimate(1960, 'coupe', 'scrap', 999_999, currentYear: 2026);

        $this->assertSame(100, $quote['offer']);
    }

    public function test_offer_is_rounded_to_five_dollars(): void
    {
        $quote = $this->estimator->estimate(2012, 'suv', 'not_running', 87_000, currentYear: 2026);

        $this->assertSame(0, $quote['offer'] % 5);
    }
}
