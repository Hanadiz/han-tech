<?php
// Simple health check endpoint
http_response_code(200);
echo json_encode([
    'status' => 'healthy',
    'timestamp' => date('Y-m-d H:i:s'),
    'environment' => 'production'
]);