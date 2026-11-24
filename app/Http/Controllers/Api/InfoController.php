<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;

/** Reports which build is running, so a deploy can be verified from outside. */
class InfoController extends Controller
{
    public function __invoke(): JsonResponse
    {
        return response()->json([
            'app' => config('app.name'),
            'version' => config('app.version'),
            'region' => config('app.region'),
            'php' => PHP_VERSION,
            'laravel' => app()->version(),
        ]);
    }
}
