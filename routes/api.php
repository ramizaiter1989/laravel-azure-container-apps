<?php

use App\Http\Controllers\Api\InfoController;
use App\Http\Controllers\Api\QuoteController;
use Illuminate\Support\Facades\Route;

Route::get('/info', InfoController::class);
Route::post('/quotes', [QuoteController::class, 'store'])->middleware('throttle:30,1');
