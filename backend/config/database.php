'connections' => [
    'pgsql' => [
        'driver' => 'pgsql',
        'host' => env('DB_HOST', 'hanadiz-db.internal'),
        'port' => env('DB_PORT', '5432'),
        'database' => env('DB_DATABASE', 'hanadiz'),
        'username' => env('DB_USERNAME', 'hanadiz_user'),
        'password' => env('DB_PASSWORD', ''),
        'charset' => 'utf8',
        'prefix' => '',
        'schema' => 'public',
        'sslmode' => 'require',
        'options' => [
            PDO::ATTR_EMULATE_PREPARES => false,
            PDO::ATTR_PERSISTENT => true,
        ],
    ],
],