<?php
// Downloads proxy: streams a remote file to the client. Streamtape page URLs
// are resolved server-side (fresh) before downloading. The upstream is probed
// first so a bad resolution returns a clean error instead of HTML. Supports
// Range for resume and reports the real file size.
require_once "config.php";

$url = trim($_GET['url'] ?? '');
if (empty($url) || !filter_var($url, FILTER_VALIDATE_URL) || !preg_match('~^https?://~i', $url)) {
    http_response_code(400);
    die('Invalid URL');
}

function proxy_resolve_streamtape($url) {
    $file_id = '';
    if (preg_match('/(?:v|e)\/([a-zA-Z0-9_-]+)/i', $url, $m)) {
        $file_id = $m[1];
    }
    if (empty($file_id)) return '';

    // 1. Official Streamtape API
    $login = STREAMTAPE_LOGIN;
    $key = STREAMTAPE_KEY;
    if (!empty($login) && !empty($key)) {
        $ticket_url = "https://api.streamtape.com/file/dlticket?file={$file_id}&login={$login}&key={$key}";
        $ticket_res = @file_get_contents($ticket_url);
        if ($ticket_res) {
            $td = json_decode($ticket_res, true);
            if (($td['status'] ?? 0) === 200 && isset($td['result']['ticket'])) {
                $ticket = $td['result']['ticket'];
                $wait = intval($td['result']['wait_time'] ?? 0);
                if ($wait > 0) sleep(min($wait, 5));
                $dl_url = "https://api.streamtape.com/file/dl?file={$file_id}&ticket={$ticket}";
                $dl_res = @file_get_contents($dl_url);
                if ($dl_res) {
                    $dd = json_decode($dl_res, true);
                    if (($dd['status'] ?? 0) === 200 && isset($dd['result']['url'])) {
                        $stream = $dd['result']['url'];
                        if (strpos($stream, 'stream=1') === false) {
                            $stream .= (strpos($stream, '?') !== false ? '&stream=1' : '?stream=1');
                        }
                        return $stream;
                    }
                }
            }
        }
    }

    // 2. Page scrape fallback
    $embed = preg_replace('~/v/~', '/e/', $url, 1);
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $embed);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    curl_setopt($ch, CURLOPT_TIMEOUT, 15);
    $html = curl_exec($ch);
    curl_close($ch);
    if (!$html) return '';

    $direct = '';
    if (preg_match("/robotlink'\)\.innerHTML\s*=\s*'([^']+)'\s*\+\s*\('([^']+)'\)\.substring\((\d+)\)\.substring\((\d+)\)/i", $html, $m)) {
        $direct = "https:" . $m[1] . substr($m[2], intval($m[3]) + intval($m[4]));
    } else if (preg_match("/robotlink'\)\.innerHTML\s*=\s*'([^']+)'\s*\+\s*\('([^']+)'\)\.substring\((\d+)\)/i", $html, $m2)) {
        $direct = "https:" . $m2[1] . substr($m2[2], intval($m2[3]));
    } else if (preg_match('/id="norobotlink"[^>]*>(.*?)<\/div>/i', $html, $m3)) {
        $direct = "https:" . trim($m3[1]);
    }
    if (empty($direct)) return '';

    if (strpos($direct, 'stream=1') === false) {
        $direct .= (strpos($direct, '?') !== false ? '&stream=1' : '?stream=1');
    }

    $ch2 = curl_init();
    curl_setopt($ch2, CURLOPT_URL, $direct);
    curl_setopt($ch2, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch2, CURLOPT_NOBODY, true);
    curl_setopt($ch2, CURLOPT_FOLLOWLOCATION, false);
    curl_setopt($ch2, CURLOPT_HTTPHEADER, ['User-Agent: Mozilla/5.0', 'Referer: https://streamtape.com/']);
    curl_setopt($ch2, CURLOPT_TIMEOUT, 10);
    curl_exec($ch2);
    $redirect = curl_getinfo($ch2, CURLINFO_REDIRECT_URL);
    curl_close($ch2);
    return !empty($redirect) ? $redirect : $direct;
}

// Resolve streamtape page URLs server-side (fresh at download time)
if (preg_match('~streamtape|strcloud|tpead|tapepops~i', $url)) {
    $resolved = proxy_resolve_streamtape($url);
    if (empty($resolved)) {
        http_response_code(502);
        die('STREAM_RESOLUTION_FAILED');
    }
    $url = $resolved;
}

// Probe upstream (Range 0-0) to validate it is media and get the real size
$size = 0;
$bodyCount = 0;
$probe = curl_init();
curl_setopt($probe, CURLOPT_URL, $url);
curl_setopt($probe, CURLOPT_RETURNTRANSFER, false);
curl_setopt($probe, CURLOPT_FOLLOWLOCATION, true);
curl_setopt($probe, CURLOPT_MAXREDIRS, 6);
curl_setopt($probe, CURLOPT_RANGE, '0-0');
curl_setopt($probe, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
curl_setopt($probe, CURLOPT_REFERER, 'https://streamtape.com/');
curl_setopt($probe, CURLOPT_TIMEOUT, 15);
curl_setopt($probe, CURLOPT_HEADERFUNCTION, function ($curl, $header) use (&$size) {
    $len = strlen($header);
    $trim = trim($header);
    if (stripos($trim, 'Content-Range:') === 0 && preg_match('~/(\d+)\s*$~', $trim, $m)) {
        $size = intval($m[1]);
    } else if (stripos($trim, 'Content-Length:') === 0) {
        $cl = intval(trim(substr($trim, 15)));
        if ($cl > $size) $size = $cl;
    }
    return $len;
});
curl_setopt($probe, CURLOPT_WRITEFUNCTION, function ($curl, $data) use (&$bodyCount) {
    $bodyCount += strlen($data);
    if ($bodyCount > 65536) return 0; // abort after 64KB if Range is ignored
    return strlen($data);
});
curl_exec($probe);
$code = intval(curl_getinfo($probe, CURLINFO_HTTP_CODE));
$ctype = (string)curl_getinfo($probe, CURLINFO_CONTENT_TYPE);
curl_close($probe);

// 403 is often CDN hotlink protection — the full GET can still work, so allow it.
if ($code >= 400 && $code !== 403) {
    http_response_code(502);
    die('UPSTREAM_INVALID');
}
// Reject 2xx responses that are HTML pages (bad resolution)
if ($code >= 200 && $code < 400 && stripos($ctype, 'text/html') !== false) {
    http_response_code(502);
    die('UPSTREAM_INVALID');
}
if ($size <= 0) {
    $size = 0;
}

header('Content-Type: application/octet-stream');
header('Accept-Ranges: bytes');
if ($size > 0) {
    header('Content-Length: ' . $size);
    header('X-File-Size: ' . $size);
}

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
curl_setopt($ch, CURLOPT_MAXREDIRS, 6);
curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
curl_setopt($ch, CURLOPT_REFERER, 'https://streamtape.com/');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, false);
curl_setopt($ch, CURLOPT_HEADER, false);
curl_setopt($ch, CURLOPT_TIMEOUT, 0);
curl_setopt($ch, CURLOPT_BUFFERSIZE, 131072);

if (isset($_SERVER['HTTP_RANGE'])) {
    curl_setopt($ch, CURLOPT_RANGE, $_SERVER['HTTP_RANGE']);
}

curl_exec($ch);
curl_close($ch);
