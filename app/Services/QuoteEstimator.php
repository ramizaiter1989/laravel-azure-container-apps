<?php

namespace App\Services;

/**
 * Estimates a cash offer for a used or end-of-life vehicle.
 *
 * Pure domain logic (no I/O), so it is fast to unit-test and easy to swap
 * for a pricing model later.
 */
class QuoteEstimator
{
    public const CONDITIONS = ['running', 'not_running', 'damaged', 'scrap'];

    public const BODY_TYPES = ['sedan', 'suv', 'truck', 'van', 'coupe'];

    private const BASE_BY_BODY = [
        'sedan' => 900,
        'coupe' => 850,
        'suv' => 1200,
        'van' => 1100,
        'truck' => 1500,
    ];

    private const CONDITION_FACTOR = [
        'running' => 1.0,
        'not_running' => 0.65,
        'damaged' => 0.5,
        'scrap' => 0.3,
    ];

    /**
     * @return array{offer: int, currency: string, breakdown: array<string, int|float>}
     */
    public function estimate(int $year, string $bodyType, string $condition, int $mileage, ?int $currentYear = null): array
    {
        $currentYear ??= (int) date('Y');
        $age = max(0, $currentYear - $year);

        $base = self::BASE_BY_BODY[$bodyType];
        $ageFactor = max(0.35, 1 - 0.04 * $age);             // -4 % per year, floor 35 %
        $mileageFactor = max(0.6, 1 - $mileage / 500_000);   // -1 % per 5,000 mi, floor 60 %
        $conditionFactor = self::CONDITION_FACTOR[$condition];

        $offer = (int) (round($base * $ageFactor * $mileageFactor * $conditionFactor / 5) * 5);
        $offer = max(100, $offer);                            // minimum scrap value

        return [
            'offer' => $offer,
            'currency' => 'USD',
            'breakdown' => [
                'base' => $base,
                'age_factor' => round($ageFactor, 2),
                'mileage_factor' => round($mileageFactor, 2),
                'condition_factor' => $conditionFactor,
            ],
        ];
    }
}
