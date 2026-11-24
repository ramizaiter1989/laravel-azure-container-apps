<?php

namespace App\Http\Requests;

use App\Services\QuoteEstimator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreQuoteRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'year' => ['required', 'integer', 'between:1950,'.((int) date('Y') + 1)],
            'body_type' => ['required', Rule::in(QuoteEstimator::BODY_TYPES)],
            'condition' => ['required', Rule::in(QuoteEstimator::CONDITIONS)],
            'mileage' => ['required', 'integer', 'min:0', 'max:1000000'],
            'zip' => ['nullable', 'regex:/^\d{5}$/'],
        ];
    }
}
