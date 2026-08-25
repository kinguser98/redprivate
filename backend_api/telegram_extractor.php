<?php
/**
 * Standalone High-Speed Server-Side Telegram Uploader
 * 
 * Receives:
 *  - bot_token
 *  - channel_id
 *  - image_urls (array of image URLs)
 *  - video_url (Streamtape / Vidara / Merivo / LuluVdo / Direct MP4 URL)
 *  - title
 *  - caption (HTML formatted)
 *  - upload_photos (bool)
 *  - upload_video (bool)
 * 
 * Downloads at 10Gbps on the server and uploads directly to Telegram Bot API.
 * Uses 0 mobile data on the user's phone!
 */

ini_set('display_errors', 0);
error_reporting(0);
ignore_user_abort(true);
set_time_limit(300);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

function json_out($success, $data = [], $message = '') {
    echo json_encode([
        'status'  => $success ? 'success' : 'error',
        'success' => $success,
        'data'    => $data,
        'message' => $message,
    ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

$raw_input = file_get_contents('php://input');
$input = json_decode($raw_input, true) ?? $_POST;

$action = trim($input['action'] ?? $_GET['action'] ?? 'upload');

if ($action === 'ping') {
    json_out(true, ['server_time' => time()], 'Telegram Extractor Server is Online');
}

$bot_token = trim($input['bot_token'] ?? '');
$channel_id = trim($input['channel_id'] ?? '');
$title = trim($input['title'] ?? 'DropMMS Video');
$caption = trim($input['caption'] ?? '');
$video_url = trim($input['video_url'] ?? '');
$image_urls = $input['image_urls'] ?? [];
$upload_photos = isset($input['upload_photos']) ? filter_var($input['upload_photos'], FILTER_VALIDATE_BOOLEAN) : true;
$upload_video = isset($input['upload_video']) ? filter_var($input['upload_video'], FILTER_VALIDATE_BOOLEAN) : true;

if (empty($bot_token) || empty($channel_id)) {
    json_out(false, [], 'Bot Token and Channel ID are required.');
}

if (!is_array($image_urls)) {
    $image_urls = !empty($image_urls) ? [$image_urls] : [];
}

$tmp_dir = sys_get_temp_dir() . '/tg_extractor_' . uniqid();
if (!is_dir($tmp_dir)) {
    @mkdir($tmp_dir, 0777, true);
}

$results = [
    'photos_uploaded' => 0,
    'video_uploaded' => false,
];

// Helper: Custom CURL GET with anti-hotlink bypass
function fetch_media_bytes($url, $referer = 'https://dropmms.co/') {
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_TIMEOUT        => 30,
        CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_SSL_VERIFYHOST => false,
        CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        CURLOPT_HTTPHEADER     => [
            'Referer: ' . $referer,
            'Accept: image/webp,image/apng,image/*,*/*;q=0.8',
        ],
    ]);
    $data = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return ($code == 200 && !empty($data)) ? $data : false;
}

// 1. Upload Photos as Multi-Photo Album (sendMediaGroup)
if ($upload_photos && !empty($image_urls)) {
    $downloaded_files = [];
    foreach ($image_urls as $idx => $img_url) {
        $img_bytes = fetch_media_bytes($img_url);
        if ($img_bytes) {
            $fpath = $tmp_dir . '/photo_' . $idx . '.jpg';
            file_put_contents($fpath, $img_bytes);
            $downloaded_files[] = $fpath;
        }
    }

    if (!empty($downloaded_files)) {
        // Chunk into batches of up to 10 photos
        $batches = array_chunk($downloaded_files, 10);
        foreach ($batches as $bIdx => $batch) {
            $media_group = [];
            $post_fields = ['chat_id' => $channel_id];

            foreach ($batch as $i => $file_path) {
                $attach_key = 'photo_' . $i;
                $item = [
                    'type'  => 'photo',
                    'media' => 'attach://' . $attach_key,
                ];

                // Caption only on first photo of first album
                if ($bIdx === 0 && $i === 0 && !empty($caption)) {
                    $item['caption'] = $caption;
                    $item['parse_mode'] = 'HTML';
                }

                $media_group[] = $item;
                $post_fields[$attach_key] = new CURLFile($file_path, 'image/jpeg', basename($file_path));
            }

            $post_fields['media'] = json_encode($media_group);

            $tg_ch = curl_init();
            curl_setopt_array($tg_ch, [
                CURLOPT_URL            => "https://api.telegram.org/bot{$bot_token}/sendMediaGroup",
                CURLOPT_POST           => true,
                CURLOPT_POSTFIELDS     => $post_fields,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_TIMEOUT        => 60,
                CURLOPT_SSL_VERIFYPEER => false,
            ]);
            $tg_resp = curl_exec($tg_ch);
            curl_close($tg_ch);

            $tg_json = json_decode($tg_resp, true);
            if ($tg_json && !empty($tg_json['ok'])) {
                $results['photos_uploaded'] += count($batch);
            }
        }
    }
}

// 2. Resolve and Upload Native Playable Video (sendVideo)
if ($upload_video && !empty($video_url)) {
    // Resolve Streamtape / Vidara / Merivo stream link
    $direct_stream_url = $video_url;

    if (preg_match('/(?:streamtape|streamta\.pe|strcloud|stape\.fun|advtpe|adblocktape)\.com\/[vef]\/([a-zA-Z0-9_-]+)/i', $video_url, $m)) {
        $file_id = $m[1];
        // Scrape from fast mirror
        $scrape_url = "https://strcloud.link/v/$file_id";
        $scrape_html = fetch_media_bytes($scrape_url, "https://strcloud.link/v/$file_id");
        if ($scrape_html && preg_match("/norobotlink['\"]\)\.innerHTML\s*=\s*['\"]([^'\"]+)['\"]\s*\+\s*\('([^'\"]+)'\)\.substring\((\d+)\)(?:\.substring\((\d+)\))?/i", $scrape_html, $sm)) {
            $prefix = $sm[1];
            $tok = $sm[2];
            $s1 = intval($sm[3]);
            $s2 = isset($sm[4]) ? intval($sm[4]) : 0;
            $clean_tok = substr($tok, $s1 + $s2);
            $full_path = $prefix . $clean_tok;
            if (strpos($full_path, '//') === 0) $full_path = 'https:' . $full_path;
            elseif (strpos($full_path, 'http') !== 0) $full_path = "https://strcloud.link$full_path";
            $full_path = str_replace('streamtape.com', 'strcloud.link', $full_path);
            if (strpos($full_path, 'stream=1') === false) {
                $full_path .= (strpos($full_path, '?') !== false) ? '&stream=1' : '?stream=1';
            }
            $direct_stream_url = $full_path;
        }
    } elseif (preg_match('/(?:vidara|merivo)/i', $video_url)) {
        $parts = explode('/', trim(parse_url($video_url, PHP_URL_PATH), '/'));
        $filecode = end($parts);
        if (!empty($filecode)) {
            $ch = curl_init();
            curl_setopt_array($ch, [
                CURLOPT_URL            => 'https://merivo.fit/api/stream',
                CURLOPT_POST           => true,
                CURLOPT_POSTFIELDS     => json_encode(['filecode' => $filecode, 'device' => 'android']),
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_TIMEOUT        => 10,
                CURLOPT_SSL_VERIFYPEER => false,
                CURLOPT_HTTPHEADER     => [
                    'Content-Type: application/json',
                    'Referer: https://merivo.fit/e/' . $filecode,
                    'Origin: https://merivo.fit',
                    'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                ],
            ]);
            $m_resp = curl_exec($ch);
            curl_close($ch);
            $m_json = json_decode($m_resp, true);
            if (!empty($m_json['streaming_url'])) {
                $direct_stream_url = $m_json['streaming_url'];
            }
        }
    }

    // Download video file to server temp
    $temp_video = $tmp_dir . '/video.mp4';
    $fp = fopen($temp_video, 'w+');

    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $direct_stream_url,
        CURLOPT_FILE           => $fp,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_CONNECTTIMEOUT => 15,
        CURLOPT_TIMEOUT        => 180,
        CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        CURLOPT_HTTPHEADER     => [
            'Referer: https://strcloud.link/',
        ],
    ]);
    curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    fclose($fp);

    if (file_exists($temp_video) && filesize($temp_video) > 100 * 1024) {
        $video_size_mb = round(filesize($temp_video) / (1024 * 1024), 2);

        // Telegram Bot API limit is 50MB
        if ($video_size_mb <= 50) {
            $tg_ch = curl_init();
            $safe_title = preg_replace('/[\\\\\/:\*\?"<>\|]/', '_', $title);
            $post_fields = [
                'chat_id'            => $channel_id,
                'caption'            => !empty($caption) ? $caption : $title,
                'parse_mode'         => 'HTML',
                'supports_streaming' => 'true',
                'video'              => new CURLFile($temp_video, 'video/mp4', $safe_title . '.mp4'),
            ];

            curl_setopt_array($tg_ch, [
                CURLOPT_URL            => "https://api.telegram.org/bot{$bot_token}/sendVideo",
                CURLOPT_POST           => true,
                CURLOPT_POSTFIELDS     => $post_fields,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_TIMEOUT        => 180,
                CURLOPT_SSL_VERIFYPEER => false,
            ]);
            $tg_resp = curl_exec($tg_ch);
            curl_close($tg_ch);

            $tg_json = json_decode($tg_resp, true);
            if ($tg_json && !empty($tg_json['ok'])) {
                $results['video_uploaded'] = true;
            } else {
                $results['video_error'] = $tg_json['description'] ?? 'Telegram API video upload failed';
            }
        } else {
            $results['video_error'] = "Video is {$video_size_mb} MB (Telegram Bot limit is 50 MB).";
        }
    } else {
        $results['video_error'] = 'Stream host did not return video bytes or stream has expired.';
    }
}

// Cleanup temp files
array_map('unlink', glob("$tmp_dir/*"));
@rmdir($tmp_dir);

json_out(true, $results, 'Telegram Broadcast Process Completed');
