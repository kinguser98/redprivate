<?php
// Red App Shared Hosting Backend API Configuration
error_reporting(E_ERROR | E_PARSE);
ini_set('display_errors', '0');
ini_set('log_errors', '1');
if (ob_get_level() === 0) {
    ob_start();
}

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

define('STREAMTAPE_LOGIN', 'a43e89ab9e67b46b371f');
define('STREAMTAPE_KEY', '8wykGo0eJkto7yZ');

// Optional Jina Reader API key (https://jina.ai/reader — free). Empty string =
// anonymous access (lowest-trust pool, 20 RPM). Setting a key moves requests to
// the authenticated pool (higher rate limits, less likely to be blocked).
define('JINA_API_KEY', '');

// ---------------------------------------------------------------------------
// DATABASE CREDENTIALS — REAL values (already configured)
// ---------------------------------------------------------------------------
$db_host = 'localhost';
$db_user = 'goprivat_redapp';
$db_pass = '2vHXNVB^beFL{@RC';
$db_name = 'goprivat_redapp';

// Optional manual override file (loaded safely — a broken file won't 500).
$localCfg = __DIR__ . '/config.local.php';
if (is_file($localCfg)) {
    $localCfgContents = @file_get_contents($localCfg);
    if ($localCfgContents !== false) {
        // Only pull the 4 values via regex so syntax errors can never crash us.
        if (preg_match("/\\$db_host\\s*=\\s*['\"]([^'\"]*)['\"]/", $localCfgContents, $m)) $db_host = $m[1];
        if (preg_match("/\\$db_user\\s*=\\s*['\"]([^'\"]*)['\"]/", $localCfgContents, $m)) $db_user = $m[1];
        if (preg_match("/\\$db_pass\\s*=\\s*['\"]([^'\"]*)['\"]/", $localCfgContents, $m)) $db_pass = $m[1];
        if (preg_match("/\\$db_name\\s*=\\s*['\"]([^'\"]*)['\"]/", $localCfgContents, $m)) $db_name = $m[1];
    }
}

try {
    $pdo = new PDO("mysql:host=$db_host;dbname=$db_name;charset=utf8mb4", $db_user, $db_pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
} catch (PDOException $e) {
    if (ob_get_level()) ob_clean();
    echo json_encode([
        "status" => "error",
        "message" => "Database Connection Failed for user=$db_user db=$db_name: " . $e->getMessage()
    ]);
    exit();
}

function json_response($status, $data = [], $message = "") {
    if (ob_get_level()) {
        ob_clean();
    }
    echo json_encode([
        "status" => $status ? "success" : "error",
        "message" => $message,
        "data" => $data
    ]);
    exit();
}
?>
