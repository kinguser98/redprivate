<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);

header('Content-Type: text/plain; charset=utf-8');

echo "Step 1: Requiring config.php...\n";
require_once "config.php";
echo "Step 2: config.php loaded successfully. PDO connected.\n";

echo "Step 3: Testing admin_api.php syntax by including it...\n";
try {
    // Check if admin_api.php has any compile-time parse errors
    include_once "admin_api.php";
    echo "Step 4: admin_api.php included successfully without fatal errors!\n";
} catch (Throwable $e) {
    echo "Fatal Error caught in admin_api.php: " . $e->getMessage() . " on line " . $e->getLine() . "\n";
}
