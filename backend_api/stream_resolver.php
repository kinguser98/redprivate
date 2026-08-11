<?php
// Stream Resolver Endpoint — Universal Server-Side Video Resolver
require_once "config.php";

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

$input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
$url = trim($_GET['url'] ?? $_POST['url'] ?? $input['url'] ?? '');

if (empty($url)) {
    json_response(false, [], "URL parameter 'url' is required");
}

function base_n_convert_res($num, $b) {
    $chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    if ($num < $b) return $chars[$num];
    return base_n_convert_res(intdiv($num, $b), $b) . $chars[$num % $b];
}

function unpack_dean_edwards_res($p, $a, $c, $k) {
    for ($i = $c - 1; $i >= 0; $i--) {
        if (isset($k[$i]) && $k[$i] !== '') {
            $key = base_n_convert_res($i, $a);
            $p = preg_replace('/\b' . preg_quote($key, '/') . '\b/', $k[$i], $p);
        }
    }
    return $p;
}

function resolve_streamtape_standalone($url) {
    if (empty($url)) return '';
    $url = trim($url);

    if (preg_match('~/(?:v|e)/([a-zA-Z0-9_-]+)~', $url, $m)) {
        if (strpos($url, 'streamtape') !== false || strpos($url, 'tpead') !== false || strpos($url, 'tapepops') !== false || strpos($url, 'adblocktpe') !== false || strpos($url, 'advtpe') !== false || strpos($url, 'stape') !== false || strpos($url, 'strcloud') !== false) {
            return "https://streamtape.com/v/" . $m[1];
        }
    }

    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_MAXREDIRS      => 5,
        CURLOPT_TIMEOUT        => 12,
        CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    ]);
    $body = curl_exec($ch);
    $effective_url = curl_getinfo($ch, CURLINFO_EFFECTIVE_URL);
    curl_close($ch);

    if (preg_match('~/(?:v|e)/([a-zA-Z0-9_-]+)~', $effective_url, $m)) {
        if (strpos($effective_url, 'streamtape') !== false || strpos($effective_url, 'tpead') !== false || strpos($effective_url, 'tapepops') !== false || strpos($effective_url, 'adblocktpe') !== false || strpos($effective_url, 'advtpe') !== false || strpos($effective_url, 'stape') !== false || strpos($effective_url, 'strcloud') !== false) {
            return "https://streamtape.com/v/" . $m[1];
        }
    }

    if ($body) {
        if (preg_match('~https?://(?:www\.)?(?:streamtape|tpead|tapepops|adblocktpe|advtpe|stape|strcloud)\.[a-z]{2,6}/(?:v|e)/([a-zA-Z0-9_-]+)~i', $body, $bm)) {
            return "https://streamtape.com/v/" . $bm[1];
        }
    }

    return '';
}

function get_luluvdo_code_res($url) {
    $path = parse_url($url, PHP_URL_PATH);
    if (empty($path)) return '';
    $parts = array_values(array_filter(explode('/', $path)));
    if (empty($parts)) return '';
    return end($parts);
}

function resolve_luluvdo_standalone($url) {
    if (empty($url)) return '';
    $url = trim($url);

    $file_code = get_luluvdo_code_res($url);
    if (empty($file_code)) return '';

    $urls_to_try = [
        "https://lulucdn.com/e/" . $file_code,
        "https://lulucdn.com/" . $file_code,
        "https://luluvdo.com/e/" . $file_code,
        "https://luluvdo.com/" . $file_code,
        "https://lulustream.com/e/" . $file_code
    ];

    foreach ($urls_to_try as $target_url) {
        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL            => $target_url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_TIMEOUT        => 8,
            CURLOPT_SSL_VERIFYPEER => false,
            CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            CURLOPT_HTTPHEADER     => [
                'Referer: https://lulucdn.com/',
            ],
        ]);
        $html = curl_exec($ch);
        curl_close($ch);

        if (!$html) continue;

        if (preg_match('/eval\(function\(p,a,c,k,e,d\)\{.*?\n?\}\s*\(\s*[\'"](.*?)[\'"]\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*[\'"](.*?)[\'"]\.split\([\'"]\|[\'"]\)/s', $html, $m)) {
            $p = $m[1];
            $a = intval($m[2]);
            $c = intval($m[3]);
            $k = explode('|', $m[4]);

            $unpacked = unpack_dean_edwards_res($p, $a, $c, $k);
            if (preg_match('/https?:\/\/[^\s\'"<>]+\.m3u8(?:\?[^\s\'"<>]*)?/i', $unpacked, $sm)) {
                return $sm[0];
            }
        }

        if (preg_match('/https?:\/\/[^\s\'"<>]+\.m3u8(?:\?[^\s\'"<>]*)?/i', $html, $sm)) {
            return $sm[0];
        }
    }

    return '';
}

// Master resolution logic
$resolved = '';
if (strpos($url, 'streamtape') !== false || strpos($url, 'tpead') !== false || strpos($url, 'tapepops') !== false || strpos($url, 'adblocktpe') !== false || strpos($url, 'advtpe') !== false || strpos($url, 'stape') !== false || strpos($url, 'strcloud') !== false) {
    $resolved = resolve_streamtape_standalone($url);
} elseif (strpos($url, 'luluvdo') !== false || strpos($url, 'lulustream') !== false || strpos($url, 'lulucdn') !== false) {
    $resolved = resolve_luluvdo_standalone($url);
} elseif (preg_match('/\.m3u8|\.mp4/i', $url)) {
    $resolved = $url;
} else {
    $resolved = resolve_streamtape_standalone($url);
    if (empty($resolved)) {
        $resolved = resolve_luluvdo_standalone($url);
    }
}

if (!empty($resolved)) {
    $referer = 'https://streamtape.com/';
    if (strpos($url, 'luluvdo') !== false || strpos($url, 'lulustream') !== false || strpos($resolved, 'tnmr.org') !== false || strpos($resolved, 'lulucdn') !== false) {
        $referer = 'https://luluvdo.com/';
    }

    json_response(true, [
        'stream_url' => $resolved,
        'original_url' => $url,
        'headers' => [
            'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer' => $referer
        ]
    ], 'Stream resolved successfully');
} else {
    json_response(false, ['stream_url' => '', 'original_url' => $url], 'No playable stream found for URL');
}
?>
