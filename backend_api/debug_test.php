<?php
error_reporting(E_ALL);
ini_set('display_errors', '1');
require_once __DIR__ . '/config.php';
header('Content-Type: text/plain');

echo "USER_DB COLUMNS:\n";
try {
    $q = $pdo->query("DESCRIBE user_db")->fetchAll();
    print_r($q);
} catch(Exception $e) { echo "Error: " . $e->getMessage() . "\n"; }
?>
