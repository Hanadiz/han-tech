<?php
return [
    'allowed_origins' => [
        'https://hanadiz-frontend.onrender.com',
        'https://hanadiz-backend.onrender.com',
    ],
    'rate_limiting' => [
        'enabled' => true,
        'max_requests' => 100,
        'decay_minutes' => 1,
    ],
    'headers' => [
        'X-Frame-Options' => 'DENY',
        'X-Content-Type-Options' => 'nosniff',
        'Referrer-Policy' => 'strict-origin-when-cross-origin',
    ],
];