<?php
require_once "config.php";

$url = trim($_GET['url'] ?? '');

if (empty($url)) {
    json_response(false, [], "URL parameter is required");
}

if (strpos($url, 'luluvdo') !== false || strpos($url, 'lulustream') !== false || strpos($url, 'tnmr') !== false || strpos($url, 'uplinks') !== false) {
    require_once "stream_resolver.php";
    exit(0);
}

// Convert embed URLs (/e/) or watch URLs (/v/) to standard watch URL
$watch_url = preg_replace('#/(?:e|f)/#', '/v/', $url);

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $watch_url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Accept-Language: en-US,en;q=0.9',
    'Referer: https://streamtape.com/'
]);
curl_setopt($ch, CURLOPT_TIMEOUT, 15);
$html = curl_exec($ch);
curl_close($ch);

if (!$html) {
    json_response(false, [], "Failed to fetch Streamtape page");
}

$direct_link = "";

// Match JS robotlink/norobotlink/ideoolink/ideoooolink/captchalink/botlink patterns:
// Pattern 1a: double-substring (offset = sub1 + sub2)
if (preg_match("/(?:robotlink|norobotlink|ideoolink|ideoooolink|captchalink|botlink)'\)\.innerHTML\s*=\s*'([^']*)'\s*\+\s*\('([^']*)'\)\.substring\((\d+)\)\.substring\((\d+)\)/i", $html, $m)) {
    $prefix = $m[1];
    $target = $m[2];
    $sub1 = intval($m[3]);
    $sub2 = intval($m[4]);
    $cleanTarget = substr($target, $sub1 + $sub2);
    $direct_link = "https:" . $prefix . $cleanTarget;
// Pattern 1b: single-substring
} else if (preg_match("/(?:robotlink|norobotlink|ideoolink|ideoooolink|captchalink|botlink)'\)\.innerHTML\s*=\s*'([^']*)'\s*\+\s*\('([^']*)'\)\.substring\((\d+)\)/i", $html, $m2)) {
    $prefix = $m2[1];
    $target = $m2[2];
    $sub1 = intval($m2[3]);
    $cleanTarget = substr($target, $sub1);
    $direct_link = "https:" . $prefix . $cleanTarget;
} else if (preg_match('/id="(?:norobotlink|ideoooolink|captchalink|robotlink)"[^>]*>(.*?)<\/(?:div|span)>/i', $html, $m3)) {
    $direct_link = "https:" . trim($m3[1]);
}

// Fallback: plain div/span elements
if (empty($direct_link)) {
    foreach (['norobotlink', 'ideoooolink', 'captchalink', 'robotlink', 'ideoolink', 'botlink'] as $divId) {
        if (preg_match('/id="' . $divId . '"[^>]*>(.*?)<\/(?:div|span)>/is', $html, $m4)) {
            $val = trim($m4[1]);
            if (!empty($val) && strpos($val, 'get_video') !== false) {
                $direct_link = $val;
                break;
            }
        }
    }
}

// Normalize host-relative /host/path -> https://host/path, and //host/path -> https://host/path
if (!empty($direct_link)) {
    if (preg_match('#^/([^/?]+)(/.+)$#', $direct_link, $m5)) {
        $direct_link = "https://" . $m5[1] . $m5[2];
    } elseif (strpos($direct_link, '//') === 0) {
        $direct_link = "https:" . $direct_link;
    } elseif (strpos($direct_link, 'http') !== 0 && strpos($direct_link, '/') === 0) {
        $direct_link = ''; // bare path with no host - skip
    } elseif (strpos($direct_link, 'http') !== 0) {
        $direct_link = "https://" . $direct_link;
    }
}

if (!empty($direct_link)) {
    if (strpos($direct_link, 'stream=1') === false) {
        $direct_link .= (strpos($direct_link, '?') !== false ? '&stream=1' : '?stream=1');
    }

    // Append format hint fragment #video.mp4 so media_kit / libmpv recognizes format immediately!
    if (strpos($direct_link, '#') === false) {
        $direct_link .= '#video.mp4';
    }

    json_response(true, [
        "original_url" => $url,
        "stream_url" => $direct_link,
        "source" => "scraper"
    ], "Streamtape link resolved");
} else {
    json_response(false, ["original_url" => $url], "Failed to extract Streamtape video token. Link may be dead or deleted.");
}
?>
