<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreQuoteRequest;
use App\Services\QuoteEstimator;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Str;

class QuoteController extends Controller
{
    public function store(StoreQuoteRequest $request, QuoteEstimator $estimator): JsonResponse
    {
        $data = $request->validated();

        $estimate = $estimator->estimate(
            year: (int) $data['year'],
            bodyType: $data['body_type'],
            condition: $data['condition'],
            mileage: (int) $data['mileage'],
        );

        return response()->json([
            'id' => (string) Str::uuid(),
            'input' => $data,
            ...$estimate,
            'valid_until' => now()->addDays(7)->toDateString(),
        ], 201);
    }
}
