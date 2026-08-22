<?php
// Transparent Streaming Pipe for FPO media CDN
ini_set('display_errors', 0);
error_reporting(0);
set_time_limit(0);

$targetUrl = isset($_GET['url']) ? $_GET['url'] : '';
if (empty($targetUrl) || strpos($targetUrl, 'http') !== 0) {
    http_response_code(400);
    echo "Missing or invalid target URL";
    exit;
}

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $targetUrl);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, false);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
curl_setopt($ch, CURLOPT_TIMEOUT, 0);
curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');

$headers = ['Referer: https://www.fpo.xxx/'];
if (isset($_SERVER['HTTP_RANGE'])) {
    $headers[] = 'Range: ' . $_SERVER['HTTP_RANGE'];
}
curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);

curl_setopt($ch, CURLOPT_HEADERFUNCTION, function($curl, $header) {
    $len = strlen($header);
    $trimmed = trim($header);
    if (empty($trimmed)) return $len;

    if (preg_match('/^HTTP\/[12]\.?\d?\s+(\d+)/i', $trimmed, $m)) {
        http_response_code(intval($m[1]));
    } else if (preg_match('/^(Content-Type|Content-Length|Content-Range|Accept-Ranges|Content-Disposition):/i', $trimmed)) {
        header($trimmed);
    }
    return $len;
});

curl_setopt($ch, CURLOPT_WRITEFUNCTION, function($curl, $data) {
    echo $data;
    if (ob_get_level() > 0) ob_flush();
    flush();
    return strlen($data);
});

curl_exec($ch);
curl_close($ch);
