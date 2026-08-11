<?php
require_once "config.php";

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

$input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
$action = $_GET['action'] ?? $_POST['action'] ?? $input['action'] ?? '';

// Ensure genres has a sort_order column (idempotent migration for shared hosting)
try {
    $hasSort = $pdo->query("SHOW COLUMNS FROM genres LIKE 'sort_order'")->fetch();
    if (!$hasSort) {
        $pdo->exec("ALTER TABLE genres ADD COLUMN sort_order INT NOT NULL DEFAULT 0");
    }
} catch (Exception $e) {}

// Ensure user_reports table exists
try {
    $pdo->exec("CREATE TABLE IF NOT EXISTS user_reports (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        content_id INT NOT NULL,
        content_type INT NOT NULL, -- 1 = Movie, 2 = Web Series
        message TEXT NOT NULL,
        status INT NOT NULL DEFAULT 0, -- 0 = Pending, 1 = Accepted, 2 = Rejected
        admin_reply VARCHAR(255) DEFAULT NULL,
        reply_seen INT NOT NULL DEFAULT 0, -- 0 = Unseen, 1 = Seen
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_user (user_id),
        INDEX idx_seen (reply_seen)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
} catch (Exception $e) {}

// Ensure scraper_catalog_cache table exists
try {
    $pdo->exec("CREATE TABLE IF NOT EXISTS scraper_catalog_cache (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        source VARCHAR(50) NOT NULL,
        title VARCHAR(255) NOT NULL,
        page_url VARCHAR(500) NOT NULL,
        poster VARCHAR(500) DEFAULT NULL,
        release_date VARCHAR(100) DEFAULT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY idx_source_url (source, page_url(190))
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
} catch (Exception $e) {}

// Ensure upcoming table exists
try {
    $pdo->exec("CREATE TABLE IF NOT EXISTS upcoming (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT DEFAULT NULL,
        poster VARCHAR(255) DEFAULT NULL,
        banner VARCHAR(255) DEFAULT NULL,
        release_date VARCHAR(100) DEFAULT NULL,
        youtube_trailer VARCHAR(255) DEFAULT NULL,
        status INT NOT NULL DEFAULT 1
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
} catch (Exception $e) {}

// Ensure active_sessions table exists (online now tracking)
try {
    $pdo->exec("CREATE TABLE IF NOT EXISTS active_sessions (
        user_id INT NOT NULL PRIMARY KEY,
        last_ping DATETIME NOT NULL,
        current_view VARCHAR(100) DEFAULT NULL,
        content_id INT DEFAULT NULL,
        content_type INT DEFAULT NULL, -- 1 = Movie, 2 = Web Series
        INDEX idx_ping (last_ping)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
} catch (Exception $e) {}

// Ensure watch_history_analytics table exists (play logs)
try {
    $pdo->exec("CREATE TABLE IF NOT EXISTS watch_history_analytics (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        content_id INT NOT NULL,
        content_type INT NOT NULL, -- 1 = Movie, 2 = Web Series
        duration_seconds INT NOT NULL DEFAULT 0,
        completed INT NOT NULL DEFAULT 0, -- 0 = No, 1 = Yes
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_user (user_id),
        INDEX idx_content (content_id, content_type)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
} catch (Exception $e) {}

// Ensure download_statistics table exists (download tracking)
try {
    $pdo->exec("CREATE TABLE IF NOT EXISTS download_statistics (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        content_id INT NOT NULL,
        content_type INT NOT NULL, -- 1 = Movie, 2 = Web Series
        status VARCHAR(50) NOT NULL DEFAULT 'started', -- 'started', 'completed'
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_user (user_id),
        INDEX idx_content (content_id, content_type)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
} catch (Exception $e) {}

// Add app_version column to user_db if it doesn't exist
try {
    $pdo->exec("ALTER TABLE user_db ADD COLUMN app_version VARCHAR(50) DEFAULT '1.0.0'");
} catch (Exception $e) {}



//
// LINK HEALTH HELPERS (works for Streamtape + direct MP4/MKV)
//
// Resolves comma-separated genre IDs to genre names so the app queries them properly
function resolve_genre_names($pdo, $genres_input) {
    if (empty($genres_input)) {
        return '';
    }
    $parts = array_filter(array_map('trim', explode(',', $genres_input)));
    $ids = [];
    $names = [];
    foreach ($parts as $p) {
        if (is_numeric($p)) {
            $ids[] = intval($p);
        } else {
            $names[] = $p;
        }
    }
    if (!empty($ids)) {
        try {
            $in_clause = implode(',', $ids);
            $stmt = $pdo->query("SELECT name FROM genres WHERE id IN ($in_clause)");
            foreach ($stmt->fetchAll(PDO::FETCH_COLUMN) as $name) {
                $names[] = trim($name);
            }
        } catch (Exception $e) {}
    }
    return implode(',', array_filter(array_unique($names)));
}

// Detect any Streamtape-family host (old/new mirror domains).
function is_streamtape_link($url) {
    if (empty($url)) return false;
    $host = strtolower(parse_url($url, PHP_URL_HOST) ?: $url);
    $patterns = [
        'streamtape', 'tapepops', 'tapepop', 'advtpe', 'streamtp', 's-tpe', 'tpead',
        'tpe.com', 'streamta', 'tapecom', 'tape.gg', 'stp.gg', 'tapemax', 'tapehost',
        'streamtape.xyz', 'streamtape.net', 'streamtape.to', 'streamtape.click',
        'tpes.', 'tape.xyz', 'tpe.xyz', 'streamtape.top', 'streamtapp', 'stape',
    ];
    foreach ($patterns as $p) {
        if (strpos($host, $p) !== false) return true;
    }
    return false;
}

// Known Streamtape-family mirror hosts. The same video ID works on every mirror,
// so a video is LIVE if ANY mirror serves a real player for that ID.
function streamtape_mirror_hosts() {
    return [
        'streamtape.com',
        'advtpe.com',
        'tapepops.com',
        'tpead.net',
        'tpead.com',
        'streamtp.com',
        'streamtape.to',
        'streamtape.net',
    ];
}

// Build an embed URL for a given /v/ url on a specific mirror host.
function streamtape_embed_on_host($url, $host) {
    $path = parse_url($url, PHP_URL_PATH); // /v/{ID}
    $id = basename($path ?: '');
    if (empty($id)) return '';
    return "https://" . $host . "/e/" . $id;
}

// Extract the video ID from a streamtape /v/ or /e/ url.
function streamtape_video_id($url) {
    $path = parse_url($url, PHP_URL_PATH) ?: '';
    $id = basename($path);
    if (preg_match('/^[A-Za-z0-9]{10,}$/', $id)) return $id;
    // Fallback: any non-empty token after last slash
    return $id !== '' && $id !== '/' ? $id : '';
}

function resolve_streamtape_direct($url) {
    $embed_url = preg_replace('~/v/~', '/e/', $url, 1);
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $embed_url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_USERAGENT, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
    curl_setopt($ch, CURLOPT_TIMEOUT, 15);
    $html = curl_exec($ch);
    curl_close($ch);
    if (!$html) return '';
    $direct_link = "";
    if (preg_match("/robotlink'\)\.innerHTML\s*=\s*'([^']+)'\s*\+\s*\('([^']+)'\)\.substring\((\d+)\)\.substring\((\d+)\)/i", $html, $m)) {
        $direct_link = "https:" . $m[1] . substr($m[2], intval($m[3]) + intval($m[4]));
    } else if (preg_match("/robotlink'\)\.innerHTML\s*=\s*'([^']+)'\s*\+\s*\('([^']+)'\)\.substring\((\d+)\)/i", $html, $m2)) {
        $direct_link = "https:" . $m2[1] . substr($m2[2], intval($m2[3]));
    } else if (preg_match('/id="norobotlink"[^>]*>(.*?)<\/div>/i', $html, $m3)) {
        $direct_link = "https:" . trim($m3[1]);
    }
    if (empty($direct_link)) return '';
    if (strpos($direct_link, 'stream=1') === false) {
        $direct_link .= (strpos($direct_link, '?') !== false ? '&stream=1' : '?stream=1');
    }
    $ch2 = curl_init();
    curl_setopt($ch2, CURLOPT_URL, $direct_link);
    curl_setopt($ch2, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch2, CURLOPT_NOBODY, true);
    curl_setopt($ch2, CURLOPT_FOLLOWLOCATION, false);
    curl_setopt($ch2, CURLOPT_HTTPHEADER, ['User-Agent: Mozilla/5.0', 'Referer: https://streamtape.com/']);
    curl_setopt($ch2, CURLOPT_TIMEOUT, 10);
    curl_exec($ch2);
    $redirect_url = curl_getinfo($ch2, CURLINFO_REDIRECT_URL);
    curl_close($ch2);
    return !empty($redirect_url) ? $redirect_url : $direct_link;
}

// Decide a streamtape-family embed page verdict based on VERIFIED signals:
//   - HTTP 404/410              DEAD (video gone)
//   - body has "Video not found" / "deleted by the creator"  DEAD
//   - body has robotlink/get_video  LIVE (real player exists)
//   - blocked/timeout (403/429/0)  UNCERTAIN (never kill on uncertainty)
function streamtape_embed_verdict($html, $code) {
    $code = intval($code);
    if ($code === 404 || $code === 410) return 'dead';
    if ($code >= 200 && $code < 400) {
        if (streamtape_embed_is_dead($html)) return 'dead';
        if ($html && (strpos($html, 'robotlink') !== false || strpos($html, 'get_video') !== false)) {
            $direct = extract_streamtape_direct_from_html($html);
            if (!empty($direct)) return 'live';
        }
        return 'uncertain'; // 200 but no playable marker parsed
    }
    return 'uncertain'; // 403/429/timeout/other
}

// Single-link health check  VERIFIED 100% logic.
function http_health_check($url, $timeout = 8) {
    if (empty($url)) return ["ok" => false, "code" => 0, "direct" => ""];
    $url = trim($url);
    if (strpos($url, ' ') !== false) {
        $url = str_replace(' ', '%20', $url);
    }
    if (is_streamtape_link($url)) {
        $vid = streamtape_video_id($url);
        $ownHost = strtolower(parse_url($url, PHP_URL_HOST) ?: '');
        // Prefer the SAME host the link uses (e.g. advtpe.com) that's the
        // authoritative source. Fall back to a couple mirrors only if blocked.
        $hosts = [];
        if ($ownHost !== '') $hosts[] = $ownHost;
        foreach (streamtape_mirror_hosts() as $m) {
            if (!in_array($m, $hosts)) $hosts[] = $m;
        }

        $verdict = 'uncertain';
        foreach ($hosts as $i => $h) {
            $embed = "https://" . $h . "/e/" . $vid;
            $ch0 = curl_init();
            curl_setopt($ch0, CURLOPT_URL, $embed);
            curl_setopt($ch0, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch0, CURLOPT_FOLLOWLOCATION, true);
            curl_setopt($ch0, CURLOPT_MAXREDIRS, 4);
            curl_setopt($ch0, CURLOPT_USERAGENT, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36");
            curl_setopt($ch0, CURLOPT_HTTPHEADER, ['Referer: https://streamtape.com/', 'Accept-Language: en-US,en;q=0.9']);
            curl_setopt($ch0, CURLOPT_TIMEOUT, $timeout);
            $html = curl_exec($ch0);
            $embedCode = intval(curl_getinfo($ch0, CURLINFO_HTTP_CODE));
            curl_close($ch0);

            $v = streamtape_embed_verdict($html, $embedCode);
            if ($v === 'live' || $v === 'dead') {
                $verdict = $v;
                break;
            }
            // Same host uncertain (blocked) try the /v/ watch page as tiebreaker
            if ($i === 0 && $v === 'uncertain') {
                $vurl = "https://" . $h . "/v/" . $vid;
                $ch1 = curl_init();
                curl_setopt($ch1, CURLOPT_URL, $vurl);
                curl_setopt($ch1, CURLOPT_RETURNTRANSFER, true);
                curl_setopt($ch1, CURLOPT_FOLLOWLOCATION, true);
                curl_setopt($ch1, CURLOPT_MAXREDIRS, 4);
                curl_setopt($ch1, CURLOPT_USERAGENT, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36");
                curl_setopt($ch1, CURLOPT_HTTPHEADER, ['Referer: https://streamtape.com/', 'Accept-Language: en-US,en;q=0.9']);
                curl_setopt($ch1, CURLOPT_TIMEOUT, $timeout);
                $vbody = curl_exec($ch1);
                $vcode = intval(curl_getinfo($ch1, CURLINFO_HTTP_CODE));
                curl_close($ch1);
                if ($vcode === 404 || $vcode === 410) {
                    $verdict = 'dead';
                    break;
                }
                if ($vcode >= 200 && $vcode < 400 && $vbody &&
                    (strpos($vbody, 'get_video') !== false || strpos($vbody, 'robotlink') !== false)) {
                    $verdict = 'live';
                    break;
                }
            }
        }

        if ($verdict === 'dead') return ["ok" => false, "code" => 404, "direct" => ""];
        if ($verdict === 'live') return ["ok" => true, "code" => 200, "direct" => ""];
        // Truly uncertain never kill a live link. Default to LIVE.
        return ["ok" => true, "code" => 200, "direct" => ""];
    }
    // Non-streamtape fallback
    $low = strtolower($url);
    $referer = 'https://streamtape.com/';
    if (strpos($low, 'ixifile') !== false || strpos($low, 'uncutmasti') !== false) {
        $referer = 'https://uncutmasti.com/';
    } else if (strpos($low, 'hdmaal') !== false) {
        $referer = 'https://hdmaal.gg/';
    } else if (strpos($low, 'hdmove99') !== false) {
        $referer = 'https://hdmove99.com/';
    } else if (strpos($low, 'skymovies') !== false) {
        $referer = 'https://skymovieshd.ceo/';
    }

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_MAXREDIRS, 5);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
    curl_setopt($ch, CURLOPT_TIMEOUT, $timeout);
    curl_setopt($ch, CURLOPT_USERAGENT, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36");
    curl_setopt($ch, CURLOPT_HTTPHEADER, ["Referer: $referer", 'Accept-Language: en-US,en;q=0.9', 'Accept: */*']);
    $body = curl_exec($ch);
    $code = intval(curl_getinfo($ch, CURLINFO_HTTP_CODE));
    $errno = curl_errno($ch);
    curl_close($ch);

    $ok2 = ($code >= 200 && $code < 400) || $code === 416 || ($code === 0 && $errno === 28);
    return ["ok" => $ok2, "code" => $code, "direct" => $url];
}

// Extract the direct (CDN) url from a Streamtape embed page HTML body.
// Handles both the JS-obfuscated innerHTML patterns AND the plain
// <div id="robotlink">/host/get_video?...</div> format used by tapepops/advtpe.
function extract_streamtape_direct_from_html($html) {
    if (empty($html)) return '';
    $direct_link = "";
    // Pattern 1: document.getElementById('robotlink').innerHTML = 'pre'+ ('x').substring(a).substring(b);
    if (preg_match("/robotlink'\)\.innerHTML\s*=\s*'([^']*)'\s*\+\s*\('([^']*)'\)\.substring\((\d+)\)\.substring\((\d+)\)/i", $html, $m)) {
        $direct_link = "https:" . $m[1] . substr($m[2], intval($m[3]) + intval($m[4]));
    } else if (preg_match("/robotlink'\)\.innerHTML\s*=\s*'([^']*)'\s*\+\s*\('([^']*)'\)\.substring\((\d+)\)/i", $html, $m2)) {
        $direct_link = "https:" . $m2[1] . substr($m2[2], intval($m2[3]));
    } else if (preg_match('/id="norobotlink"[^>]*>(.*?)<\/div>/i', $html, $m3)) {
        $direct_link = "https:" . trim($m3[1]);
    }
    // Pattern 2: plain <div id="robotlink">/tapepops.com/get_video?id=...&token=...</div>
    if (empty($direct_link) && preg_match('/id="robotlink"[^>]*>(.*?)<\/div>/is', $html, $m4)) {
        $direct_link = trim($m4[1]);
    }
    // Normalize host-relative /host/path  https://host/path, and //host/path  https://host/path
    if (!empty($direct_link)) {
        if (preg_match('#^/([^/]+)(/.*)$#', $direct_link, $m5)) {
            $direct_link = "https://" . $m5[1] . $m5[2];
        } elseif (strpos($direct_link, '//') === 0) {
            $direct_link = "https:" . $direct_link;
        } elseif (strpos($direct_link, 'http') !== 0) {
            $direct_link = "https://" . $direct_link;
        }
    }
    if (empty($direct_link)) return '';
    if (strpos($direct_link, 'stream=1') === false) {
        $direct_link .= (strpos($direct_link, '?') !== false ? '&stream=1' : '?stream=1');
    }
    return $direct_link;
}

// Check if a Streamtape embed page indicates a deleted/removed video.
// Uses ONLY specific deletion phrases  never bare "404"/"not found" which
// appear in normal page JS. Empty/blocked HTML is NOT dead (uncertain).
function streamtape_embed_is_dead($html) {
    if (empty($html)) return false;
    return preg_match('/video not found|file not found|video deleted|file deleted|has been removed|removed by uploader|not available anymore|this video has been removed|video is no longer available|deleted by the creator|content was removed|does not exist anymore|no longer exist|maybe it got deleted/i', $html);
}

// Direct-URL (CDN) check for streamtape-family links: dead only on specific phrases.
function streamtape_direct_is_dead($body) {
    if (empty($body)) return false;
    return preg_match('/video not found|file not found|video deleted|file deleted|has been removed|removed by uploader|not available anymore|this video has been removed|video is no longer available|does not exist|invalid file|deleted by the creator/i', $body);
}

// Direct media file links (MP4/MKV/etc) are checked by HTTP status only.
function is_direct_media_link($url) {
    if (empty($url)) return false;
    $path = strtolower(parse_url($url, PHP_URL_PATH) ?: '');
    foreach (['.mp4', '.mkv', '.webm', '.m4v', '.mov', '.avi', '.ts', '.m3u8', '.mp3', '.aac', '.flv', '.wmv', '.mpg', '.mpeg'] as $ext) {
        if (substr($path, -strlen($ext)) === $ext) return true;
    }
    return false;
}

// Broad dead-page signature scan for hosted video pages (doodstream, etc).
function page_has_dead_signature($body) {
    if (empty($body)) return false;
    if (preg_match('/video not found|file not found|video deleted|file deleted|has been removed|removed by uploader|not available anymore|this video has been removed|video is no longer available|does not exist|invalid file|page not found|content not found|no longer available|video.*removed|file.*not found|not found|404|error 404|sorry.*not found|takedown|expired/i', $body)) {
        return true;
    }
    if (preg_match('/<title[^>]*>(.*?)<\/title>/is', $body, $tm) &&
        preg_match('/not found|deleted|removed|404|error|unavailable/i', $tm[1])) {
        return true;
    }
    return false;
}
// Parallel link health check using curl_multi  dramatically faster than
// sequential http_health_check when scanning large batches.
// $links: list of ['id' => int, 'url' => string]
// Returns: [ id => ['ok' => bool, 'code' => int] ]
//
// VERIFIED 100% logic (tested on advtpe.com live+dead pairs):
//   DEAD: embed HTTP 404/410, or body says "Video not found"/"deleted by the creator"
//   LIVE: embed HTTP 200 + robotlink/get_video player present
//   UNCERTAIN (403/429/timeout/200-no-marker): verify via /v/ watch page,
//         then default to LIVE. We never kill a link on uncertainty.
function batch_health_check($links, $timeout = 8) {
    $results = [];
    if (empty($links)) return $results;

    // Phase 1: fetch streamtape embed pages in parallel (same-host first).
    $mh = curl_multi_init();
    $embedHandles = [];  // handleId => curl handle
    $embedLink = [];     // handleId => link id
    $embedHost = [];     // handleId => host
    $embedOrder = [];    // handleId => order (0 = same host)
    $checkUrl = [];      // id => url to check directly (non-streamtape)
    $isSt = [];          // id => bool
    $isDirect = [];      // id => bool (direct .mp4/.mkv etc)
    $origUrl = [];       // id => original url

    $nextHandle = 0;
    foreach ($links as $l) {
        $url = trim($l['url'] ?? '');
        if ($url === '') { $results[$l['id']] = ["ok" => false, "code" => 0]; continue; }
        $origUrl[$l['id']] = $url;
        if (is_streamtape_link($url)) {
            $isSt[$l['id']] = true;
            $vid = streamtape_video_id($url);
            $ownHost = strtolower(parse_url($url, PHP_URL_HOST) ?: '');
            $hosts = [];
            if ($ownHost !== '') $hosts[] = $ownHost;
            foreach (streamtape_mirror_hosts() as $m) {
                if (!in_array($m, $hosts)) $hosts[] = $m;
            }
            foreach ($hosts as $idx => $h) {
                $embed = "https://" . $h . "/e/" . $vid;
                $ch = curl_init();
                curl_setopt($ch, CURLOPT_URL, $embed);
                curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
                curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
                curl_setopt($ch, CURLOPT_MAXREDIRS, 4);
                curl_setopt($ch, CURLOPT_USERAGENT, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36");
                curl_setopt($ch, CURLOPT_HTTPHEADER, ['Referer: https://streamtape.com/', 'Accept-Language: en-US,en;q=0.9']);
                curl_setopt($ch, CURLOPT_TIMEOUT, $timeout);
                curl_multi_add_handle($mh, $ch);
                $embedHandles[$nextHandle] = $ch;
                $embedLink[$nextHandle] = $l['id'];
                $embedHost[$nextHandle] = $h;
                $embedOrder[$nextHandle] = $idx;
                $nextHandle++;
            }
        } else {
            $isDirect[$l['id']] = is_direct_media_link($url);
            $checkUrl[$l['id']] = $url;
        }
    }

    if (!empty($embedHandles)) {
        $running = null;
        do {
            $mrc = curl_multi_exec($mh, $running);
            if ($running > 0) curl_multi_select($mh, 0.2);
        } while ($running > 0);

        // Per link: collect verdicts
        $linkEmbed = [];
        foreach ($embedHandles as $hid => $ch) {
            $html = curl_multi_getcontent($ch);
            $code = intval(curl_getinfo($ch, CURLINFO_HTTP_CODE));
            curl_multi_remove_handle($mh, $ch);
            curl_close($ch);
            $id = $embedLink[$hid];
            $v = streamtape_embed_verdict($html, $code);
            $linkEmbed[$id][] = $v;
        }
        curl_multi_close($mh);

        foreach ($linkEmbed as $id => $verdicts) {
            $sameHostVerdict = $verdicts[0] ?? 'uncertain';
            if ($sameHostVerdict === 'dead') {
                $results[$id] = ["ok" => false, "code" => 404];
                continue;
            }
            if ($sameHostVerdict === 'live') {
                $results[$id] = ["ok" => true, "code" => 200];
                continue;
            }
            if (in_array('live', $verdicts)) {
                $results[$id] = ["ok" => true, "code" => 200];
                continue;
            }
            $original = trim($origUrl[$id] ?? '');
            if (!empty($original)) {
                $checkUrl[$id] = $original;
            } else {
                $results[$id] = ["ok" => true, "code" => 200];
            }
        }
    }

    // Phase 2: check direct/fallback URLs
    if (!empty($checkUrl)) {
        $mh2 = curl_multi_init();
        $handles2 = [];
        foreach ($checkUrl as $id => $url) {
            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $url);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
            curl_setopt($ch, CURLOPT_MAXREDIRS, 5);
            curl_setopt($ch, CURLOPT_TIMEOUT, $timeout);
            curl_setopt($ch, CURLOPT_RANGE, isset($isDirect[$id]) && $isDirect[$id] ? '0-2047' : '0-65535');
            curl_setopt($ch, CURLOPT_USERAGENT, "Mozilla/5.0");
            curl_setopt($ch, CURLOPT_HTTPHEADER, ['Referer: https://streamtape.com/']);
            curl_multi_add_handle($mh2, $ch);
            $handles2[$id] = $ch;
        }
        $running = null;
        do {
            curl_multi_exec($mh2, $running);
            if ($running > 0) curl_multi_select($mh2, 0.2);
        } while ($running > 0);

        foreach ($handles2 as $id => $ch) {
            $code = intval(curl_getinfo($ch, CURLINFO_HTTP_CODE));
            $errno = curl_errno($ch);
            $ctype = strtolower((string) curl_getinfo($ch, CURLINFO_CONTENT_TYPE));
            $body = curl_multi_getcontent($ch);
            curl_multi_remove_handle($mh2, $ch);
            curl_close($ch);
            $ok = false;
            if (isset($isSt[$id])) {
                if ($code === 404 || $code === 410) { $ok = false; }
                else if ($code >= 200 && $code < 400) {
                    if (strpos($ctype, 'text/html') !== false) {
                        $ok = ($body && (strpos($body, 'get_video') !== false || strpos($body, 'robotlink') !== false))
                              ? true : !streamtape_direct_is_dead($body);
                    } else { $ok = true; }
                } else { $ok = true; }
            } else if ($errno === 0 && $code > 0) {
                if ($code >= 200 && $code < 400) {
                    if (isset($isDirect[$id]) && $isDirect[$id]) { $ok = strpos($ctype, 'text/html') === false; }
                    else if (strpos($ctype, 'text/html') !== false) { $ok = !page_has_dead_signature($body); }
                    else { $ok = true; }
                } else { $ok = false; }
            } else {
                $ok = isset($isDirect[$id]) && $isDirect[$id] ? false : true;
            }
            $results[$id] = ["ok" => $ok, "code" => $code];
        }
        curl_multi_close($mh2);
    }

    return $results;
}

function get_all_play_links($pdo) {
    $all = [];
    $stmt = $pdo->query("SELECT id, 'movie_play' as source, movie_id as content_id, url, name, quality, 'movie' as content_type FROM movie_play_links WHERE status = 1");
    $all = array_merge($all, $stmt->fetchAll());
    $stmt = $pdo->query("SELECT epl.id, 'episode_play' as source, epl.episode_id as content_id, epl.url, epl.name, epl.quality, 'episode' as content_type FROM episode_play_links epl WHERE epl.status = 1");
    $all = array_merge($all, $stmt->fetchAll());
    return $all;
}

function safe_count($pdo, $sql) {
    try { return intval($pdo->query($sql)->fetchColumn()); } catch (Exception $e) { return 0; }
}

function check_and_do_weekly_reset($pdo) {
    try {
        @$pdo->exec("CREATE TABLE IF NOT EXISTS app_settings (`key` VARCHAR(100) NOT NULL PRIMARY KEY, `value` TEXT NOT NULL DEFAULT '') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    } catch (Exception $e) { return; }
    try {
        $row = @$pdo->query("SELECT `value` FROM app_settings WHERE `key` = 'last_weekly_reset'")->fetchColumn();
        $lastReset = $row ? @strtotime($row) : 0;
        $now = time();
        $todayStr = date('Y-m-d', $now);
        $lastResetStr = $lastReset ? date('Y-m-d', $lastReset) : '';
        if (date('N', $now) == 1 && $lastResetStr !== $todayStr) {
            @$pdo->exec("UPDATE movies SET weekly_views = 0");
            @$pdo->exec("UPDATE web_series SET weekly_views = 0");
            @$pdo->exec("REPLACE INTO app_settings (`key`, `value`) VALUES ('last_weekly_reset', '$todayStr')");
        }
    } catch (Exception $e) {}
}

try {
    $hasV1 = $pdo->query("SHOW COLUMNS FROM movies LIKE 'views'")->fetch();
    if (!$hasV1) $pdo->exec("ALTER TABLE movies ADD COLUMN views INT NOT NULL DEFAULT 0");
    $hasV2 = $pdo->query("SHOW COLUMNS FROM movies LIKE 'weekly_views'")->fetch();
    if (!$hasV2) $pdo->exec("ALTER TABLE movies ADD COLUMN weekly_views INT NOT NULL DEFAULT 0");
    $hasWV1 = $pdo->query("SHOW COLUMNS FROM web_series LIKE 'views'")->fetch();
    if (!$hasWV1) $pdo->exec("ALTER TABLE web_series ADD COLUMN views INT NOT NULL DEFAULT 0");
    $hasWV2 = $pdo->query("SHOW COLUMNS FROM web_series LIKE 'weekly_views'")->fetch();
    if (!$hasWV2) $pdo->exec("ALTER TABLE web_series ADD COLUMN weekly_views INT NOT NULL DEFAULT 0");
} catch (Exception $e) {}

//
// 1. LIST ALL MOVIES
//
if ($action === 'get_parked_ids') {
    // Only hide content that has status=0 OR has NO active play links at all.
    // Do NOT hide content just because it has SOME dead links  it may still have active ones.
    $parked_m = $pdo->query("
        SELECT m.id, m.name FROM movies m
        WHERE m.status = 0
           OR NOT EXISTS (SELECT 1 FROM movie_play_links a WHERE a.movie_id = m.id AND a.status = 1)
    ")->fetchAll();

    $parked_s = $pdo->query("
        SELECT s.id, s.name FROM web_series s
        WHERE s.status = 0
           OR NOT EXISTS (
               SELECT 1 FROM web_series_episoade aep
               JOIN episode_play_links aepl ON aepl.episode_id = aep.id AND aepl.status = 1
               WHERE aep.season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = s.id)
           )
    ")->fetchAll();

    $movie_ids   = array_map(function($r) { return intval($r['id']); }, $parked_m);
    $series_ids  = array_map(function($r) { return intval($r['id']); }, $parked_s);
    $movie_names = array_map(function($r) { return trim($r['name']); }, $parked_m);
    $series_names= array_map(function($r) { return trim($r['name']); }, $parked_s);

    json_response(true, [
        "movie_ids"    => $movie_ids,
        "series_ids"   => $series_ids,
        "movie_names"  => $movie_names,
        "series_names" => $series_names
    ], "Parked IDs fetched");
}

if ($action === 'list_movies') {
    try { $pdo->exec("DELETE FROM movie_play_links WHERE status = 0"); } catch(Exception $e){}

    $movies = $pdo->query("SELECT m.*, 
        IFNULL(m.views, 0) as views,
        IFNULL(m.weekly_views, 0) as weekly_views,
        (SELECT COUNT(*) FROM movie_play_links WHERE movie_id = m.id AND status = 1) as active_links,
        0 as dead_links,
        (SELECT ct.name FROM custom_tag_log ctl JOIN custom_tags ct ON ct.id = ctl.custom_tags_id WHERE ctl.content_id = m.id AND ctl.content_type = 1 ORDER BY ctl.id DESC LIMIT 1) as custom_tag,
        (SELECT GROUP_CONCAT(network_id) FROM content_network_log WHERE content_id = m.id AND content_type = 1) as network_ids
        FROM movies m WHERE m.status = 1 ORDER BY m.id DESC")->fetchAll();
    if (!empty($movies)) {
        $ids = array_column($movies, 'id');
        $in = implode(',', array_map('intval', $ids));
        $links = $pdo->query("SELECT * FROM movie_play_links WHERE movie_id IN ($in) AND status = 1 ORDER BY movie_id ASC, link_order ASC")->fetchAll();
        $byMovie = [];
        foreach ($links as $l) { $byMovie[$l['movie_id']][] = $l; }
        foreach ($movies as &$m) { $m['play_links'] = $byMovie[$m['id']] ?? []; }
    }
    json_response(true, ["movies" => $movies], "Movies fetched");
}

//
// 2. LIST ALL WEB SERIES
//
if ($action === 'list_series') {
    $series = $pdo->query("SELECT ws.*, 
        (SELECT ct.name FROM custom_tag_log ctl JOIN custom_tags ct ON ct.id = ctl.custom_tags_id WHERE ctl.content_id = ws.id AND ctl.content_type = 2 ORDER BY ctl.id DESC LIMIT 1) as custom_tag,
        (SELECT GROUP_CONCAT(network_id) FROM content_network_log WHERE content_id = ws.id AND content_type = 2) as network_ids
        FROM web_series ws WHERE ws.status = 1 ORDER BY ws.id DESC")->fetchAll();
    if (!empty($series)) {
        $ids = array_column($series, 'id');
        $in = implode(',', array_map('intval', $ids));
        $seasons = $pdo->query("SELECT * FROM web_series_seasons WHERE web_series_id IN ($in) AND status = 1 ORDER BY web_series_id ASC, season_order ASC")->fetchAll();
        $seasonBySeries = [];
        $seasonIds = [];
        foreach ($seasons as $s) { $seasonBySeries[$s['web_series_id']][] = $s; $seasonIds[] = $s['id']; }
        $episodes = [];
        if (!empty($seasonIds)) {
            $sin = implode(',', array_map('intval', $seasonIds));
            $episodes = $pdo->query("SELECT * FROM web_series_episoade WHERE season_id IN ($sin) ORDER BY season_id ASC, episoade_order ASC")->fetchAll();
        }
        $epBySeason = [];
        $epIds = [];
        foreach ($episodes as $e) { $epBySeason[$e['season_id']][] = $e; $epIds[] = $e['id']; }
        $links = [];
        if (!empty($epIds)) {
            $ein = implode(',', array_map('intval', $epIds));
            $links = $pdo->query("SELECT * FROM episode_play_links WHERE episode_id IN ($ein) ORDER BY episode_id ASC, link_order ASC")->fetchAll();
        }
        $linkByEp = [];
        foreach ($links as $l) { $linkByEp[$l['episode_id']][] = $l; }
        foreach ($series as &$s) {
            $ss = $seasonBySeries[$s['id']] ?? [];
            foreach ($ss as &$season) {
                $eps = $epBySeason[$season['id']] ?? [];
                foreach ($eps as &$ep) { $ep['play_links'] = $linkByEp[$ep['id']] ?? []; }
                $season['episodes'] = $eps;
            }
            $s['seasons'] = $ss;
        }
    }
    json_response(true, ["series" => $series], "Series fetched");
}

if ($action === 'get_taxonomy') {
    $ott = [];
    try {
        $ott = $pdo->query("SELECT id, name, icon, COALESCE(status, 1) as status FROM genres ORDER BY sort_order ASC, name ASC")->fetchAll();
    } catch (Exception $e) {
        $ott = $pdo->query("SELECT id, name, icon FROM genres ORDER BY name ASC")->fetchAll();
    }
    $cast = [];
    try {
        $cast = $pdo->query("SELECT id, name, logo FROM networks WHERE status = 1 ORDER BY networks_order ASC, name ASC")->fetchAll();
    } catch (Exception $e) {
        $cast = $pdo->query("SELECT id, name, logo FROM networks ORDER BY name ASC")->fetchAll();
    }
    $tags = [];
    try {
        $tags = $pdo->query("SELECT id, name, background_color, text_color FROM custom_tags ORDER BY name ASC")->fetchAll();
    } catch (Exception $e) {}
    json_response(true, ["ott_platforms" => $ott, "cast_networks" => $cast, "custom_tags" => $tags], "Taxonomy fetched");
}

if ($action === 'list_genres') {
    $genres = [];
    try {
        // Admin view: return ALL genres (active + hidden) with status and sort_order
        $genres = $pdo->query("SELECT id, name, icon, status, sort_order FROM genres ORDER BY sort_order ASC, name ASC")->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        try {
            $genres = $pdo->query("SELECT id, name, icon, COALESCE(status, 1) as status, 0 as sort_order FROM genres ORDER BY name ASC")->fetchAll(PDO::FETCH_ASSOC);
        } catch (Exception $e2) {
            $genres = [];
        }
    }
    json_response(true, ["genres" => $genres], "Genres fetched");
}

// Resolve a custom tag name to a custom_tags row (create if missing) and
// record it in custom_tag_log for the given content. content_type: 1=movie, 2=series.
function save_custom_tag($pdo, $tagName, $contentId, $contentType) {
    $tagName = trim($tagName);
    if ($tagName === '' || $contentId <= 0) return;
    try {
        // Reject raw PHP array/object dumps ("{ID: 11++ ...}") that sometimes
        // sneak into the field  only store clean short tags.
        if (strpos($tagName, '{') !== false || strpos($tagName, '++') !== false || strlen($tagName) > 20) {
            $tagName = 'HD';
        }
        $stmt = $pdo->prepare("SELECT id FROM custom_tags WHERE TRIM(name) = ? ORDER BY id DESC LIMIT 1");
        $stmt->execute([$tagName]);
        $tagId = $stmt->fetchColumn();
        if (!$tagId) {
            $pdo->prepare("INSERT INTO custom_tags (name, background_color, text_color, created_at, updated_at) VALUES (?, '#E50914', '#FFFFFF', ?, ?)")
                ->execute([$tagName, time(), time()]);
            $tagId = $pdo->lastInsertId();
        }
        $pdo->prepare("DELETE FROM custom_tag_log WHERE content_id = ? AND content_type = ?")->execute([$contentId, $contentType]);
        $pdo->prepare("INSERT INTO custom_tag_log (custom_tags_id, content_id, content_type) VALUES (?, ?, ?)")
            ->execute([$tagId, $contentId, $contentType]);
    } catch (Exception $e) {
        // Tables may not exist on some setups  ignore, content still saves.
    }
}

//
// 3. EDIT MOVIE
//
if ($action === 'edit_movie') {
    $id = intval($input['id'] ?? 0);
    if ($id <= 0) json_response(false, [], "Movie ID required");
    $fields = [];
    $params = [];
    foreach (['name','description','poster','banner','genres','release_date'] as $f) {
        if (isset($input[$f])) {
            $fields[] = "$f = ?";
            if ($f === 'genres') {
                $params[] = resolve_genre_names($pdo, $input[$f]);
            } else {
                $params[] = $input[$f];
            }
        }
    }
    if (!empty($fields)) {
        $params[] = $id;
        $pdo->prepare("UPDATE movies SET " . implode(", ", $fields) . " WHERE id = ?")->execute($params);
    }
    // Update cast networks in content_network_log
    if (isset($input['network'])) {
        $pdo->prepare("DELETE FROM content_network_log WHERE content_id = ? AND content_type = 1")->execute([$id]);
        $netIds = array_filter(explode(',', $input['network']));
        foreach ($netIds as $nid) {
            $pdo->prepare("INSERT INTO content_network_log (content_id, network_id, content_type) VALUES (?, ?, 1)")->execute([$id, intval($nid)]);
        }
    }
    // Update custom tag (custom_tag_log, content_type 1 = Movie)
    if (isset($input['custom_tag'])) {
        save_custom_tag($pdo, $input['custom_tag'], $id, 1);
    }
    if (isset($input['play_links'])) {
        $pdo->prepare("DELETE FROM movie_play_links WHERE movie_id = ?")->execute([$id]);
        if (is_array($input['play_links'])) {
            foreach ($input['play_links'] as $link) {
                if (!empty($link['url'])) {
                    $pdo->prepare("INSERT INTO movie_play_links (movie_id, name, quality, url, type, status, link_order, size, skip_available, intro_start, intro_end, end_credits_marker, link_type, drm_uuid, drm_license_uri) VALUES (?, ?, ?, ?, 'Streamtape', 1, ?, ' ', 0, ' ', ' ', ' ', 0, ' ', ' ')")->execute([$id, $link['name'] ?? 'Server 1', $link['quality'] ?? '720p', $link['url'], $link['order'] ?? 1]);
                }
            }
        }
    } elseif (isset($input['stream_url'])) {
        $pdo->prepare("DELETE FROM movie_play_links WHERE movie_id = ?")->execute([$id]);
        if (!empty($input['stream_url'])) {
            $pdo->prepare("INSERT INTO movie_play_links (movie_id, name, quality, url, type, status, link_order, size, skip_available, intro_start, intro_end, end_credits_marker, link_type, drm_uuid, drm_license_uri) VALUES (?, 'Server 1', '720p', ?, 'Streamtape', 1, 1, ' ', 0, ' ', ' ', ' ', 0, ' ', ' ')")->execute([$id, $input['stream_url']]);
        }
    }
    json_response(true, [], "Movie updated");
}

//
// 4. DELETE MOVIE (soft)
//


//
// 5. EDIT SERIES
//
if ($action === 'edit_series') {
    $id = intval($input['id'] ?? 0);
    if ($id <= 0) json_response(false, [], "Series ID required");
    $fields = [];
    $params = [];
    foreach (['name','description','poster','banner','genres','release_date'] as $f) {
        if (isset($input[$f])) {
            $fields[] = "$f = ?";
            if ($f === 'genres') {
                $params[] = resolve_genre_names($pdo, $input[$f]);
            } else {
                $params[] = $input[$f];
            }
        }
    }
    if (!empty($fields)) {
        $params[] = $id;
        $pdo->prepare("UPDATE web_series SET " . implode(", ", $fields) . " WHERE id = ?")->execute($params);
    }
    // Update cast networks in content_network_log
    if (isset($input['network'])) {
        $pdo->prepare("DELETE FROM content_network_log WHERE content_id = ? AND content_type = 2")->execute([$id]);
        $netIds = array_filter(explode(',', $input['network']));
        foreach ($netIds as $nid) {
            $pdo->prepare("INSERT INTO content_network_log (content_id, network_id, content_type) VALUES (?, ?, 2)")->execute([$id, intval($nid)]);
        }
    }
    // Update custom tag (custom_tag_log, content_type 2 = WebSeries)
    if (isset($input['custom_tag'])) {
        save_custom_tag($pdo, $input['custom_tag'], $id, 2);
    }
    json_response(true, [], "Series updated");
}

//
// 6. DELETE SERIES (soft)
//


//
// 7. ADD/EDIT EPISODE (alias for add_episode_link  Flutter compat)
//
if ($action === 'add_episode_link') {
    $series_id = intval($input['series_id'] ?? 0);
    $season_name = trim($input['season_name'] ?? 'Season 1');
    $name = trim($input['name'] ?? 'Episode');
    $url = trim($input['url'] ?? '');
    $stream_type = trim($input['stream_type'] ?? 'MP4/MKV Direct Link');
    $episode_image = trim($input['episode_image'] ?? '');
    $quality = trim($input['quality'] ?? 'HD');

    if ($series_id <= 0) json_response(false, [], "Series ID required");

    // Find or create season (trim match: DB names may contain trailing spaces)
    $season_id = 0;
    $stmt = $pdo->prepare("SELECT id FROM web_series_seasons WHERE web_series_id = ? AND TRIM(Session_Name) = TRIM(?) AND status = 1");
    $stmt->execute([$series_id, $season_name]);
    $season = $stmt->fetch();
    if ($season) {
        $season_id = $season['id'];
    } else {
        $stmt = $pdo->prepare("INSERT INTO web_series_seasons (web_series_id, Session_Name, season_order, status) VALUES (?, ?, ?, 1)");
        $stmt->execute([$series_id, $season_name, 1]);
        $season_id = $pdo->lastInsertId();
    }

    // Create episode with image (include all NOT NULL columns  strict SQL mode)
    $stmt = $pdo->prepare("INSERT INTO web_series_episoade (season_id, Episoade_Name, episoade_image, episoade_description, episoade_order, downloadable, type, source, url, skip_available, intro_start, intro_end, end_credits_marker, drm_uuid, drm_license_uri, status) VALUES (?, ?, ?, '', 1, 1, 0, ' ', ' ', 0, ' ', ' ', ' ', ' ', ' ', 1)");
    $stmt->execute([$season_id, $name, $episode_image]);
    $ep_id = $pdo->lastInsertId();

    // Add play links if play_links array or URL provided
    if ($ep_id > 0) {
        if (isset($input['play_links']) && is_array($input['play_links'])) {
            $pdo->prepare("DELETE FROM episode_play_links WHERE episode_id = ?")->execute([$ep_id]);
            $ord = 1;
            foreach ($input['play_links'] as $link) {
                if (!empty($link['url'])) {
                    $st_type = $link['type'] ?? 'MP4/MKV Direct Link';
                    $st_name = $link['name'] ?? ("Server " . $ord);
                    $st_qual = $link['quality'] ?? $quality;
                    $pdo->prepare("INSERT INTO episode_play_links (episode_id, name, quality, url, type, status, link_order, size, skip_available, intro_start, intro_end, end_credits_marker, link_type, drm_uuid, drm_license_uri) VALUES (?, ?, ?, ?, ?, 1, ?, ' ', 0, ' ', ' ', ' ', 0, ' ', ' ')")->execute([$ep_id, $st_name, $st_qual, $link['url'], $st_type, $ord]);
                    $ord++;
                }
            }
        } elseif (!empty($url)) {
            $pdo->prepare("DELETE FROM episode_play_links WHERE episode_id = ?")->execute([$ep_id]);
            $pdo->prepare("INSERT INTO episode_play_links (episode_id, name, quality, url, type, status, link_order, size, skip_available, intro_start, intro_end, end_credits_marker, link_type, drm_uuid, drm_license_uri) VALUES (?, 'Server 1', ?, ?, ?, 1, 1, ' ', 0, ' ', ' ', ' ', 0, ' ', ' ')")->execute([$ep_id, $quality, $url, $stream_type]);
        }
    }

    json_response(true, ["episode_id" => $ep_id, "season_id" => $season_id], "Episode added");
}

//
// 7b. SAVE EPISODE (existing, kept for compatibility)
//
if ($action === 'save_episode' || $action === 'update_episode') {
    $ep_id = intval($input['episode_id'] ?? $input['id'] ?? 0);
    $season_id = intval($input['season_id'] ?? 0);
    $name = trim($input['name'] ?? $input['Episoade_Name'] ?? 'Episode');
    $image = trim($input['image'] ?? $input['episoade_image'] ?? '');
    $desc = trim($input['description'] ?? '');
    $order = intval($input['order'] ?? 1);
    $quality = trim($input['quality'] ?? '720p');
    $stream_type = trim($input['stream_type'] ?? 'MP4/MKV Direct Link');

    if ($ep_id > 0) {
        $pdo->prepare("UPDATE web_series_episoade SET Episoade_Name = ?, episoade_image = ?, episoade_description = ?, episoade_order = ? WHERE id = ?")->execute([$name, $image, $desc, $order, $ep_id]);
    } else {
        $pdo->prepare("INSERT INTO web_series_episoade (season_id, Episoade_Name, episoade_image, episoade_description, episoade_order, downloadable, type, source, url, skip_available, intro_start, intro_end, end_credits_marker, drm_uuid, drm_license_uri, status) VALUES (?, ?, ?, ?, ?, 1, 0, ' ', ' ', 0, ' ', ' ', ' ', ' ', ' ', 1)")->execute([$season_id, $name, $image, $desc, $order]);
        $ep_id = $pdo->lastInsertId();
    }

    if ($ep_id > 0) {
        if (isset($input['play_links']) && is_array($input['play_links'])) {
            $pdo->prepare("DELETE FROM episode_play_links WHERE episode_id = ?")->execute([$ep_id]);
            $ord = 1;
            foreach ($input['play_links'] as $link) {
                if (!empty($link['url'])) {
                    $st_type = $link['type'] ?? 'MP4/MKV Direct Link';
                    $st_name = $link['name'] ?? ("Server " . $ord);
                    $st_qual = $link['quality'] ?? $quality;
                    $pdo->prepare("INSERT INTO episode_play_links (episode_id, name, quality, url, type, status, link_order, size, skip_available, intro_start, intro_end, end_credits_marker, link_type, drm_uuid, drm_license_uri) VALUES (?, ?, ?, ?, ?, 1, ?, ' ', 0, ' ', ' ', ' ', 0, ' ', ' ')")->execute([$ep_id, $st_name, $st_qual, $link['url'], $st_type, $ord]);
                    $ord++;
                }
            }
        } else {
            $stream_url = trim($input['stream_url'] ?? $input['url'] ?? '');
            if (!empty($stream_url)) {
                $pdo->prepare("DELETE FROM episode_play_links WHERE episode_id = ?")->execute([$ep_id]);
                $pdo->prepare("INSERT INTO episode_play_links (episode_id, name, quality, url, type, status, link_order, size, skip_available, intro_start, intro_end, end_credits_marker, link_type, drm_uuid, drm_license_uri) VALUES (?, 'Server 1', ?, ?, ?, 1, 1, ' ', 0, ' ', ' ', ' ', 0, ' ', ' ')")->execute([$ep_id, $quality, $stream_url, $stream_type]);
            }
        }
    }
    json_response(true, ["episode_id" => $ep_id], "Episode saved successfully");
}

//
// 7c. LIST USERS
//
if ($action === 'list_users') {
    $stmt = $pdo->query("SELECT * FROM user_db ORDER BY id DESC");
    $users = $stmt->fetchAll();
    json_response(true, ["users" => $users], "Users fetched");
}

if ($action === 'get_user_telemetry') {
    $user_id = intval($input['user_id'] ?? $_GET['user_id'] ?? 0);
    if ($user_id <= 0) json_response(false, [], "User ID required");

    // 1. Active session details
    $active_stmt = $pdo->prepare("
        SELECT act.current_view, act.last_ping, act.content_id, act.content_type,
               CASE WHEN act.content_type = 1 THEN m.name ELSE s.name END as content_name
        FROM active_sessions act
        LEFT JOIN movies m ON act.content_id = m.id AND act.content_type = 1
        LEFT JOIN web_series s ON act.content_id = s.id AND act.content_type = 2
        WHERE act.user_id = ?
    ");
    $active_stmt->execute([$user_id]);
    $active_session = $active_stmt->fetch() ?: null;

    // 2. Play history/analytics
    $history_stmt = $pdo->prepare("
        SELECT wh.*, 
               CASE WHEN wh.content_type = 1 THEN m.name ELSE s.name END as content_name 
        FROM watch_history_analytics wh 
        LEFT JOIN movies m ON wh.content_id = m.id AND wh.content_type = 1 
        LEFT JOIN web_series s ON wh.content_id = s.id AND wh.content_type = 2 
        WHERE wh.user_id = ? 
        ORDER BY wh.id DESC LIMIT 30
    ");
    $history_stmt->execute([$user_id]);
    $play_history = $history_stmt->fetchAll();

    // 3. Download statistics
    $download_stmt = $pdo->prepare("
        SELECT ds.*, 
               CASE WHEN ds.content_type = 1 THEN m.name ELSE s.name END as content_name 
        FROM download_statistics ds 
        LEFT JOIN movies m ON ds.content_id = m.id AND ds.content_type = 1 
        LEFT JOIN web_series s ON ds.content_id = s.id AND ds.content_type = 2 
        WHERE ds.user_id = ? 
        ORDER BY ds.id DESC LIMIT 30
    ");
    $download_stmt->execute([$user_id]);
    $downloads = $download_stmt->fetchAll();

    // 4. Total playtime calculation
    $playtime_stmt = $pdo->prepare("SELECT SUM(duration_seconds) as total_playtime FROM watch_history_analytics WHERE user_id = ?");
    $playtime_stmt->execute([$user_id]);
    $playtime_row = $playtime_stmt->fetch();
    $total_playtime_sec = intval($playtime_row['total_playtime'] ?? 0);

    json_response(true, [
        "active_session" => $active_session,
        "play_history" => $play_history,
        "downloads" => $downloads,
        "total_playtime_seconds" => $total_playtime_sec
    ], "User telemetry fetched");
}

if ($action === 'get_dashboard_telemetry') {
    // 1. Live Users list (active sessions in the last 5 minutes)
    $live_stmt = $pdo->query("
        SELECT act.user_id, act.current_view, act.last_ping, act.content_id, act.content_type,
               u.name as user_name, u.email as user_email, u.app_version,
               CASE WHEN act.content_type = 1 THEN m.name ELSE s.name END as content_name
        FROM active_sessions act
        LEFT JOIN user_db u ON act.user_id = u.id
        LEFT JOIN movies m ON act.content_id = m.id AND act.content_type = 1
        LEFT JOIN web_series s ON act.content_id = s.id AND act.content_type = 2
        WHERE act.last_ping >= NOW() - INTERVAL 5 MINUTE
        ORDER BY act.last_ping DESC
    ");
    $live_users = $live_stmt->fetchAll();

    // 2. Top 10 Playtime Users
    $top_users_stmt = $pdo->query("
        SELECT wh.user_id, SUM(wh.duration_seconds) as total_playtime_seconds,
               u.name as user_name, u.email as user_email, u.app_version
        FROM watch_history_analytics wh
        LEFT JOIN user_db u ON wh.user_id = u.id
        GROUP BY wh.user_id, u.name, u.email, u.app_version
        ORDER BY total_playtime_seconds DESC LIMIT 10
    ");
    $top_users = $top_users_stmt->fetchAll();

    // 3. Top 10 Downloads
    $top_downloads_stmt = $pdo->query("
        SELECT ds.content_id, ds.content_type, COUNT(*) as download_count,
               CASE WHEN ds.content_type = 1 THEN m.name ELSE s.name END as content_name
        FROM download_statistics ds
        LEFT JOIN movies m ON ds.content_id = m.id AND ds.content_type = 1
        LEFT JOIN web_series s ON ds.content_id = s.id AND ds.content_type = 2
        GROUP BY ds.content_id, ds.content_type, content_name
        ORDER BY download_count DESC LIMIT 10
    ");
    $top_downloads = $top_downloads_stmt->fetchAll();

    // 4. Top 10 Played Content
    $top_played_stmt = $pdo->query("
        SELECT wh.content_id, wh.content_type, COUNT(*) as play_count, SUM(wh.duration_seconds) as total_playtime_seconds,
               CASE WHEN wh.content_type = 1 THEN m.name ELSE s.name END as content_name
        FROM watch_history_analytics wh
        LEFT JOIN movies m ON wh.content_id = m.id AND wh.content_type = 1
        LEFT JOIN web_series s ON wh.content_id = s.id AND wh.content_type = 2
        GROUP BY wh.content_id, wh.content_type, content_name
        ORDER BY play_count DESC LIMIT 10
    ");
    $top_played = $top_played_stmt->fetchAll();

    json_response(true, [
        "live_users" => $live_users,
        "top_users" => $top_users,
        "top_downloads" => $top_downloads,
        "top_played" => $top_played
    ], "Dashboard telemetry fetched");
}

if ($action === 'upload_image') {
    if (!isset($_FILES['image'])) {
        json_response(false, [], "No file uploaded");
    }
    $file = $_FILES['image'];
    if ($file['error'] !== UPLOAD_ERR_OK) {
        json_response(false, [], "Upload error: " . $file['error']);
    }

    // Validate image type using actual file content (not unreliable client-provided MIME)
    // Accept all common image formats
    $allowed_mime = [
        'image/jpeg', 'image/jpg', 'image/png', 'image/gif',
        'image/webp', 'image/heic', 'image/heif', 'image/avif',
        'image/bmp', 'image/x-bmp', 'image/tiff', 'image/svg+xml',
        'image/x-icon', 'image/vnd.microsoft.icon'
    ];
    // First try getimagesize() for reliable detection
    $img_info = @getimagesize($file['tmp_name']);
    $detected_mime = $img_info ? $img_info['mime'] : mime_content_type($file['tmp_name']);
    // Also allow by extension as fallback (for HEIC/AVIF which getimagesize may not detect)
    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    $allowed_ext = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif', 'avif', 'bmp', 'tiff', 'tif', 'svg', 'ico'];
    $valid_by_mime = in_array($detected_mime, $allowed_mime) || in_array($file['type'], $allowed_mime);
    $valid_by_ext  = in_array($ext, $allowed_ext);
    if (!$valid_by_mime && !$valid_by_ext) {
        json_response(false, [], "Invalid file type. Please upload any image file (JPEG, PNG, WEBP, HEIC, AVIF, GIF, BMP, etc.).");
    }

    // Create uploads directory if it doesn't exist
    $upload_dir = __DIR__ . '/uploads';
    if (!file_exists($upload_dir)) {
        mkdir($upload_dir, 0755, true);
    }
    // Generate unique filename, default to jpg if extension missing
    if (empty($ext) || !in_array($ext, $allowed_ext)) { $ext = 'jpg'; }
    $filename = 'img_' . uniqid() . '.' . $ext;
    $dest = $upload_dir . '/' . $filename;

    if (move_uploaded_file($file['tmp_name'], $dest)) {
        $protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? "https" : "http";
        $host = $_SERVER['HTTP_HOST'];
        $base_dir = dirname($_SERVER['SCRIPT_NAME']);
        $base_dir = rtrim($base_dir, '/\\');
        $public_url = "$protocol://$host$base_dir/uploads/$filename";
        json_response(true, ["url" => $public_url], "Image uploaded successfully");
    } else {
        json_response(false, [], "Failed to save uploaded file");
    }
}

if ($action === 'search_images') {
    $query = $input['query'] ?? $_POST['query'] ?? '';
    if (empty($query)) {
        json_response(false, [], "Empty query");
    }

    $urls = [];

    // --- Method 1: Bing Images (extract murl = full-res image URLs) ---
    $bing_url = "https://www.bing.com/images/search?q=" . urlencode($query) . "&form=HDRSC2";
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $bing_url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT        => 12,
        CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        CURLOPT_HTTPHEADER     => ['Accept-Language: en-US,en;q=0.9'],
    ]);
    $html = curl_exec($ch);
    curl_close($ch);

    if ($html) {
        // Extract murl (full-resolution image URLs) from Bing JSON blobs
        preg_match_all('/murl&quot;:&quot;(https?:\/\/[^&]+?)&quot;/', $html, $murl_matches);
        if (!empty($murl_matches[1])) {
            foreach ($murl_matches[1] as $img_url) {
                $img_url = html_entity_decode($img_url);
                if (filter_var($img_url, FILTER_VALIDATE_URL) && !in_array($img_url, $urls)) {
                    $urls[] = $img_url;
                }
            }
        }
        // Also try JSON format
        if (count($urls) < 5) {
            preg_match_all('/"murl":"(https?:\/\/[^"]+?)"/', $html, $json_matches);
            foreach ($json_matches[1] as $img_url) {
                if (filter_var($img_url, FILTER_VALIDATE_URL) && !in_array($img_url, $urls)) {
                    $urls[] = $img_url;
                }
            }
        }
    }

    // --- Method 2: DuckDuckGo Images (if Bing gives < 5 results) ---
    if (count($urls) < 5) {
        // Step 1: Get vqd token
        $ddg_html_url = 'https://html.duckduckgo.com/html/?q=' . urlencode($query);
        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL            => $ddg_html_url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_TIMEOUT        => 10,
            CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        ]);
        $ddg_html = curl_exec($ch);
        curl_close($ch);

        $vqd = null;
        if ($ddg_html) {
            if (preg_match('/name="vqd"\s+value="([^"]+)"/', $ddg_html, $m)) { $vqd = $m[1]; }
            elseif (preg_match('/vqd=([\d-]+)/', $ddg_html, $m)) { $vqd = $m[1]; }
        }

        if ($vqd) {
            $ddg_img_url = 'https://duckduckgo.com/i.js?' . http_build_query([
                'l' => 'us-en', 'o' => 'json', 'q' => $query, 'vqd' => $vqd, 'f' => ',,,', 'p' => '1'
            ]);
            $ch = curl_init();
            curl_setopt_array($ch, [
                CURLOPT_URL            => $ddg_img_url,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_FOLLOWLOCATION => true,
                CURLOPT_TIMEOUT        => 10,
                CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                CURLOPT_HTTPHEADER     => ['Referer: https://duckduckgo.com/', 'Accept: application/json, */*'],
            ]);
            $ddg_json = curl_exec($ch);
            curl_close($ch);
            $ddg_data = @json_decode($ddg_json, true);
            if (isset($ddg_data['results']) && is_array($ddg_data['results'])) {
                foreach ($ddg_data['results'] as $r) {
                    $img = $r['image'] ?? null;
                    if ($img && filter_var($img, FILTER_VALIDATE_URL) && !in_array($img, $urls)) {
                        $urls[] = $img;
                    }
                }
            }
        }
    }

    $urls = array_values(array_unique(array_slice($urls, 0, 40)));
    json_response(true, ["images" => $urls], count($urls) . " images found");
}

//
// 7d. LIST SUBSCRIPTION PLANS (auto-create table if missing)
//
if ($action === 'list_subscription_plans') {
    $pdo->exec("CREATE TABLE IF NOT EXISTS subscription (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        name TEXT NOT NULL,
        time INT NOT NULL,
        amount INT NOT NULL,
        currency INT NOT NULL DEFAULT 0,
        background TEXT NOT NULL,
        subscription_type INT NOT NULL DEFAULT 0,
        play_store_billing_product_id TEXT DEFAULT NULL,
        status INT NOT NULL DEFAULT 1
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    $pdo->exec("INSERT IGNORE INTO subscription (id, name, time, amount, currency, background, subscription_type, play_store_billing_product_id, status) VALUES (1, 'RED Premium +', 30, 130, 0, '', 123, '', 1)");
    $stmt = $pdo->query("SELECT * FROM subscription WHERE status = 1 ORDER BY amount ASC");
    json_response(true, ["plans" => $stmt->fetchAll()], "Plans fetched");
}

//
// 7e. GRANT VIP SUBSCRIPTION
//
if ($action === 'grant_vip') {
    $user_id = intval($input['user_id'] ?? 0);
    $plan_id = intval($input['plan_id'] ?? 0);
    if ($user_id <= 0 || $plan_id <= 0) json_response(false, [], "User and plan required");
    $stmt = $pdo->prepare("SELECT * FROM subscription WHERE id = ? AND status = 1");
    $stmt->execute([$plan_id]);
    $plan = $stmt->fetch();
    if (!$plan) json_response(false, [], "Invalid plan");
    $days = intval($plan['time']);
    $start = date('Y-m-d H:i:s');
    $exp = date('Y-m-d H:i:s', strtotime("+$days days"));
    $pdo->prepare("UPDATE user_db SET active_subscription = ?, subscription_type = ?, time = ?, amount = ?, subscription_start = ?, subscription_exp = ? WHERE id = ?")
        ->execute([$plan['name'], intval($plan['subscription_type']), $days, intval($plan['amount']), $start, $exp, $user_id]);
    log_subscription_history($pdo, $user_id, $plan['name'], $days, intval($plan['amount']), $start, $exp, 'Admin Panel');
    json_response(true, ["user_id" => $user_id], "VIP subscription granted");
}

//
// 7f. REVOKE VIP SUBSCRIPTION
//
if ($action === 'revoke_vip') {
    $user_id = intval($input['user_id'] ?? 0);
    if ($user_id <= 0) json_response(false, [], "User ID required");
    $pdo->prepare("UPDATE user_db SET active_subscription = 'Free', subscription_type = 0, time = 0, amount = 0, subscription_start = '0000-00-00', subscription_exp = '0000-00-00' WHERE id = ?")->execute([$user_id]);
    json_response(true, [], "VIP subscription revoked");
}

//
// 7g. COUPON GENERATOR
//
$pdo->exec("CREATE TABLE IF NOT EXISTS coupon (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name TEXT NOT NULL,
    coupon_code TEXT NOT NULL,
    time INT NOT NULL DEFAULT 0 COMMENT 'Days',
    time INT NOT NULL DEFAULT 0 COMMENT 'Days',
    amount INT NOT NULL DEFAULT 0,
    subscription_type INT NOT NULL DEFAULT 0,
    status INT NOT NULL DEFAULT 1,
    max_use INT NOT NULL DEFAULT 1,
    used INT NOT NULL DEFAULT 0,
    used_by TEXT NOT NULL,
    expire_date TEXT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

if ($action === 'list_coupons') {
    $stmt = $pdo->query("SELECT * FROM coupon ORDER BY id DESC");
    $coupons = $stmt->fetchAll();
    foreach ($coupons as &$c) {
        $users = [];
        foreach (array_filter(explode(',', $c['used_by'])) as $entry) {
            if (strpos($entry, ':') !== false) {
                list($uid, $uname) = explode(':', $entry, 2);
                $users[] = ["id" => $uid, "name" => $uname];
            } else {
                $users[] = ["id" => $entry, "name" => ""];
            }
        }
        $c['used_users'] = $users;
    }
    json_response(true, ["coupons" => $coupons], "Coupons fetched");
}

if ($action === 'create_coupon') {
    $code = strtoupper(trim($input['coupon_code'] ?? ''));
    $name = trim($input['name'] ?? $code);
    $plan_id = intval($input['plan_id'] ?? 0);
    $max_use = intval($input['max_use'] ?? 1);
    $expire_date = trim($input['expire_date'] ?? '');
    if (empty($code)) json_response(false, [], "Coupon code required");
    $check = $pdo->prepare("SELECT id FROM coupon WHERE coupon_code = ?");
    $check->execute([$code]);
    if ($check->fetch()) json_response(false, [], "Coupon code already exists");
    $time = intval($input['time'] ?? 0);
    $amount = intval($input['amount'] ?? 0);
    $stype = intval($input['subscription_type'] ?? 0);
    if ($plan_id > 0) {
        $planStmt = $pdo->prepare("SELECT * FROM subscription WHERE id = ? AND status = 1");
        $planStmt->execute([$plan_id]);
        $plan = $planStmt->fetch();
        if ($plan) {
            $name = trim($input['name'] ?? $plan['name']);
            $time = intval($plan['time']);
            $amount = intval($plan['amount']);
            $stype = intval($plan['subscription_type']);
        }
    }
    $pdo->prepare("INSERT INTO coupon (name, coupon_code, time, amount, subscription_type, status, max_use, used, used_by, expire_date) VALUES (?, ?, ?, ?, ?, 1, ?, 0, '', ?)")
        ->execute([$name, $code, $time, $amount, $stype, $max_use, $expire_date]);
    json_response(true, ["id" => $pdo->lastInsertId()], "Coupon created");
}

if ($action === 'delete_coupon') {
    $id = intval($input['id'] ?? 0);
    if ($id <= 0) json_response(false, [], "Coupon ID required");
    $pdo->prepare("DELETE FROM coupon WHERE id = ?")->execute([$id]);
    json_response(true, [], "Coupon deleted");
}

if ($action === 'toggle_coupon') {
    $id = intval($input['id'] ?? 0);
    if ($id <= 0) json_response(false, [], "Coupon ID required");
    $pdo->prepare("UPDATE coupon SET status = 1 - status WHERE id = ?")->execute([$id]);
    json_response(true, [], "Coupon status toggled");
}

//                                                          
// 7g1. APP SETTINGS (key/value store)
//                                                          
$pdo->exec("CREATE TABLE IF NOT EXISTS app_settings (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    skey TEXT NOT NULL,
    svalue TEXT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

if ($action === 'get_app_settings') {
    $stmt = $pdo->query("SELECT skey, svalue FROM app_settings");
    $settings = [];
    foreach ($stmt->fetchAll() as $row) {
        $settings[$row['skey']] = $row['svalue'];
    }
    json_response(true, ["settings" => $settings], "Settings fetched");
}

if ($action === 'save_app_settings') {
    $settings = $input['settings'] ?? [];
    if (is_array($settings)) {
        foreach ($settings as $k => $v) {
            $exists = $pdo->prepare("SELECT id FROM app_settings WHERE skey = ?");
            $exists->execute([$k]);
            if ($exists->fetch()) {
                $pdo->prepare("UPDATE app_settings SET svalue = ? WHERE skey = ?")->execute([strval($v), $k]);
            } else {
                $pdo->prepare("INSERT INTO app_settings (skey, svalue) VALUES (?, ?)")->execute([$k, strval($v)]);
            }
        }
    }
    json_response(true, [], "Settings saved");
}

//
// 2.5. ADD CONTENT (Movies or Web Series)
//
if ($action === 'add_content') {
    $item_type = trim($input['item_type'] ?? ''); // 'movie' or 'series'
    $name = trim($input['name'] ?? '');
    $description = trim($input['description'] ?? '');
    $poster = trim($input['poster'] ?? '');
    $banner = trim($input['banner'] ?? '');
    $release_date = trim($input['release_date'] ?? '');
    $runtime = trim($input['runtime'] ?? '');
    $youtube_trailer = trim($input['youtube_trailer'] ?? '');
    $custom_tag = trim($input['custom_tag'] ?? 'HD');
    $content_type_param = trim($input['content_type'] ?? 'Free');
    $type = (strtolower($content_type_param) !== 'free') ? 1 : 0;
    $downloadable = intval($input['downloadable'] ?? 0);
    $stream_url = trim($input['stream_url'] ?? '');
    $genres_input = trim($input['genres'] ?? '');
    $genres = resolve_genre_names($pdo, $genres_input);
    $network = trim($input['network'] ?? '');
    $status = intval($input['status'] ?? 1);

    if (empty($name)) {
        json_response(false, [], "Name is required");
    }

    if ($item_type === 'movie') {
        $contentId = 0;
        try {
            $stmt = $pdo->prepare("INSERT INTO movies (TMDB_ID, name, description, genres, release_date, runtime, poster, banner, youtube_trailer, downloadable, type, status, content_type, views, weekly_views) VALUES (0, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 1, 0, 0)");
            $stmt->execute([$name, $description, $genres, $release_date, $runtime, $poster, $banner, $youtube_trailer, $downloadable, $type]);
            $contentId = $pdo->lastInsertId();
        } catch (Exception $e) {
            json_response(false, [], "Failed to save movie: " . $e->getMessage());
        }

        if ($contentId > 0) {
            if (isset($input['play_links']) && is_array($input['play_links'])) {
                $ord = 1;
                foreach ($input['play_links'] as $link) {
                    if (!empty($link['url'])) {
                        $st_type = $link['type'] ?? 'MP4/MKV Direct Link';
                        $st_name = $link['name'] ?? ("Server " . $ord);
                        $st_qual = $link['quality'] ?? '720p';
                        try {
                            $pdo->prepare("INSERT INTO movie_play_links (movie_id, name, quality, url, type, status, link_order, size, skip_available, intro_start, intro_end, end_credits_marker, link_type, drm_uuid, drm_license_uri) VALUES (?, ?, ?, ?, ?, 1, ?, ' ', 0, ' ', ' ', ' ', 0, ' ', ' ')")
                                ->execute([$contentId, $st_name, $st_qual, $link['url'], $st_type, $ord]);
                        } catch (Exception $ex) {}
                        $ord++;
                    }
                }
            } elseif (!empty($stream_url)) {
                $st_type = $input['stream_type'] ?? 'MP4/MKV Direct Link';
                try {
                    $pdo->prepare("INSERT INTO movie_play_links (movie_id, name, quality, url, type, status, link_order, size, skip_available, intro_start, intro_end, end_credits_marker, link_type, drm_uuid, drm_license_uri) VALUES (?, 'Server 1', '720p', ?, ?, 1, 1, ' ', 0, ' ', ' ', ' ', 0, ' ', ' ')")
                        ->execute([$contentId, $stream_url, $st_type]);
                } catch (Exception $ex) {}
            }
        }

        if ($contentId > 0 && !empty($custom_tag)) {
            save_custom_tag($pdo, $custom_tag, $contentId, 1);
        }

        if ($contentId > 0 && !empty($network)) {
            $netIds = array_filter(explode(',', $network));
            foreach ($netIds as $nid) {
                try {
                    $pdo->prepare("INSERT INTO content_network_log (content_id, network_id, content_type) VALUES (?, ?, 1)")->execute([$contentId, intval($nid)]);
                } catch (Exception $ex) {}
            }
        }

        json_response(true, ["id" => $contentId], "Movie added successfully");

    } else if ($item_type === 'series') {
        $contentId = 0;
        try {
            $stmt = $pdo->prepare("INSERT INTO web_series (TMDB_ID, name, description, genres, release_date, poster, banner, youtube_trailer, downloadable, type, status, content_type, views, weekly_views) VALUES (0, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 2, 0, 0)");
            $stmt->execute([$name, $description, $genres, $release_date, $poster, $banner, $youtube_trailer, $downloadable, $type]);
            $contentId = $pdo->lastInsertId();
        } catch (Exception $e) {
            json_response(false, [], "Failed to save web series: " . $e->getMessage());
        }

        if ($contentId > 0 && !empty($custom_tag)) {
            save_custom_tag($pdo, $custom_tag, $contentId, 2);
        }

        if ($contentId > 0 && !empty($network)) {
            $netIds = array_filter(explode(',', $network));
            foreach ($netIds as $nid) {
                try {
                    $pdo->prepare("INSERT INTO content_network_log (content_id, network_id, content_type) VALUES (?, ?, 2)")->execute([$contentId, intval($nid)]);
                } catch (Exception $ex) {}
            }
        }

        json_response(true, ["id" => $contentId], "Web series added successfully");
    } else {
        json_response(false, [], "Invalid item type");
    }
}

//
// 7g2. LOG CONTENT VIEW (feeds trending)
//
if ($action === 'log_view') {
    $user_id = trim($input['user_id'] ?? '');
    $content_id = intval($input['content_id'] ?? 0);
    $content_type = intval($input['content_type'] ?? 0);
    if ($content_id <= 0) json_response(false, [], "Content ID required");
    $pdo->prepare("INSERT INTO view_log (user_id, content_id, content_type, date, time) VALUES (?, ?, ?, ?, ?)")
        ->execute([$user_id, $content_id, $content_type, date('m-d-Y'), date('h:i:s a')]);
    json_response(true, [], "View logged");
}

//
// 7g3. FAVORITES (user-wise)
//
$pdo->exec("CREATE TABLE IF NOT EXISTS favorites (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id TEXT NOT NULL,
    content_id INT NOT NULL,
    content_type INT NOT NULL DEFAULT 1,
    added_at TEXT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

if ($action === 'add_favorite') {
    $user_id = trim($input['user_id'] ?? '');
    $content_id = intval($input['content_id'] ?? 0);
    $content_type = intval($input['content_type'] ?? 1);
    if ($content_id <= 0) json_response(false, [], "Content ID required");
    $check = $pdo->prepare("SELECT id FROM favorites WHERE user_id = ? AND content_id = ? AND content_type = ?");
    $check->execute([$user_id, $content_id, $content_type]);
    if (!$check->fetch()) {
        $pdo->prepare("INSERT INTO favorites (user_id, content_id, content_type, added_at) VALUES (?, ?, ?, ?)")
            ->execute([$user_id, $content_id, $content_type, date('Y-m-d H:i:s')]);
    }
    json_response(true, [], "Added to favorites");
}

if ($action === 'remove_favorite') {
    $user_id = trim($input['user_id'] ?? '');
    $content_id = intval($input['content_id'] ?? 0);
    $content_type = intval($input['content_type'] ?? 1);
    if ($content_id <= 0) json_response(false, [], "Content ID required");
    $pdo->prepare("DELETE FROM favorites WHERE user_id = ? AND content_id = ? AND content_type = ?")
        ->execute([$user_id, $content_id, $content_type]);
    json_response(true, [], "Removed from favorites");
}

if ($action === 'get_favorites') {
    $user_id = trim($input['user_id'] ?? '');
    if (empty($user_id)) json_response(false, [], "User ID required");
    $stmt = $pdo->prepare("SELECT f.content_id, f.content_type,
        CASE WHEN f.content_type = 1 THEN m.name ELSE s.name END as name,
        CASE WHEN f.content_type = 1 THEN m.poster ELSE s.poster END as poster,
        CASE WHEN f.content_type = 1 THEN m.banner ELSE s.banner END as banner,
        CASE WHEN f.content_type = 1 THEN 'movie' ELSE 'series' END as item_type
        FROM favorites f
        LEFT JOIN movies m ON f.content_type = 1 AND f.content_id = m.id
        LEFT JOIN web_series s ON f.content_type = 2 AND f.content_id = s.id
        WHERE f.user_id = ?
        ORDER BY f.id DESC");
    $stmt->execute([$user_id]);
    json_response(true, ["favorites" => $stmt->fetchAll()], "Favorites fetched");
}

//
// 7g4. SUBSCRIPTION DETAILS & HISTORY
//
$pdo->exec("CREATE TABLE IF NOT EXISTS subscription_history (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id TEXT NOT NULL,
    plan_name TEXT NOT NULL,
    days INT NOT NULL DEFAULT 0,
    amount INT NOT NULL DEFAULT 0,
    started TEXT NOT NULL,
    expires TEXT NOT NULL,
    method TEXT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

function log_subscription_history($pdo, $user_id, $plan_name, $days, $amount, $start, $exp, $method) {
    $pdo->prepare("INSERT INTO subscription_history (user_id, plan_name, days, amount, started, expires, method) VALUES (?, ?, ?, ?, ?, ?, ?)")
        ->execute([$user_id, $plan_name, $days, $amount, $start, $exp, $method]);
}

if ($action === 'get_subscription_details') {
    $user_id = trim($input['user_id'] ?? '');
    if (empty($user_id)) json_response(false, [], "User ID required");
    $stmt = $pdo->prepare("SELECT id, name, email, active_subscription, subscription_type, time, amount, subscription_start, subscription_exp FROM user_db WHERE id = ?");
    $stmt->execute([$user_id]);
    $user = $stmt->fetch();
    $history = [];
    if ($user) {
        $h = $pdo->prepare("SELECT * FROM subscription_history WHERE user_id = ? ORDER BY id DESC LIMIT 20");
        $h->execute([$user_id]);
        $history = $h->fetchAll();
    }
    $plans = [];
    try {
        $p = $pdo->query("SELECT * FROM subscription WHERE status = 1 ORDER BY amount ASC");
        $plans = $p->fetchAll();
    } catch (Exception $e) {}
    json_response(true, ["user" => $user, "history" => $history, "plans" => $plans], "Subscription details fetched");
}

//
// 7h. REDEEM COUPON (app calls this to activate VIP)
//
if ($action === 'redeem_coupon') {
    $user_id = intval($input['user_id'] ?? 0);
    $code = strtoupper(trim($input['coupon_code'] ?? ''));
    if ($user_id <= 0 || empty($code)) json_response(false, [], "User and coupon code required");
    $stmt = $pdo->prepare("SELECT * FROM coupon WHERE coupon_code = ?");
    $stmt->execute([$code]);
    $coupon = $stmt->fetch();
    if (!$coupon) json_response(false, [], "Invalid coupon code");
    if ($coupon['status'] != 1) json_response(false, [], "Coupon is expired or inactive");
    if (intval($coupon['used']) >= intval($coupon['max_use'])) json_response(false, [], "Coupon usage limit reached");
    $exp = trim($coupon['expire_date']);
    if (!empty($exp) && $exp != '0000-00-00') {
        $expTs = strtotime($exp);
        if ($expTs !== false && $expTs < time()) json_response(false, [], "Coupon has expired");
    }
    $uStmt = $pdo->prepare("SELECT id, name FROM user_db WHERE id = ?");
    $uStmt->execute([$user_id]);
    $user = $uStmt->fetch();
    if (!$user) json_response(false, [], "User not found");
    $days = intval($coupon['time']);
    $start = date('Y-m-d H:i:s');
    $exp = date('Y-m-d H:i:s', strtotime("+$days days"));
    $pdo->prepare("UPDATE user_db SET active_subscription = ?, subscription_type = ?, time = ?, amount = ?, subscription_start = ?, subscription_exp = ? WHERE id = ?")
        ->execute([$coupon['name'], intval($coupon['subscription_type']), $days, intval($coupon['amount']), $start, $exp, $user_id]);
    $usedBy = trim($coupon['used_by']);
    $entry = $user_id . ':' . ($user['name'] ?? 'User');
    $usedBy = $usedBy === '' ? $entry : $usedBy . ',' . $entry;
    $pdo->prepare("UPDATE coupon SET used = used + 1, used_by = ? WHERE id = ?")->execute([$usedBy, $coupon['id']]);
    log_subscription_history($pdo, $user_id, $coupon['name'], $days, intval($coupon['amount']), $start, $exp, 'Coupon');
    json_response(true, [], "VIP Subscription Activated Successfully!");
}

//
// 8. ADD SEASON
//
if ($action === 'add_season') {
    $series_id = intval($input['series_id'] ?? 0);
    $name = trim($input['name'] ?? 'Season');
    $order = intval($input['order'] ?? 1);
    if ($series_id <= 0) {
        json_response(false, [], "Web series ID is required");
    }
    try {
        $pdo->prepare("INSERT INTO web_series_seasons (web_series_id, Session_Name, season_order, status) VALUES (?, ?, ?, 1)")->execute([$series_id, $name, $order]);
        json_response(true, ["season_id" => $pdo->lastInsertId()], "Season added successfully");
    } catch (Exception $e) {
        json_response(false, [], "Database error: " . $e->getMessage());
    }
}

if ($action === 'edit_season') {
    $id = intval($input['id'] ?? 0);
    $name = trim($input['name'] ?? '');
    $order = intval($input['season_order'] ?? $input['order'] ?? 1);
    if ($id <= 0 || empty($name)) {
        json_response(false, [], "Season ID and Name are required");
    }
    try {
        $pdo->prepare("UPDATE web_series_seasons SET Session_Name = ?, season_order = ? WHERE id = ?")->execute([$name, $order, $id]);
        json_response(true, [], "Season updated successfully");
    } catch (Exception $e) {
        json_response(false, [], "Database error: " . $e->getMessage());
    }
}

//
// 9a. SCAN MOVIE LINKS BATCH  parallel + stable totals + live dead list
//
$pdo->exec("CREATE TABLE IF NOT EXISTS link_scan_state (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    scan_type VARCHAR(20) NOT NULL UNIQUE,
    total INT NOT NULL DEFAULT 0,
    scanned INT NOT NULL DEFAULT 0,
    dead INT NOT NULL DEFAULT 0,
    last_id INT NOT NULL DEFAULT 0,
    done INT NOT NULL DEFAULT 0,
    started_at TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

// Reset scan progress (call when starting a fresh scan)
if ($action === 'reset_scan') {
    $ott = trim($input['ott'] ?? '');
    if (!empty($ott) && $ott !== 'All') {
        $stmtM = $pdo->prepare("SELECT COUNT(*) FROM movie_play_links mpl JOIN movies m ON mpl.movie_id = m.id WHERE mpl.status = 1 AND (FIND_IN_SET(?, m.genres) OR FIND_IN_SET(?, m.networks) OR m.ott_name = ?)");
        $stmtM->execute([$ott, $ott, $ott]);
        $totalM = intval($stmtM->fetchColumn());

        $stmtE = $pdo->prepare("SELECT COUNT(*) FROM episode_play_links epl JOIN web_series s ON epl.series_id = s.id WHERE epl.status = 1 AND (FIND_IN_SET(?, s.genres) OR FIND_IN_SET(?, s.networks) OR s.ott_name = ?)");
        $stmtE->execute([$ott, $ott, $ott]);
        $totalE = intval($stmtE->fetchColumn());
    } else {
        $totalM = intval($pdo->query("SELECT COUNT(*) FROM movie_play_links WHERE status = 1")->fetchColumn());
        $totalE = intval($pdo->query("SELECT COUNT(*) FROM episode_play_links WHERE status = 1")->fetchColumn());
    }
    $pdo->prepare("INSERT INTO link_scan_state (scan_type, total, scanned, dead, done, last_id, started_at) VALUES ('movie', ?, 0, 0, 0, 0, ?) ON DUPLICATE KEY UPDATE total = VALUES(total), scanned = 0, dead = 0, done = 0, last_id = 0, started_at = VALUES(started_at)")
        ->execute([$totalM, date('Y-m-d H:i:s')]);
    $pdo->prepare("INSERT INTO link_scan_state (scan_type, total, scanned, dead, done, last_id, started_at) VALUES ('episode', ?, 0, 0, 0, 0, ?) ON DUPLICATE KEY UPDATE total = VALUES(total), scanned = 0, dead = 0, done = 0, last_id = 0, started_at = VALUES(started_at)")
        ->execute([$totalE, date('Y-m-d H:i:s')]);
    json_response(true, ["movie_total" => $totalM, "episode_total" => $totalE], "Scan reset");
}

if ($action === 'scan_movie_links') {
    $offset = intval($input['offset'] ?? 0);
    $limit = intval($input['limit'] ?? 20);
    if ($limit < 1 || $limit > 100) $limit = 20;
    $ott = trim($input['ott'] ?? '');

    // Stable total from scan state (does not shrink as links get parked)
    $state = $pdo->query("SELECT * FROM link_scan_state WHERE scan_type = 'movie'")->fetch();
    if (!$state) {
        $total = intval($pdo->query("SELECT COUNT(*) FROM movie_play_links WHERE status = 1")->fetchColumn());
        $pdo->prepare("INSERT INTO link_scan_state (scan_type, total, scanned, dead, done, last_id, started_at) VALUES ('movie', ?, 0, 0, 0, 0, ?)")
            ->execute([$total, date('Y-m-d H:i:s')]);
        $state = $pdo->query("SELECT * FROM link_scan_state WHERE scan_type = 'movie'")->fetch();
    }
    $total = intval($state['total']);
    $alreadyScanned = intval($state['scanned']);
    $lastId = intval($state['last_id']);

    // Keyset pagination (resume from last id)
    if (!empty($ott) && $ott !== 'All') {
        $stmt = $pdo->prepare("SELECT mpl.id, mpl.movie_id, mpl.url, mpl.name FROM movie_play_links mpl JOIN movies m ON mpl.movie_id = m.id WHERE mpl.status = 1 AND (FIND_IN_SET(?, m.genres) OR FIND_IN_SET(?, m.networks) OR m.ott_name = ?) AND mpl.id > ? ORDER BY mpl.id ASC LIMIT ?");
        $stmt->execute([$ott, $ott, $ott, $lastId, $limit]);
    } else {
        $stmt = $pdo->prepare("SELECT id, movie_id, url, name FROM movie_play_links WHERE status = 1 AND id > $lastId ORDER BY id ASC LIMIT $limit");
        $stmt->execute();
    }
    $links = $stmt->fetchAll();

    $results = batch_health_check($links, 6);
    $found_dead = 0;
    $dead_links = [];
    $parked_movies = [];
    $affectedMovies = [];
    $maxId = $lastId;
    foreach ($links as $l) {
        $lid = intval($l['id']);
        if ($lid > $maxId) $maxId = $lid;
        $ok = $results[$lid]['ok'] ?? true;
        if (!$ok) {
            $pdo->prepare("UPDATE movie_play_links SET status = 0 WHERE id = ?")->execute([$lid]);
            $found_dead++;
            $affectedMovies[$l['movie_id']] = true;
            $mname = $l['name'] ?? '';
            if (empty($mname)) {
                $mn = $pdo->prepare("SELECT name FROM movies WHERE id = ?");
                $mn->execute([$l['movie_id']]);
                $mname = $mn->fetchColumn() ?: ('Movie #' . $l['movie_id']);
            }
            $dead_links[] = [
                'link_id' => $lid,
                'content_id' => $l['movie_id'],
                'content_type' => 'movie',
                'name' => $mname,
                'url' => $l['url'],
                'code' => $results[$lid]['code'] ?? 0,
            ];
            // Park the movie in the DB immediately if it now has no active links
            $chk = $pdo->prepare("SELECT COUNT(*) FROM movie_play_links WHERE movie_id = ? AND status = 1");
            $chk->execute([$l['movie_id']]);
            if (intval($chk->fetchColumn()) == 0) {
                $pdo->prepare("UPDATE movies SET status = 0 WHERE id = ? AND status = 1")->execute([$l['movie_id']]);
            }
        }
    }

    // Build parked entries for EVERY movie with a dead link this batch (live list)
    foreach (array_keys($affectedMovies) as $mid) {
        $m = $pdo->prepare("SELECT id, name, poster, genres FROM movies WHERE id = ?");
        $m->execute([$mid]);
        $mrow = $m->fetch();
        if ($mrow) {
            $dls = $pdo->prepare("SELECT id as link_id, url, name as link_name, quality FROM movie_play_links WHERE movie_id = ? AND status = 0 ORDER BY id DESC LIMIT 10");
            $dls->execute([$mid]);
            $act = $pdo->prepare("SELECT COUNT(*) FROM movie_play_links WHERE movie_id = ? AND status = 1");
            $act->execute([$mid]);
            $mrow['type'] = 'movie';
            $mrow['has_active'] = strval(intval($act->fetchColumn()));
            $mrow['dead_links'] = $dls->fetchAll();
            $parked_movies[] = $mrow;
        }
    }

    $newScanned = $alreadyScanned + count($links);
    $done = count($links) == 0 || $newScanned >= $total;
    $pdo->prepare("UPDATE link_scan_state SET scanned = ?, dead = dead + ?, done = ?, last_id = ? WHERE scan_type = 'movie'")
        ->execute([$newScanned, $found_dead, $done ? 1 : 0, $maxId]);

    json_response(true, [
        "checked" => $newScanned,
        "total" => $total,
        "found_dead" => $found_dead,
        "done" => $done,
        "dead_links" => $dead_links,
        "parked_movies" => $parked_movies,
    ], "Movie links scanned");
}

if ($action === 'scan_episode_links') {
    $offset = intval($input['offset'] ?? 0);
    $limit = intval($input['limit'] ?? 20);
    if ($limit < 1 || $limit > 100) $limit = 20;
    $ott = trim($input['ott'] ?? '');

    $state = $pdo->query("SELECT * FROM link_scan_state WHERE scan_type = 'episode'")->fetch();
    if (!$state) {
        $total = intval($pdo->query("SELECT COUNT(*) FROM episode_play_links WHERE status = 1")->fetchColumn());
        $pdo->prepare("INSERT INTO link_scan_state (scan_type, total, scanned, dead, done, last_id, started_at) VALUES ('episode', ?, 0, 0, 0, 0, ?) ON DUPLICATE KEY UPDATE total = VALUES(total), scanned = 0, dead = 0, done = 0, last_id = 0, started_at = VALUES(started_at)")
            ->execute([$total, date('Y-m-d H:i:s')]);
        $state = $pdo->query("SELECT * FROM link_scan_state WHERE scan_type = 'episode'")->fetch();
    }
    $total = intval($state['total']);
    $alreadyScanned = intval($state['scanned']);
    $lastId = intval($state['last_id']);

    // Keyset pagination (resume from last id)
    if (!empty($ott) && $ott !== 'All') {
        $stmt = $pdo->prepare("SELECT epl.id, epl.episode_id, epl.url, epl.name FROM episode_play_links epl JOIN web_series s ON epl.series_id = s.id WHERE epl.status = 1 AND (FIND_IN_SET(?, s.genres) OR FIND_IN_SET(?, s.networks) OR s.ott_name = ?) AND epl.id > ? ORDER BY epl.id ASC LIMIT ?");
        $stmt->execute([$ott, $ott, $ott, $lastId, $limit]);
    } else {
        $stmt = $pdo->prepare("SELECT id, episode_id, url, name FROM episode_play_links WHERE status = 1 AND id > $lastId ORDER BY id ASC LIMIT $limit");
        $stmt->execute();
    }
    $links = $stmt->fetchAll();

    $results = batch_health_check($links, 6);
    $found_dead = 0;
    $dead_links = [];
    $maxId = $lastId;
    foreach ($links as $l) {
        $lid = intval($l['id']);
        if ($lid > $maxId) $maxId = $lid;
        $ok = $results[$lid]['ok'] ?? true;
        if (!$ok) {
            $pdo->prepare("UPDATE episode_play_links SET status = 0 WHERE id = ?")->execute([$lid]);
            $found_dead++;
            $epName = $l['name'] ?? '';
            if (empty($epName)) {
                $en = $pdo->prepare("SELECT Episoade_Name FROM web_series_episoade WHERE id = ?");
                $en->execute([$l['episode_id']]);
                $epName = $en->fetchColumn() ?: ('Episode #' . $l['episode_id']);
            }
            $dead_links[] = [
                'link_id' => $lid,
                'content_id' => $l['episode_id'],
                'content_type' => 'episode',
                'name' => $epName,
                'url' => $l['url'],
                'code' => $results[$lid]['code'] ?? 0,
            ];
            $chk = $pdo->prepare("SELECT COUNT(*) FROM episode_play_links WHERE episode_id = ? AND status = 1");
            $chk->execute([$l['episode_id']]);
            if (intval($chk->fetchColumn()) == 0) {
                $pdo->prepare("UPDATE web_series_episoade SET status = 0 WHERE id = ? AND status = 1")->execute([$l['episode_id']]);
            }
        }
    }

    $newScanned = $alreadyScanned + count($links);
    $done = count($links) == 0 || $newScanned >= $total;
    $pdo->prepare("UPDATE link_scan_state SET scanned = ?, dead = dead + ?, done = ?, last_id = ? WHERE scan_type = 'episode'")
        ->execute([$newScanned, $found_dead, $done ? 1 : 0, $maxId]);

    $parked_series = [];
    $affectedSeries = [];
    foreach ($dead_links as $dl) {
        if ($dl['content_type'] !== 'episode') continue;
        $epId = intval($dl['content_id']);
        $sid = $pdo->prepare("SELECT season_id FROM web_series_episoade WHERE id = ?");
        $sid->execute([$epId]);
        $seasonId = $sid->fetchColumn();
        if (!$seasonId) continue;
        $wsid = $pdo->prepare("SELECT web_series_id FROM web_series_seasons WHERE id = ?");
        $wsid->execute([$seasonId]);
        $seriesId = intval($wsid->fetchColumn());
        if ($seriesId <= 0) continue;
        $affectedSeries[$seriesId] = true;
        $chk = $pdo->prepare("SELECT COUNT(*) FROM web_series_episoade WHERE season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?) AND status = 1");
        $chk->execute([$seriesId]);
        if (intval($chk->fetchColumn()) == 0) {
            $pdo->prepare("UPDATE web_series SET status = 0 WHERE id = ? AND status = 1")->execute([$seriesId]);
        }
    }
    foreach (array_keys($affectedSeries) as $seriesId) {
        $s = $pdo->prepare("SELECT id, name, poster, genres FROM web_series WHERE id = ?");
        $s->execute([$seriesId]);
        $srow = $s->fetch();
        if ($srow) {
            $eps = $pdo->prepare("SELECT ep.id as episode_id, ep.Episoade_Name as episode_name, ep.episoade_image, ss.Session_Name as season_name, epl.id as link_id, epl.url as old_url, epl.name as link_name, epl.quality FROM web_series_episoade ep LEFT JOIN web_series_seasons ss ON ss.id = ep.season_id LEFT JOIN episode_play_links epl ON epl.episode_id = ep.id WHERE ep.season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?) AND (ep.status = 0 OR epl.status = 0) ORDER BY ep.id DESC LIMIT 100");
            $eps->execute([$seriesId]);
            $act = $pdo->prepare("SELECT COUNT(*) FROM web_series_episoade WHERE season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?) AND status = 1");
            $act->execute([$seriesId]);
            $srow['type'] = 'series';
            $srow['has_active'] = strval(intval($act->fetchColumn()));
            $srow['dead_episodes'] = $eps->fetchAll();
            $parked_series[] = $srow;
        }
    }

    json_response(true, [
        "checked" => $newScanned,
        "total" => $total,
        "found_dead" => $found_dead,
        "done" => $done,
        "dead_links" => $dead_links,
        "parked_series" => $parked_series,
    ], "Episode links scanned");
}

//
// Scan progress (live totals for the UI while scanning)
//
if ($action === 'get_scan_progress') {
    $m = $pdo->query("SELECT * FROM link_scan_state WHERE scan_type = 'movie'")->fetch();
    $e = $pdo->query("SELECT * FROM link_scan_state WHERE scan_type = 'episode'")->fetch();
    json_response(true, [
        "movie" => $m,
        "episode" => $e,
    ], "Scan progress fetched");
}

//
// 9c. PARK DEAD CONTENT
//
if ($action === 'park_dead_content') {
    $parked_movies = 0; $parked_series = 0;
    $stmt = $pdo->query("SELECT id FROM movies WHERE status = 1");
    while ($m = $stmt->fetch()) {
        $chk = $pdo->prepare("SELECT COUNT(*) FROM movie_play_links WHERE movie_id = ? AND status = 1");
        $chk->execute([$m['id']]);
        if ($chk->fetchColumn() == 0) {
            $pdo->prepare("UPDATE movies SET status = 0 WHERE id = ?")->execute([$m['id']]);
            $parked_movies++;
        }
    }
    $stmt = $pdo->query("SELECT id FROM web_series_episoade WHERE status = 1");
    while ($ep = $stmt->fetch()) {
        $chk = $pdo->prepare("SELECT COUNT(*) FROM episode_play_links WHERE episode_id = ? AND status = 1");
        $chk->execute([$ep['id']]);
        if ($chk->fetchColumn() == 0) {
            $pdo->prepare("UPDATE web_series_episoade SET status = 0 WHERE id = ?")->execute([$ep['id']]);
        }
    }
    $stmt = $pdo->query("SELECT id FROM web_series WHERE status = 1");
    while ($s = $stmt->fetch()) {
        $chk = $pdo->prepare("SELECT COUNT(*) FROM web_series_episoade WHERE season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?) AND status = 1");
        $chk->execute([$s['id']]);
        if ($chk->fetchColumn() == 0) {
            $pdo->prepare("UPDATE web_series SET status = 0 WHERE id = ?")->execute([$s['id']]);
            $parked_series++;
        }
    }
    json_response(true, ["parked_movies" => $parked_movies, "parked_series" => $parked_series], "Parking completed");
}

//
// 9d. REACTIVATE CONTENT (manual  just set status=1, no new link required)
//
if ($action === 'reactivate_content') {
    $type = $input['type'] ?? 'movie';
    $id = intval($input['id'] ?? 0);
    if ($type === 'movie') {
        $pdo->prepare("UPDATE movies SET status = 1 WHERE id = ?")->execute([$id]);
        $pdo->prepare("UPDATE movie_play_links SET status = 1 WHERE movie_id = ?")->execute([$id]);
    } else {
        $pdo->prepare("UPDATE web_series SET status = 1 WHERE id = ?")->execute([$id]);
        $pdo->prepare("UPDATE web_series_seasons SET status = 1 WHERE web_series_id = ?")->execute([$id]);
        $pdo->prepare("UPDATE web_series_episoade SET status = 1 WHERE season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?)")->execute([$id]);
        $pdo->prepare("UPDATE episode_play_links SET status = 1 WHERE episode_id IN (SELECT id FROM web_series_episoade WHERE season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?))")->execute([$id]);
    }
    json_response(true, [], "Content reactivated");
}

//
// 10. GET PARKED CONTENT (enhanced: full old link details)
//
if ($action === 'get_parked') {
    $mstmt = $pdo->query("SELECT DISTINCT m.id, m.name, m.poster, m.genres FROM movies m LEFT JOIN movie_play_links pl ON pl.movie_id = m.id WHERE m.status = 0 OR pl.status = 0 OR pl.id IS NULL ORDER BY m.id DESC LIMIT 1000");
    $movies = $mstmt->fetchAll();
    foreach ($movies as &$m) {
        $dls = $pdo->prepare("SELECT id as link_id, url, name as link_name, quality FROM movie_play_links WHERE movie_id = ? AND status = 0 ORDER BY id DESC LIMIT 50");
        $dls->execute([$m['id']]);
        $act = $pdo->prepare("SELECT COUNT(*) FROM movie_play_links WHERE movie_id = ? AND status = 1");
        $act->execute([$m['id']]);
        $m['type'] = 'movie';
        $m['has_active'] = strval(intval($act->fetchColumn()));
        $m['dead_links'] = $dls->fetchAll();
    }
    unset($m);

    $sstmt = $pdo->query("SELECT DISTINCT ws.id, ws.name, ws.poster, ws.genres FROM web_series ws LEFT JOIN web_series_seasons ss ON ss.web_series_id = ws.id LEFT JOIN web_series_episoade ep ON ep.season_id = ss.id LEFT JOIN episode_play_links epl ON epl.episode_id = ep.id WHERE ws.status = 0 OR ep.status = 0 OR epl.status = 0 OR ep.id IS NULL ORDER BY ws.id DESC LIMIT 1000");
    $series = $sstmt->fetchAll();
    foreach ($series as &$s) {
        $eps = $pdo->prepare("SELECT ep.id as episode_id, ep.Episoade_Name as episode_name, ep.episoade_image, ss.Session_Name as season_name, epl.id as link_id, epl.url as old_url, epl.name as link_name, epl.quality FROM web_series_episoade ep LEFT JOIN web_series_seasons ss ON ss.id = ep.season_id LEFT JOIN episode_play_links epl ON epl.episode_id = ep.id WHERE ep.season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?) AND (ep.status = 0 OR epl.status = 0) ORDER BY ep.id DESC LIMIT 100");
        $eps->execute([$s['id']]);
        $act = $pdo->prepare("SELECT COUNT(*) FROM web_series_episoade WHERE season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?) AND status = 1");
        $act->execute([$s['id']]);
        $s['type'] = 'series';
        $s['has_active'] = strval(intval($act->fetchColumn()));
        $s['dead_episodes'] = $eps->fetchAll();
    }
    unset($s);

    json_response(true, ["movies" => $movies, "series" => $series], "Parked content fetched");
}

//
// 11. RESTORE PARKED CONTENT (Save new link & set status=1)
//
if ($action === 'restore_content') {
    $type = $input['type'] ?? 'movie';
    $id = intval($input['id'] ?? 0);
    $new_url = trim($input['new_url'] ?? '');
    if (strpos($new_url, ' ') !== false) {
        $new_url = str_replace(' ', '%20', $new_url);
    }
    $link_verified = false;
    $check_code = 0;

    if (!empty($new_url)) {
        $r = http_health_check($new_url);
        $link_verified = $r['ok'];
        $check_code = $r['code'];
    }

    if ($type === 'movie') {
        if (!empty($new_url)) {
            $stmt = $pdo->prepare("SELECT id FROM movie_play_links WHERE movie_id = ? AND status = 0 LIMIT 1");
            $stmt->execute([$id]);
            $link = $stmt->fetch();
            if ($link) {
                $pdo->prepare("UPDATE movie_play_links SET url = ?, status = 1 WHERE id = ?")->execute([$new_url, $link['id']]);
            } else {
                $pdo->prepare("INSERT INTO movie_play_links (movie_id, name, quality, url, type, status, link_order, size, skip_available, intro_start, intro_end, end_credits_marker, link_type, drm_uuid, drm_license_uri) VALUES (?, 'Server 1', '720p', ?, 'Streamtape', 1, 1, ' ', 0, ' ', ' ', ' ', 0, ' ', ' ')")->execute([$id, $new_url]);
            }
        }
        $pdo->prepare("UPDATE movie_play_links SET status = 1 WHERE movie_id = ?")->execute([$id]);
        $pdo->prepare("UPDATE movies SET status = 1 WHERE id = ?")->execute([$id]);

        if (!empty($new_url)) {
            json_response(true, ["verified" => $link_verified, "code" => $check_code], $link_verified ? "Link verified & restored" : "Link check failed (HTTP $check_code), but new link saved.");
        } else {
            json_response(true, [], "Visibility restored");
        }
    } else {
        $episode_id = intval($input['episode_id'] ?? $input['id'] ?? 0);
        $episoade_image = trim($input['episoade_image'] ?? '');
        
        if ($episode_id > 0 && !empty($episoade_image)) {
            $pdo->prepare("UPDATE web_series_episoade SET episoade_image = ? WHERE id = ?")->execute([$episoade_image, $episode_id]);
        }

        if (!empty($new_url) && $episode_id > 0) {
            $stmt = $pdo->prepare("SELECT id FROM episode_play_links WHERE episode_id = ? AND status = 0 LIMIT 1");
            $stmt->execute([$episode_id]);
            $link = $stmt->fetch();
            if ($link) {
                $pdo->prepare("UPDATE episode_play_links SET url = ?, status = 1 WHERE id = ?")->execute([$new_url, $link['id']]);
            } else {
                $pdo->prepare("INSERT INTO episode_play_links (episode_id, name, quality, url, type, status, link_order, size, skip_available, intro_start, intro_end, end_credits_marker, link_type, drm_uuid, drm_license_uri) VALUES (?, 'Server 1', '720p', ?, 'Streamtape', 1, 1, ' ', 0, ' ', ' ', ' ', 0, ' ', ' ')")->execute([$episode_id, $new_url]);
            }
            $pdo->prepare("UPDATE web_series_episoade SET status = 1 WHERE id = ?")->execute([$episode_id]);
        } else if ($episode_id > 0) {
            $pdo->prepare("UPDATE episode_play_links SET status = 1 WHERE episode_id = ?")->execute([$episode_id]);
            $pdo->prepare("UPDATE web_series_episoade SET status = 1 WHERE id = ?")->execute([$episode_id]);
        } else {
            $pdo->prepare("UPDATE web_series_episoade SET status = 1 WHERE season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?)")->execute([$id]);
            $pdo->prepare("UPDATE episode_play_links SET status = 1 WHERE episode_id IN (SELECT id FROM web_series_episoade WHERE season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?))")->execute([$id]);
        }
        $pdo->prepare("UPDATE web_series_seasons SET status = 1 WHERE web_series_id = ?")->execute([$id]);
        $pdo->prepare("UPDATE web_series SET status = 1 WHERE id = ?")->execute([$id]);

        json_response(true, ["verified" => $link_verified, "code" => $check_code], "Episode updated & series restored");
    }
}

//
// 11b. CHECK SINGLE LINK
//
if ($action === 'check_link') {
    $url = trim($input['url'] ?? '');
    if (empty($url)) json_response(false, [], "URL required");
    $r = http_health_check($url);
    json_response(true, ["ok" => $r['ok'], "code" => $r['code'], "direct" => $r['direct'] ?? ''], $r['ok'] ? "Link is LIVE" : "Link is DEAD (HTTP {$r['code']})");
}

//
// 11c. REPLACE DOMAIN BULK
//
if ($action === 'replace_domain') {
    $old_domain = trim($input['old_domain'] ?? '');
    $new_domain = trim($input['new_domain'] ?? '');
    if (empty($old_domain) || empty($new_domain)) json_response(false, [], "Both old and new domain required");

    $old_clean = preg_replace('~^https?://~', '', rtrim($old_domain, '/'));
    $new_clean = preg_replace('~^https?://~', '', rtrim($new_domain, '/'));

    $m_stmt = $pdo->prepare("UPDATE movie_play_links SET url = REPLACE(url, ?, ?) WHERE url LIKE ?");
    $m_stmt->execute([$old_clean, $new_clean, "%" . $old_clean . "%"]);
    $m_count = $m_stmt->rowCount();

    $e_stmt = $pdo->prepare("UPDATE episode_play_links SET url = REPLACE(url, ?, ?) WHERE url LIKE ?");
    $e_stmt->execute([$old_clean, $new_clean, "%" . $old_clean . "%"]);
    $e_count = $e_stmt->rowCount();

    json_response(true, ["movie_links_updated" => $m_count, "episode_links_updated" => $e_count], "Replaced {$old_clean} with {$new_clean} across {$m_count} movie links & {$e_count} episode links.");
}

//
// 11d. RESTORE ALL PARKED CONTENT
//
if ($action === 'restore_all') {
    $pdo->exec("UPDATE movies SET status = 1 WHERE status = 0");
    $pdo->exec("UPDATE movie_play_links SET status = 1 WHERE status = 0");
    $pdo->exec("UPDATE web_series SET status = 1 WHERE status = 0");
    $pdo->exec("UPDATE web_series_seasons SET status = 1 WHERE status = 0");
    $pdo->exec("UPDATE web_series_episoade SET status = 1 WHERE status = 0");
    $pdo->exec("UPDATE episode_play_links SET status = 1 WHERE status = 0");
    json_response(true, [], "All parked content & play links restored to live status!");
}

//
// 11e. REMOVE FROM DEAD AREA (force restore one item to the app)
//
if ($action === 'remove_from_dead') {
    $type = $input['type'] ?? 'movie';
    $id = intval($input['id'] ?? 0);
    if ($id <= 0) json_response(false, [], "ID required");
    if ($type === 'movie') {
        $pdo->prepare("UPDATE movies SET status = 1 WHERE id = ?")->execute([$id]);
        $pdo->prepare("UPDATE movie_play_links SET status = 1 WHERE movie_id = ?")->execute([$id]);
    } else if ($type === 'episode') {
        $pdo->prepare("UPDATE episode_play_links SET status = 1 WHERE episode_id = ?")->execute([$id]);
        $pdo->prepare("UPDATE web_series_episoade SET status = 1 WHERE id = ?")->execute([$id]);
        $ep = $pdo->prepare("SELECT season_id FROM web_series_episoade WHERE id = ?");
        $ep->execute([$id]);
        $seasonId = $ep->fetchColumn();
        if ($seasonId) {
            $pdo->prepare("UPDATE web_series_seasons SET status = 1 WHERE id = ?")->execute([$seasonId]);
            $ws = $pdo->prepare("SELECT web_series_id FROM web_series_seasons WHERE id = ?");
            $ws->execute([$seasonId]);
            $wsId = $ws->fetchColumn();
            if ($wsId) {
                $pdo->prepare("UPDATE web_series SET status = 1 WHERE id = ?")->execute([$wsId]);
            }
        }
    } else { // series (force whole series back)
        $pdo->prepare("UPDATE web_series SET status = 1 WHERE id = ?")->execute([$id]);
        $pdo->prepare("UPDATE web_series_seasons SET status = 1 WHERE web_series_id = ?")->execute([$id]);
        $pdo->prepare("UPDATE web_series_episoade SET status = 1 WHERE season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?)")->execute([$id]);
        $pdo->prepare("UPDATE episode_play_links SET status = 1 WHERE episode_id IN (SELECT id FROM web_series_episoade WHERE season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?))")->execute([$id]);
    }
    json_response(true, [], "Restored to the app");
}

//
//
// 11f. DELETE CONTENT (dynamic dispatcher for parked content)
//
if ($action === 'delete_content') {
    $type = $input['type'] ?? 'movie';
    $id = intval($input['id'] ?? 0);
    if ($id <= 0) json_response(false, [], "ID required");
    
    if ($type === 'movie') {
        $pdo->prepare("DELETE FROM movie_play_links WHERE movie_id = ?")->execute([$id]);
        $pdo->prepare("DELETE FROM custom_tag_log WHERE content_id = ? AND content_type = 1")->execute([$id]);
        $pdo->prepare("DELETE FROM content_network_log WHERE content_id = ? AND content_type = 1")->execute([$id]);
        $pdo->prepare("DELETE FROM movies WHERE id = ?")->execute([$id]);
        json_response(true, [], "Movie deleted successfully");
    } else if ($type === 'series') {
        $pdo->prepare("DELETE FROM episode_play_links WHERE episode_id IN (SELECT id FROM web_series_episoade WHERE season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?))")->execute([$id]);
        $pdo->prepare("DELETE FROM episode_download_links WHERE episode_id IN (SELECT id FROM web_series_episoade WHERE season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?))")->execute([$id]);
        $pdo->prepare("DELETE FROM web_series_episoade WHERE season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?)")->execute([$id]);
        $pdo->prepare("DELETE FROM web_series_seasons WHERE web_series_id = ?")->execute([$id]);
        $pdo->prepare("DELETE FROM custom_tag_log WHERE content_id = ? AND content_type = 2")->execute([$id]);
        $pdo->prepare("DELETE FROM content_network_log WHERE content_id = ? AND content_type = 2")->execute([$id]);
        $pdo->prepare("DELETE FROM web_series WHERE id = ?")->execute([$id]);
        json_response(true, [], "Series deleted successfully");
    } else if ($type === 'season') {
        $pdo->prepare("DELETE FROM episode_play_links WHERE episode_id IN (SELECT id FROM web_series_episoade WHERE season_id = ?)")->execute([$id]);
        $pdo->prepare("DELETE FROM episode_download_links WHERE episode_id IN (SELECT id FROM web_series_episoade WHERE season_id = ?)")->execute([$id]);
        $pdo->prepare("DELETE FROM web_series_episoade WHERE season_id = ?")->execute([$id]);
        $pdo->prepare("DELETE FROM web_series_seasons WHERE id = ?")->execute([$id]);
        json_response(true, [], "Season deleted successfully");
    } else if ($type === 'episode') {
        $pdo->prepare("DELETE FROM episode_play_links WHERE episode_id = ?")->execute([$id]);
        $pdo->prepare("DELETE FROM episode_download_links WHERE episode_id = ?")->execute([$id]);
        $pdo->prepare("DELETE FROM web_series_episoade WHERE id = ?")->execute([$id]);
        json_response(true, [], "Episode deleted successfully");
    } else {
        json_response(false, [], "Invalid delete type");
    }
}

//
// 12. DELETE ACTIONS (MOVIE, SERIES, SEASON, EPISODE)
//
if ($action === 'delete_movie') {
    $id = intval($input['id'] ?? 0);
    if ($id <= 0) json_response(false, [], "Movie ID required");
    $pdo->prepare("DELETE FROM movie_play_links WHERE movie_id = ?")->execute([$id]);
    $pdo->prepare("DELETE FROM custom_tag_log WHERE content_id = ? AND content_type = 1")->execute([$id]);
    $pdo->prepare("DELETE FROM content_network_log WHERE content_id = ? AND content_type = 1")->execute([$id]);
    $pdo->prepare("DELETE FROM movies WHERE id = ?")->execute([$id]);
    json_response(true, [], "Movie deleted successfully");
}

if ($action === 'delete_series') {
    $id = intval($input['id'] ?? 0);
    if ($id <= 0) json_response(false, [], "Series ID required");
    $pdo->prepare("DELETE FROM episode_play_links WHERE episode_id IN (SELECT id FROM web_series_episoade WHERE season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?))")->execute([$id]);
    $pdo->prepare("DELETE FROM episode_download_links WHERE episode_id IN (SELECT id FROM web_series_episoade WHERE season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?))")->execute([$id]);
    $pdo->prepare("DELETE FROM web_series_episoade WHERE season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?)")->execute([$id]);
    $pdo->prepare("DELETE FROM web_series_seasons WHERE web_series_id = ?")->execute([$id]);
    $pdo->prepare("DELETE FROM custom_tag_log WHERE content_id = ? AND content_type = 2")->execute([$id]);
    $pdo->prepare("DELETE FROM content_network_log WHERE content_id = ? AND content_type = 2")->execute([$id]);
    $pdo->prepare("DELETE FROM web_series WHERE id = ?")->execute([$id]);
    json_response(true, [], "Series deleted successfully");
}

if ($action === 'delete_season') {
    $id = intval($input['id'] ?? 0);
    if ($id <= 0) json_response(false, [], "Season ID required");
    $pdo->prepare("DELETE FROM episode_play_links WHERE episode_id IN (SELECT id FROM web_series_episoade WHERE season_id = ?)")->execute([$id]);
    $pdo->prepare("DELETE FROM episode_download_links WHERE episode_id IN (SELECT id FROM web_series_episoade WHERE season_id = ?)")->execute([$id]);
    $pdo->prepare("DELETE FROM web_series_episoade WHERE season_id = ?")->execute([$id]);
    $pdo->prepare("DELETE FROM web_series_seasons WHERE id = ?")->execute([$id]);
    json_response(true, [], "Season deleted successfully");
}

if ($action === 'delete_episode') {
    $id = intval($input['id'] ?? 0);
    if ($id <= 0) json_response(false, [], "Episode ID required");
    $pdo->prepare("DELETE FROM episode_play_links WHERE episode_id = ?")->execute([$id]);
    $pdo->prepare("DELETE FROM episode_download_links WHERE episode_id = ?")->execute([$id]);
    $pdo->prepare("DELETE FROM web_series_episoade WHERE id = ?")->execute([$id]);
    json_response(true, [], "Episode deleted successfully");
}

//
// 12f. LIVE STATISTICS & TELEMETRY API
//
if ($action === 'heartbeat') {
    $user_id = intval($input['user_id'] ?? 0);
    if ($user_id > 0) {
        $current_view = trim($input['current_view'] ?? '');
        $content_id = isset($input['content_id']) && $input['content_id'] !== '' ? intval($input['content_id']) : null;
        $content_type = isset($input['content_type']) && $input['content_type'] !== '' ? intval($input['content_type']) : null;
        $app_version = trim($input['app_version'] ?? '');
        
        $stmt = $pdo->prepare("INSERT INTO active_sessions (user_id, last_ping, current_view, content_id, content_type) 
            VALUES (?, NOW(), ?, ?, ?) 
            ON DUPLICATE KEY UPDATE last_ping = NOW(), current_view = VALUES(current_view), content_id = VALUES(content_id), content_type = VALUES(content_type)");
        $stmt->execute([$user_id, $current_view, $content_id, $content_type]);
        
        if (!empty($app_version)) {
            $stmt_u = $pdo->prepare("UPDATE user_db SET app_version = ? WHERE id = ?");
            $stmt_u->execute([$app_version, $user_id]);
        }
    }
    json_response(true, [], "Heartbeat registered");
}

if ($action === 'log_play_event') {
    $user_id = intval($input['user_id'] ?? 0);
    $content_id = intval($input['content_id'] ?? 0);
    $content_type = intval($input['content_type'] ?? 1);
    $duration = intval($input['duration_seconds'] ?? 0);
    $completed = intval($input['completed'] ?? 0);
    
    if ($user_id > 0 && $content_id > 0) {
        $stmt = $pdo->prepare("INSERT INTO watch_history_analytics (user_id, content_id, content_type, duration_seconds, completed) VALUES (?, ?, ?, ?, ?)");
        $stmt->execute([$user_id, $content_id, $content_type, $duration, $completed]);
    }
    json_response(true, [], "Play event logged");
}

if ($action === 'log_download_event') {
    $user_id = intval($input['user_id'] ?? 0);
    $content_id = intval($input['content_id'] ?? 0);
    $content_type = intval($input['content_type'] ?? 1);
    $status = trim($input['status'] ?? 'started');
    
    if ($user_id > 0 && $content_id > 0) {
        $stmt = $pdo->prepare("INSERT INTO download_statistics (user_id, content_id, content_type, status) VALUES (?, ?, ?, ?)");
        $stmt->execute([$user_id, $content_id, $content_type, $status]);
    }
    json_response(true, [], "Download event logged");
}

//
// 13. DASHBOARD ANALYTICS & TOP 15 RANKINGS
//
if ($action === 'get_analytics') {
    check_and_do_weekly_reset($pdo);

    $m_active = safe_count($pdo, "SELECT COUNT(*) FROM movies WHERE status = 1");
    $m_parked = safe_count($pdo, "SELECT COUNT(*) FROM movies WHERE status = 0");
    $m_total  = safe_count($pdo, "SELECT COUNT(*) FROM movies");
    if ($m_total < ($m_active + $m_parked)) $m_total = $m_active + $m_parked;

    $s_active = safe_count($pdo, "SELECT COUNT(*) FROM web_series WHERE status = 1");
    $s_parked = safe_count($pdo, "SELECT COUNT(*) FROM web_series WHERE status = 0");
    $s_total  = safe_count($pdo, "SELECT COUNT(*) FROM web_series");
    if ($s_total < ($s_active + $s_parked)) $s_total = $s_active + $s_parked;

    $ep_active  = safe_count($pdo, "SELECT COUNT(*) FROM web_series_episoade WHERE status = 1");
    $ep_total   = safe_count($pdo, "SELECT COUNT(*) FROM web_series_episoade");
    $mpl_active = safe_count($pdo, "SELECT COUNT(*) FROM movie_play_links WHERE status = 1");
    $mpl_dead   = safe_count($pdo, "SELECT COUNT(*) FROM movie_play_links WHERE status = 0");
    $epl_active = safe_count($pdo, "SELECT COUNT(*) FROM episode_play_links WHERE status = 1");
    $epl_dead   = safe_count($pdo, "SELECT COUNT(*) FROM episode_play_links WHERE status = 0");

    // User stats - try multiple possible table/column names
    $u_total = 0; $u_vip = 0;
    try {
        $u_total = safe_count($pdo, "SELECT COUNT(*) FROM user_db");
        $u_vip   = safe_count($pdo, "SELECT COUNT(*) FROM user_db WHERE subscription_type > 0 OR (active_subscription IS NOT NULL AND LOWER(TRIM(active_subscription)) NOT IN ('free','0','none','null','false',''))");
    } catch (Exception $e) {
        try { $u_total = safe_count($pdo, "SELECT COUNT(*) FROM users"); } catch (Exception $e2) {}
    }

    // Live statistics & logs
    $online_users = 0; $streaming_users = 0;
    try {
        $online_users = safe_count($pdo, "SELECT COUNT(DISTINCT user_id) FROM active_sessions WHERE last_ping > NOW() - INTERVAL 1 MINUTE");
        $streaming_users = safe_count($pdo, "SELECT COUNT(DISTINCT user_id) FROM active_sessions WHERE last_ping > NOW() - INTERVAL 1 MINUTE AND current_view = 'player'");
    } catch (Exception $e) {}

    $today_streams = 0;
    try {
        $today_streams = safe_count($pdo, "SELECT COUNT(*) FROM watch_history_analytics WHERE created_at >= CURDATE()");
    } catch (Exception $e) {}

    $top_downloads = [];
    try {
        $dl_stmt = $pdo->query("SELECT content_id, content_type, COUNT(*) as dl_count FROM download_statistics GROUP BY content_id, content_type ORDER BY dl_count DESC LIMIT 5");
        while ($r = $dl_stmt->fetch(PDO::FETCH_ASSOC)) {
            $name = "Unknown Content";
            if ($r['content_type'] == 1) {
                $m = $pdo->prepare("SELECT name FROM movies WHERE id = ?");
                $m->execute([$r['content_id']]);
                $n = $m->fetchColumn();
                if ($n) $name = $n;
            } else {
                $s = $pdo->prepare("SELECT name FROM web_series WHERE id = ?");
                $s->execute([$r['content_id']]);
                $n = $s->fetchColumn();
                if ($n) $name = $n;
            }
            $top_downloads[] = [
                "name" => $name,
                "type" => $r['content_type'] == 1 ? 'movie' : 'series',
                "count" => intval($r['dl_count'])
            ];
        }
    } catch (Exception $e) {}

    $top_movies = []; $top_series = []; $weekly_combined = [];
    try {
        $top_movies = $pdo->query("SELECT id, name, poster, IFNULL(banner,'') as banner, IFNULL(views,0) as views, IFNULL(weekly_views,0) as weekly_views, release_date, status, 'movie' as type FROM movies WHERE status = 1 ORDER BY views DESC, id DESC LIMIT 15")->fetchAll();
    } catch (Exception $e) {}
    try {
        $top_series = $pdo->query("SELECT id, name, poster, IFNULL(banner,'') as banner, IFNULL(views,0) as views, IFNULL(weekly_views,0) as weekly_views, release_date, status, 'series' as type FROM web_series WHERE status = 1 ORDER BY views DESC, id DESC LIMIT 15")->fetchAll();
    } catch (Exception $e) {}
    try {
        $w_movies = $pdo->query("SELECT id, name, poster, IFNULL(banner,'') as banner, IFNULL(views,0) as views, IFNULL(weekly_views,0) as weekly_views, release_date, 'movie' as type FROM movies WHERE status = 1 ORDER BY weekly_views DESC, views DESC, id DESC LIMIT 15")->fetchAll();
        $w_series = $pdo->query("SELECT id, name, poster, IFNULL(banner,'') as banner, IFNULL(views,0) as views, IFNULL(weekly_views,0) as weekly_views, release_date, 'series' as type FROM web_series WHERE status = 1 ORDER BY weekly_views DESC, views DESC, id DESC LIMIT 15")->fetchAll();
        $weekly_combined = array_merge($w_movies, $w_series);
        usort($weekly_combined, function($a, $b) {
            if ($a['weekly_views'] == $b['weekly_views']) return $b['views'] - $a['views'];
            return $b['weekly_views'] - $a['weekly_views'];
        });
        $weekly_combined = array_slice($weekly_combined, 0, 15);
    } catch (Exception $e) {}

    json_response(true, [
        "movies"        => ["active" => $m_active, "parked" => $m_parked, "total" => $m_total],
        "series"        => ["active" => $s_active, "parked" => $s_parked, "total" => $s_total],
        "episodes"      => ["active" => $ep_active, "total" => $ep_total],
        "movie_links"   => ["active" => $mpl_active, "dead" => $mpl_dead, "total" => $mpl_active + $mpl_dead],
        "episode_links" => ["active" => $epl_active, "dead" => $epl_dead, "total" => $epl_active + $epl_dead],
        "users"         => ["total" => $u_total, "vip" => $u_vip, "free" => max(0, $u_total - $u_vip)],
        "live"          => [
            "online_users" => $online_users,
            "streaming_users" => $streaming_users,
            "today_streams" => $today_streams,
            "top_downloads" => $top_downloads
        ],
        "top_15_movies" => $top_movies,
        "top_15_series" => $top_series,
        "weekly_trending" => $weekly_combined,
    ], "Analytics fetched successfully");
}

if ($action === 'update_views') {
    $type = $input['type'] ?? 'movie';
    $id = intval($input['id'] ?? 0);
    $views = intval($input['views'] ?? 0);
    $weekly_views = intval($input['weekly_views'] ?? 0);
    if ($id <= 0) json_response(false, [], "Content ID required");

    if ($type === 'movie') {
        $pdo->prepare("UPDATE movies SET views = ?, weekly_views = ? WHERE id = ?")->execute([$views, $weekly_views, $id]);
    } else {
        $pdo->prepare("UPDATE web_series SET views = ?, weekly_views = ? WHERE id = ?")->execute([$views, $weekly_views, $id]);
    }
    json_response(true, ["views" => $views, "weekly_views" => $weekly_views], "Views updated successfully");
}

if ($action === 'reset_all_views') {
    $pdo->exec("UPDATE movies SET views = 0, weekly_views = 0");
    $pdo->exec("UPDATE web_series SET views = 0, weekly_views = 0");
    json_response(true, [], "All view counts reset to 0 successfully");
}

//
// 14. PUSH CAMPAIGNS & ANNOUNCEMENTS
//
if ($action === 'create_push_campaign') {
    $title = $input['title'] ?? 'Newly Uploaded Today!';
    $items = $input['items'] ?? []; // Array of {"id": int, "type": "movie"|"series"}
    $hours = intval($input['hours_valid'] ?? 24);
    if ($hours <= 0) $hours = 24;
    if (empty($items)) json_response(false, [], "Please select at least one movie or web series");

    $expiry = date('Y-m-d H:i:s', strtotime("+$hours hours"));
    $jsonItems = json_encode($items);

    $pdo->exec("CREATE TABLE IF NOT EXISTS push_campaigns (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        items JSON NOT NULL,
        expiry_at DATETIME NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        status INT NOT NULL DEFAULT 1
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $stmt = $pdo->prepare("INSERT INTO push_campaigns (title, items, expiry_at, status) VALUES (?, ?, ?, 1)");
    $stmt->execute([$title, $jsonItems, $expiry]);
    json_response(true, ["campaign_id" => $pdo->lastInsertId()], "Push campaign created successfully");
}

if ($action === 'list_push_campaigns') {
    try {
        $stmt = $pdo->query("SELECT * FROM push_campaigns ORDER BY id DESC");
        $campaigns = $stmt->fetchAll();
        json_response(true, ["campaigns" => $campaigns], "Push campaigns fetched");
    } catch (Exception $e) {
        json_response(true, ["campaigns" => []], "No campaigns table");
    }
}

if ($action === 'delete_push_campaign') {
    $id = intval($input['id'] ?? 0);
    if ($id <= 0) json_response(false, [], "Campaign ID required");
    $pdo->prepare("DELETE FROM push_campaigns WHERE id = ?")->execute([$id]);
    json_response(true, [], "Push campaign deleted");
}

if ($action === 'create_announcement') {
    $title = $input['title'] ?? 'Important Announcement';
    $message = $input['message'] ?? '';
    $imageUrl = $input['image_url'] ?? '';
    $hours = intval($input['hours_valid'] ?? 72);

    if (empty($message)) json_response(false, [], "Message text required");
    $expiry = $hours > 0 ? date('Y-m-d H:i:s', strtotime("+$hours hours")) : null;

    $pdo->exec("CREATE TABLE IF NOT EXISTS announcements (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        message TEXT NOT NULL,
        image_url TEXT DEFAULT NULL,
        expiry_at DATETIME DEFAULT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        status INT NOT NULL DEFAULT 1
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $stmt = $pdo->prepare("INSERT INTO announcements (title, message, image_url, expiry_at, status) VALUES (?, ?, ?, ?, 1)");
    $stmt->execute([$title, $message, $imageUrl, $expiry]);
    json_response(true, ["announcement_id" => $pdo->lastInsertId()], "Announcement sent successfully");
}

if ($action === 'list_announcements') {
    try {
        $stmt = $pdo->query("SELECT * FROM announcements ORDER BY id DESC");
        $announcements = $stmt->fetchAll();
        json_response(true, ["announcements" => $announcements], "Announcements fetched");
    } catch (Exception $e) {
        json_response(true, ["announcements" => []], "No announcements table");
    }
}

if ($action === 'delete_announcement') {
    $id = intval($input['id'] ?? 0);
    if ($id <= 0) json_response(false, [], "Announcement ID required");
    $pdo->prepare("DELETE FROM announcements WHERE id = ?")->execute([$id]);
    json_response(true, [], "Announcement deleted");
}

if ($action === 'submit_report') {
    $userId = intval($input['user_id'] ?? 0);
    $contentId = intval($input['content_id'] ?? 0);
    $contentType = intval($input['content_type'] ?? 0);
    $message = trim($input['message'] ?? '');

    if ($userId <= 0 || $contentId <= 0 || $contentType <= 0 || empty($message)) {
        json_response(false, [], "All parameters (user_id, content_id, content_type, message) are required");
    }

    $stmt = $pdo->prepare("INSERT INTO user_reports (user_id, content_id, content_type, message, status, reply_seen) VALUES (?, ?, ?, ?, 0, 0)");
    $stmt->execute([$userId, $contentId, $contentType, $message]);
    json_response(true, ["report_id" => $pdo->lastInsertId()], "Report submitted successfully");
}

if ($action === 'get_user_notifications') {
    $userId = intval($input['user_id'] ?? $_GET['user_id'] ?? 0);
    if ($userId <= 0) {
        json_response(false, [], "User ID is required");
    }

    $stmt = $pdo->prepare("
        SELECT r.id, r.content_id, r.content_type, r.message, r.status, r.admin_reply, r.created_at,
               CASE WHEN r.content_type = 1 THEN m.name ELSE s.name END as content_name
        FROM user_reports r
        LEFT JOIN movies m ON m.id = r.content_id AND r.content_type = 1
        LEFT JOIN web_series s ON s.id = r.content_id AND r.content_type = 2
        WHERE r.user_id = ? AND r.status > 0 AND r.reply_seen = 0
        ORDER BY r.id DESC
    ");
    $stmt->execute([$userId]);
    $replies = $stmt->fetchAll(PDO::FETCH_ASSOC);

    if (!empty($replies)) {
        $ids = array_column($replies, 'id');
        $in = implode(',', array_map('intval', $ids));
        $pdo->exec("UPDATE user_reports SET reply_seen = 1 WHERE id IN ($in)");
    }

    json_response(true, ["notifications" => $replies], "Notifications fetched");
}

if ($action === 'list_reports') {
    $userTable = 'user_db';
    try {
        $pdo->query("SELECT 1 FROM user_db LIMIT 1");
    } catch (Exception $e) {
        $userTable = 'users';
    }

    $reports = $pdo->query("
        SELECT r.*,
               CASE WHEN r.content_type = 1 THEN m.name ELSE s.name END as content_name,
               CASE WHEN r.content_type = 1 THEN m.poster ELSE s.poster END as content_poster,
               u.name as user_name, u.email as user_email
        FROM user_reports r
        LEFT JOIN movies m ON m.id = r.content_id AND r.content_type = 1
        LEFT JOIN web_series s ON s.id = r.content_id AND r.content_type = 2
        LEFT JOIN $userTable u ON u.id = r.user_id
        ORDER BY r.status ASC, r.id DESC
        LIMIT 200
    ")->fetchAll(PDO::FETCH_ASSOC);

    json_response(true, ["reports" => $reports], "Reports fetched");
}

if ($action === 'resolve_report') {
    $id = intval($input['report_id'] ?? 0);
    $status = intval($input['status'] ?? 1); // 1 = Accepted, 2 = Rejected
    $adminReply = trim($input['admin_reply'] ?? '');

    if ($id <= 0 || ($status !== 1 && $status !== 2)) {
        json_response(false, [], "Invalid parameters (report_id, status)");
    }

    $stmt = $pdo->prepare("UPDATE user_reports SET status = ?, admin_reply = ?, reply_seen = 0 WHERE id = ?");
    $stmt->execute([$status, $adminReply, $id]);
    json_response(true, [], "Report resolved successfully");
}

if ($action === 'delete_report') {
    $id = intval($input['report_id'] ?? 0);
    if ($id <= 0) {
        json_response(false, [], "Report ID required");
    }
    $pdo->prepare("DELETE FROM user_reports WHERE id = ?")->execute([$id]);
    json_response(true, [], "Report deleted successfully");
}

if ($action === 'delete_user') {
    $uid = intval($input['user_id'] ?? 0);
    if ($uid <= 0) {
        json_response(false, [], "User ID required");
    }
    $pdo->prepare("DELETE FROM user_reports WHERE user_id = ?")->execute([$uid]);
    $pdo->prepare("DELETE FROM favorites WHERE user_id = ?")->execute([$uid]);
    $pdo->prepare("DELETE FROM favourite WHERE user_id = ?")->execute([$uid]);
    $pdo->prepare("DELETE FROM subscription_history WHERE user_id = ?")->execute([$uid]);
    $pdo->prepare("DELETE FROM watch_log WHERE user_id = ?")->execute([$uid]);
    $pdo->prepare("DELETE FROM user_db WHERE id = ?")->execute([$uid]);
    json_response(true, [], "User deleted successfully");
}

//
// 14. UPCOMING CONTENT CRUD
//
if ($action === 'list_upcoming') {
    try {
        $stmt = $pdo->query("SELECT * FROM upcoming_contents ORDER BY id DESC");
        $upcoming = $stmt->fetchAll(PDO::FETCH_ASSOC);
        foreach ($upcoming as &$item) {
            $item['youtube_trailer'] = $item['trailer_url'] ?? '';
            $item['banner'] = $item['poster'] ?? '';
        }
        json_response(true, ["upcoming" => $upcoming], "Upcoming content fetched");
    } catch (Exception $e) {
        json_response(true, ["upcoming" => []], "Upcoming content fetched");
    }
}

if ($action === 'add_upcoming') {
    $name = trim($input['name'] ?? '');
    $description = trim($input['description'] ?? '');
    $poster = trim($input['poster'] ?? '');
    $release_date = trim($input['release_date'] ?? '');
    $trailer_url = trim($input['youtube_trailer'] ?? $input['trailer_url'] ?? '');
    $type = intval($input['type'] ?? 1);
    $status = intval($input['status'] ?? 1);

    if (empty($name)) {
        json_response(false, [], "Name is required");
    }

    try {
        $stmt = $pdo->prepare("INSERT INTO upcoming_contents (tmdb_id, name, description, poster, trailer_url, release_date, type, status) VALUES (0, ?, ?, ?, ?, ?, ?, ?)");
        $stmt->execute([$name, $description, $poster, $trailer_url, $release_date, $type, $status]);
        json_response(true, ["id" => $pdo->lastInsertId()], "Upcoming content added successfully");
    } catch (Exception $e) {
        json_response(false, [], "Failed to save upcoming content: " . $e->getMessage());
    }
}

if ($action === 'edit_upcoming') {
    $id = intval($input['id'] ?? 0);
    $name = trim($input['name'] ?? '');
    $description = trim($input['description'] ?? '');
    $poster = trim($input['poster'] ?? '');
    $release_date = trim($input['release_date'] ?? '');
    $trailer_url = trim($input['youtube_trailer'] ?? $input['trailer_url'] ?? '');
    $type = intval($input['type'] ?? 1);
    $status = intval($input['status'] ?? 1);

    if ($id <= 0 || empty($name)) {
        json_response(false, [], "ID and Name are required");
    }

    try {
        $stmt = $pdo->prepare("UPDATE upcoming_contents SET name = ?, description = ?, poster = ?, trailer_url = ?, release_date = ?, type = ?, status = ? WHERE id = ?");
        $stmt->execute([$name, $description, $poster, $trailer_url, $release_date, $type, $status, $id]);
        json_response(true, [], "Upcoming content updated successfully");
    } catch (Exception $e) {
        json_response(false, [], "Failed to update upcoming content: " . $e->getMessage());
    }
}

if ($action === 'delete_upcoming') {
    $id = intval($input['id'] ?? 0);
    if ($id <= 0) {
        json_response(false, [], "ID is required");
    }
    try {
        $pdo->prepare("DELETE FROM upcoming_contents WHERE id = ?")->execute([$id]);
        json_response(true, [], "Upcoming content deleted successfully");
    } catch (Exception $e) {
        json_response(false, [], "Failed to delete upcoming content: " . $e->getMessage());
    }
}

//
// 15. OTT PLATFORMS & GENRES CRUD
//
if ($action === 'add_genre') {
    $name = trim($input['name'] ?? '');
    $icon = trim($input['icon'] ?? '');
    if (empty($name)) {
        json_response(false, [], "Name is required");
    }
    try {
        $stmt = $pdo->prepare("INSERT INTO genres (name, icon, status, sort_order) VALUES (?, ?, 1, 0)");
        $stmt->execute([$name, $icon]);
        json_response(true, ["id" => $pdo->lastInsertId()], "Genre added successfully");
    } catch (Exception $e) {
        json_response(false, [], "Failed to save genre: " . $e->getMessage());
    }
}

if ($action === 'delete_genre') {
    $id = intval($input['id'] ?? 0);
    if ($id <= 0) {
        json_response(false, [], "ID is required");
    }
    try {
        $pdo->prepare("DELETE FROM genres WHERE id = ?")->execute([$id]);
        json_response(true, [], "Genre deleted successfully");
    } catch (Exception $e) {
        json_response(false, [], "Failed to delete genre: " . $e->getMessage());
    }
}

//
// 16. CAST & NETWORKS CRUD
//
if ($action === 'list_networks') {
    try {
        $stmt = $pdo->query("SELECT id, name, logo, COALESCE(status, 1) as status, COALESCE(networks_order, 0) as networks_order FROM networks ORDER BY networks_order ASC, name ASC");
        $networks = $stmt->fetchAll(PDO::FETCH_ASSOC);
        json_response(true, ["networks" => $networks], "Networks fetched");
    } catch (Exception $e) {
        try {
            $networks = $pdo->query("SELECT id, name, logo FROM networks ORDER BY name ASC")->fetchAll(PDO::FETCH_ASSOC);
            json_response(true, ["networks" => $networks], "Networks fetched");
        } catch (Exception $e2) {
            json_response(true, ["networks" => []], "Networks fetched");
        }
    }
}

if ($action === 'add_network') {
    $name = trim($input['name'] ?? '');
    $logo = trim($input['logo'] ?? '');
    if (empty($name)) {
        json_response(false, [], "Name is required");
    }
    try {
        $stmt = $pdo->prepare("INSERT INTO networks (name, logo, status, networks_order) VALUES (?, ?, 1, 0)");
        $stmt->execute([$name, $logo]);
        json_response(true, ["id" => $pdo->lastInsertId()], "Network added successfully");
    } catch (Exception $e) {
        json_response(false, [], "Failed to save network: " . $e->getMessage());
    }
}

if ($action === 'delete_network') {
    $id = intval($input['id'] ?? 0);
    if ($id <= 0) {
        json_response(false, [], "ID is required");
    }
    try {
        $pdo->prepare("DELETE FROM networks WHERE id = ?")->execute([$id]);
        json_response(true, [], "Network deleted successfully");
    } catch (Exception $e) {
        json_response(false, [], "Failed to delete network: " . $e->getMessage());
    }
}

//  list_seasons 
if ($action === 'list_seasons') {
    $series_id = intval($input['series_id'] ?? 0);
    if ($series_id <= 0) json_response(false, [], "series_id required");
    try {
        $stmt = $pdo->prepare(
            "SELECT id, Session_Name AS name, season_order AS `order`, status
             FROM web_series_seasons
             WHERE web_series_id = ?
             ORDER BY season_order ASC, id ASC"
        );
        $stmt->execute([$series_id]);
        json_response(true, ["seasons" => $stmt->fetchAll()], "Seasons fetched");
    } catch (Exception $e) {
        json_response(true, ["seasons" => []], "Seasons fetched (empty)");
    }
}

//  list_episodes 
if ($action === 'list_episodes') {
    $season_id = intval($input['season_id'] ?? 0);
    if ($season_id <= 0) json_response(false, [], "season_id required");
    try {
        $stmt = $pdo->prepare(
            "SELECT ep.id, ep.Episoade_Name AS name, ep.episoade_image AS banner,
                    ep.status,
                    IFNULL(epl.url,'')    AS play_link,
                    IFNULL(epl.quality,'720p') AS quality
             FROM web_series_episoade ep
             LEFT JOIN episode_play_links epl ON epl.episode_id = ep.id
             WHERE ep.season_id = ?
             ORDER BY ep.episoade_order ASC, ep.id ASC"
        );
        $stmt->execute([$season_id]);
        json_response(true, ["episodes" => $stmt->fetchAll()], "Episodes fetched");
    } catch (Exception $e) {
        json_response(true, ["episodes" => []], "Episodes fetched (empty)");
    }
}


// =============================================================================
// OTT GENRE SORT AND HIDE ACTIONS
// =============================================================================

if ($action === 'edit_genre') {
    $id = intval($input['id'] ?? 0);
    if ($id <= 0) json_response(false, [], 'Genre ID required');
    $fields = [];
    $params = [];
    foreach (['name', 'icon', 'description', 'color'] as $f) {
        if (isset($input[$f])) {
            $fields[] = "$f = ?";
            $params[] = trim((string)$input[$f]);
        }
    }
    if (isset($input['status'])) {
        $fields[] = 'status = ?';
        $params[] = intval($input['status']);
    }
    if (isset($input['sort_order'])) {
        $fields[] = 'sort_order = ?';
        $params[] = intval($input['sort_order']);
    }
    if (empty($fields)) json_response(false, [], 'No fields to update');
    try {
        $params[] = $id;
        $sql = 'UPDATE genres SET ' . implode(', ', $fields) . ' WHERE id = ?';
        $pdo->prepare($sql)->execute($params);
        json_response(true, [], 'Genre updated successfully');
    } catch (Exception $e) {
        json_response(false, [], 'DB error: ' . $e->getMessage());
    }
}

if ($action === 'reorder_genres') {
    $order = trim($input['order'] ?? '');
    if (empty($order)) json_response(false, [], 'Order required');
    $ids = array_values(array_filter(array_map('intval', explode(',', $order))));
    if (empty($ids)) json_response(false, [], 'No valid IDs');
    try {
        $stmt = $pdo->prepare('UPDATE genres SET sort_order = ? WHERE id = ?');
        foreach ($ids as $sortOrder => $genreId) {
            $stmt->execute([$sortOrder, $genreId]);
        }
        json_response(true, [], 'Genre order updated');
    } catch (Exception $e) {
        json_response(false, [], 'DB error: ' . $e->getMessage());
    }
}

// =============================================================================
// OTT NETWORK TOGGLE AND EDIT ACTIONS
// =============================================================================

if ($action === 'toggle_network_status' || $action === 'toggle_network' || $action === 'toggle_ott_status') {
    $id = intval($input['id'] ?? 0);
    $status = intval($input['status'] ?? 1);
    if ($id <= 0) json_response(false, [], 'Network ID required');
    try {
        $pdo->prepare('UPDATE networks SET status = ? WHERE id = ?')->execute([$status, $id]);
        json_response(true, ['status' => $status], 'Network status updated');
    } catch (Exception $e) {
        json_response(false, [], 'DB error: ' . $e->getMessage());
    }
}

if ($action === 'edit_network') {
    $id = intval($input['id'] ?? 0);
    if ($id <= 0) json_response(false, [], 'Network ID required');
    $fields = [];
    $params = [];
    foreach (['name', 'logo'] as $f) {
        if (isset($input[$f])) {
            $fields[] = "$f = ?";
            $params[] = trim((string)$input[$f]);
        }
    }
    if (isset($input['status'])) {
        $fields[] = 'status = ?';
        $params[] = intval($input['status']);
    }
    if (isset($input['networks_order'])) {
        $fields[] = 'networks_order = ?';
        $params[] = intval($input['networks_order']);
    }
    if (empty($fields)) json_response(false, [], 'No fields to update');
    try {
        $params[] = $id;
        $pdo->prepare('UPDATE networks SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);
        json_response(true, [], 'Network updated');
    } catch (Exception $e) {
        json_response(false, [], 'DB error: ' . $e->getMessage());
    }
}

if ($action === 'reorder_networks') {
    $order = trim($input['order'] ?? '');
    if (empty($order)) json_response(false, [], 'Order required');
    $ids = array_values(array_filter(array_map('intval', explode(',', $order))));
    if (empty($ids)) json_response(false, [], 'No valid IDs');
    try {
        $stmt = $pdo->prepare('UPDATE networks SET networks_order = ? WHERE id = ?');
        foreach ($ids as $sortOrder => $networkId) {
            $stmt->execute([$sortOrder, $networkId]);
        }
        json_response(true, [], 'Network order updated');
    } catch (Exception $e) {
        json_response(false, [], 'DB error: ' . $e->getMessage());
    }
}

if ($action === 'get_app_settings') {
    try {
        $pdo->exec("CREATE TABLE IF NOT EXISTS app_settings (
            id INT AUTO_INCREMENT PRIMARY KEY,
            skey VARCHAR(100) UNIQUE NOT NULL,
            svalue TEXT
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

        $stmt = $pdo->query("SELECT skey, svalue FROM app_settings");
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $settings = [];
        foreach ($rows as $row) {
            $settings[$row['skey']] = $row['svalue'];
        }
        json_response(true, ["settings" => $settings], "Settings loaded");
    } catch (Exception $e) {
        json_response(false, [], "DB error: " . $e->getMessage());
    }
}

if ($action === 'save_app_settings') {
    $settings = $input['settings'] ?? $_POST['settings'] ?? [];
    if (is_string($settings)) {
        $settings = json_decode($settings, true) ?? [];
    }
    if (!is_array($settings)) {
        json_response(false, [], "Invalid settings object");
    }

    try {
        $pdo->exec("CREATE TABLE IF NOT EXISTS app_settings (
            id INT AUTO_INCREMENT PRIMARY KEY,
            skey VARCHAR(100) UNIQUE NOT NULL,
            svalue TEXT
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

        $stmt = $pdo->prepare("INSERT INTO app_settings (skey, svalue) VALUES (?, ?) ON DUPLICATE KEY UPDATE svalue = VALUES(svalue)");
        foreach ($settings as $k => $v) {
            $stmt->execute([(string)$k, (string)$v]);
        }
        json_response(true, [], "Settings saved successfully");
    } catch (Exception $e) {
        json_response(false, [], "DB error: " . $e->getMessage());
    }
}

// ------------------------------------------------------------------
// SKYMOVIESHD & HDMAAL AUTOMATION ENGINE
// ------------------------------------------------------------------


function resolve_streamtape_url($url) {
    if (empty($url)) return '';
    $url = trim($url);

    // Direct Streamtape or mirror link with /v/ or /e/
    if (preg_match('~/(?:v|e)/([a-zA-Z0-9_-]+)~', $url, $m)) {
        if (strpos($url, 'streamtape') !== false || strpos($url, 'tpead') !== false || strpos($url, 'tapepops') !== false || strpos($url, 'adblocktpe') !== false || strpos($url, 'advtpe') !== false || strpos($url, 'stape') !== false || strpos($url, 'strcloud') !== false) {
            return "https://streamtape.com/v/" . $m[1];
        }
    }

    // Resolve protector/intermediary URLs (uplinks24, toolkitspro, howblogs, goflix, etc.)
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_MAXREDIRS      => 5,
        CURLOPT_TIMEOUT        => 12,
        CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
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

function base_n_convert($num, $b) {
    $chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    if ($num < $b) return $chars[$num];
    return base_n_convert(intdiv($num, $b), $b) . $chars[$num % $b];
}

function unpack_dean_edwards_php($p, $a, $c, $k) {
    for ($i = $c - 1; $i >= 0; $i--) {
        if (isset($k[$i]) && $k[$i] !== '') {
            $key = base_n_convert($i, $a);
            $p = preg_replace('/\b' . preg_quote($key, '/') . '\b/', $k[$i], $p);
        }
    }
    return $p;
}

function get_luluvdo_code($url) {
    $path = parse_url($url, PHP_URL_PATH);
    if (empty($path)) return '';
    $parts = array_values(array_filter(explode('/', $path)));
    if (empty($parts)) return '';
    return end($parts);
}

function resolve_luluvdo_url($url) {
    if (empty($url)) return '';
    $url = trim($url);

    $file_code = get_luluvdo_code($url);
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
            CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
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

            $unpacked = unpack_dean_edwards_php($p, $a, $c, $k);
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

function resolve_uplinks24_urls($url) {
    if (preg_match('/uplinks24\.com\/view\/([a-zA-Z0-9]+)/i', $url, $m)) {
        $code = $m[1];
        $cookie_file = tempnam(sys_get_temp_dir(), 'u24');
        $view_url = "https://uplinks24.com/view/$code";
        $save_url = "https://uplinks24.com/save/$code";
        $headers = [
            'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer: https://hdmove99.com/',
        ];
        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL => $view_url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_COOKIEJAR => $cookie_file,
            CURLOPT_COOKIEFILE => $cookie_file,
            CURLOPT_TIMEOUT => 10,
        ]);
        $h1 = curl_exec($ch);
        curl_close($ch);

        if ($h1 && preg_match('/name=["\'](_csrf_token_[^"\']+)["\']/', $h1, $cm) && preg_match('/value=["\']([a-f0-9]{32,40})["\']/', $h1, $vm)) {
            $csrf_field = $cm[1];
            $csrf_val = $vm[1];
            $ch = curl_init();
            curl_setopt_array($ch, [
                CURLOPT_URL => $view_url,
                CURLOPT_POST => true,
                CURLOPT_POSTFIELDS => http_build_query([$csrf_field => $csrf_val]),
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_HTTPHEADER => array_merge($headers, ['Content-Type: application/x-www-form-urlencoded']),
                CURLOPT_COOKIEJAR => $cookie_file,
                CURLOPT_COOKIEFILE => $cookie_file,
                CURLOPT_TIMEOUT => 10,
            ]);
            curl_exec($ch);
            curl_close($ch);

            $ch = curl_init();
            curl_setopt_array($ch, [
                CURLOPT_URL => $save_url,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_HTTPHEADER => $headers,
                CURLOPT_COOKIEJAR => $cookie_file,
                CURLOPT_COOKIEFILE => $cookie_file,
                CURLOPT_TIMEOUT => 10,
            ]);
            $h3 = curl_exec($ch);
            curl_close($ch);
            @unlink($cookie_file);

            if ($h3) {
                $lines = explode("\n", $h3);
                $found = [];
                foreach ($lines as $line) {
                    $l = trim($line);
                    if (strpos($l, 'http') === 0 && strpos($l, '.jpg') === false && strpos($l, '.png') === false) {
                        $found[] = $l;
                    }
                }
                return $found;
            }
        }
        @unlink($cookie_file);
    }
    return [];
}

function resolve_server_stream_url($url) {
    if (empty($url)) return '';
    $url = trim($url);

    // 0. Check uplinks24
    if (strpos($url, 'uplinks24.com') !== false) {
        $u_links = resolve_uplinks24_urls($url);
        foreach ($u_links as $ul) {
            $res = resolve_server_stream_url($ul);
            if (!empty($res)) return $res;
        }
    }

    // 1. Check Streamtape / mirrors
    if (strpos($url, 'streamtape') !== false || strpos($url, 'tpead') !== false || strpos($url, 'tapepops') !== false || strpos($url, 'adblocktpe') !== false || strpos($url, 'advtpe') !== false || strpos($url, 'stape') !== false || strpos($url, 'strcloud') !== false) {
        return resolve_streamtape_url($url);
    }

    // 2. Check Luluvdo / LuluStream / LuluCDN
    if (strpos($url, 'luluvdo') !== false || strpos($url, 'lulustream') !== false || strpos($url, 'lulucdn') !== false) {
        return resolve_luluvdo_url($url);
    }

    // 3. Direct M3U8 or MP4
    if (preg_match('/\.m3u8|\.mp4/i', $url)) {
        return $url;
    }

    // 4. Try resolving through protector / intermediary pages
    $st = resolve_streamtape_url($url);
    if (!empty($st)) return $st;

    $lulu = resolve_luluvdo_url($url);
    if (!empty($lulu)) return $lulu;

    return '';
}

function get_scraper_domains($pdo) {
    $skymovies_domain = 'https://skymovieshd.ceo';
    $hdmaal_domain = 'https://hdmaal.gg';
    $uncutmasti_domain = 'https://uncutmasti.com';
    $hdmove99_domain = 'https://hdmove99.com';
    try {
        $stmt = $pdo->query("SELECT skey, svalue FROM app_settings WHERE skey IN ('skymovies_domain', 'hdmaal_domain', 'uncutmasti_domain', 'hdmove99_domain')");
        foreach ($stmt->fetchAll() as $row) {
            $val = rtrim(trim($row['svalue']), '/');
            if ($row['skey'] === 'skymovies_domain' && !empty($val)) $skymovies_domain = $val;
            if ($row['skey'] === 'hdmaal_domain' && !empty($val)) $hdmaal_domain = $val;
            if ($row['skey'] === 'uncutmasti_domain' && !empty($val)) $uncutmasti_domain = $val;
            if ($row['skey'] === 'hdmove99_domain' && !empty($val)) $hdmove99_domain = $val;
        }
    } catch (Exception $e) {}
    return [$skymovies_domain, $hdmaal_domain, $uncutmasti_domain, $hdmove99_domain];
}

function download_and_host_image($img_url, $title = '', $episode = '') {
    if (empty($img_url) || !filter_var($img_url, FILTER_VALIDATE_URL)) return $img_url;
    
    // Check if it's already on our hosting server
    if (strpos($img_url, 'goprivate.fun') !== false || strpos($img_url, 'localhost') !== false) {
        return $img_url;
    }

    $ext = pathinfo(parse_url($img_url, PHP_URL_PATH), PATHINFO_EXTENSION);
    if (empty($ext) || strlen($ext) > 5) $ext = 'jpg';

    // Clean title & episode to build clean folder & filenames e.g. /uploads/posters/Movie_Title/
    $clean_title = !empty($title) ? preg_replace('/[^a-zA-Z0-9_-]/', '_', trim($title)) : '';
    $clean_title = preg_replace('/_+/', '_', trim($clean_title, '_'));
    $clean_ep = !empty($episode) ? preg_replace('/[^a-zA-Z0-9_-]/', '_', trim($episode)) : '';
    $clean_ep = preg_replace('/_+/', '_', trim($clean_ep, '_'));

    if (!empty($clean_title)) {
        $sub_dir = 'posters/' . $clean_title . '/';
    } else {
        $sub_dir = 'posters/';
    }

    $upload_dir = __DIR__ . '/uploads/' . $sub_dir;
    if (!file_exists($upload_dir)) {
        @mkdir($upload_dir, 0755, true);
    }

    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $img_url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT        => 15,
        CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    ]);
    $data = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($http_code === 200 && !empty($data)) {
        if (!empty($clean_ep)) {
            $filename = $clean_ep . '.' . $ext;
        } else if (!empty($clean_title)) {
            $filename = $clean_title . '_poster.' . $ext;
        } else {
            $filename = 'poster_' . time() . '_' . substr(md5($img_url), 0, 8) . '.' . $ext;
        }
        $target_file = $upload_dir . $filename;
        if (file_put_contents($target_file, $data)) {
            $scheme = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') ? 'https' : 'http';
            $host = $_SERVER['HTTP_HOST'] ?? 'red.goprivate.fun';
            $base_path = rtrim(dirname($_SERVER['SCRIPT_NAME']), '/\\');
            return "$scheme://$host$base_path/uploads/$sub_dir$filename";
        }
    }
    return $img_url;
}

if ($action === 'download_remote_poster') {
    $img_url = trim($input['url'] ?? $_POST['url'] ?? '');
    $title = trim($input['title'] ?? $_POST['title'] ?? '');
    $episode = trim($input['episode'] ?? $_POST['episode'] ?? '');
    if (empty($img_url)) json_response(false, [], 'Image URL required');
    $local_url = download_and_host_image($img_url, $title, $episode);
    json_response(true, ['url' => $local_url], 'Poster saved to server');
}

if ($action === 'fetch_skymovies_catalog') {
    list($skymovies_domain, $hdmaal_domain) = get_scraper_domains($pdo);
    $page = intval($input['page'] ?? 1);
    $category = trim($input['category'] ?? 'Hot-Short-Film');
    
    $url = "$skymovies_domain/category/$category.html";
    if ($page > 1) {
        $url = "$skymovies_domain/category/$category/$page.html";
    }

    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT        => 15,
        CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    ]);
    $html = curl_exec($ch);
    curl_close($ch);

    $items = [];
    if ($html) {
        // Robust regex matching all <div class='L'>...<a href='...'>...</a></div> structures
        preg_match_all('/<div class=[\'"]L[\'"][^>]*>.*?<a href=[\'"]([^\'"]+)[\'"][^>]*>(?:<img[^>]*>)?\s*(.*?)\s*<\/a>/is', $html, $matches, PREG_SET_ORDER);
        
        if (empty($matches)) {
            preg_match_all('/<div class=[\'"]Let[\'"][^>]*>.*?<a href=[\'"]([^\'"]+)[\'"][^>]*>(?:<img[^>]*>)?\s*(.*?)\s*<\/a>/is', $html, $matches, PREG_SET_ORDER);
        }
        if (empty($matches)) {
            preg_match_all('/<div class=[\'"]Fmvideo[\'"][^>]*>.*?<a href=[\'"]([^\'"]+)[\'"][^>]*>(?:<img[^>]*>)?\s*(.*?)\s*<\/a>/is', $html, $matches, PREG_SET_ORDER);
        }

        foreach ($matches as $m) {
            $item_link = $m[1];
            $item_title = trim(strip_tags(html_entity_decode($m[2])));

            if (empty($item_link) || strpos($item_link, 'disclaimer') !== false || strpos($item_link, 'index.php') !== false) {
                continue;
            }

            if (strpos($item_link, 'http') === false) {
                $item_link = $skymovies_domain . '/' . ltrim($item_link, '/');
            }

            $items[] = [
                'title' => $item_title,
                'page_url' => $item_link,
                'poster' => '',
            ];
        }
    }

    json_response(true, ['items' => $items, 'domain' => $skymovies_domain], 'Skymovies catalog fetched');
}

if ($action === 'search_skymovies_catalog') {
    list($skymovies_domain, $hdmaal_domain) = get_scraper_domains($pdo);
    $query = trim($input['query'] ?? $_POST['query'] ?? '');
    if (empty($query)) json_response(false, [], 'Query required');

    $search_url = "$skymovies_domain/search.php?search=" . urlencode($query) . "&cat=All";
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $search_url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT        => 15,
        CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    ]);
    $html = curl_exec($ch);
    curl_close($ch);

    $items = [];
    if ($html) {
        preg_match_all('/<div class=[\'"](?:L|Let|Fmvideo)[\'"][^>]*>.*?<a href=[\'"]([^\'"]+)[\'"][^>]*>(?:<img[^>]*>)?\s*(.*?)\s*<\/a>/is', $html, $matches, PREG_SET_ORDER);
        foreach ($matches as $m) {
            $item_link = $m[1];
            $item_title = trim(strip_tags(html_entity_decode($m[2])));
            if (empty($item_link) || strpos($item_link, 'disclaimer') !== false || strpos($item_link, 'index.php') !== false) continue;
            if (strpos($item_link, 'http') === false) {
                $item_link = $skymovies_domain . '/' . ltrim($item_link, '/');
            }
            $items[] = [
                'title' => $item_title,
                'page_url' => $item_link,
            ];
        }
    }

    json_response(true, ['items' => $items], 'Skymovies catalog search completed');
}

if ($action === 'search_hdmaal_catalog') {
    list($skymovies_domain, $hdmaal_domain) = get_scraper_domains($pdo);
    $query = trim($input['query'] ?? $_POST['query'] ?? $_GET['query'] ?? '');
    if (empty($query)) json_response(false, [], 'Query required');

    $search_url = "$hdmaal_domain/?s=" . urlencode($query);
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $search_url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT        => 12,
        CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    ]);
    $html = curl_exec($ch);
    curl_close($ch);

    $items = [];
    if ($html) {
        preg_match_all('/<a[^>]+href=[\'"](https?:\/\/[^\'"]+)[\'"][^>]*>(?:(?!<\/a>).)*?<h2[^>]*class=[\'"]vtitle[\'"][^>]*>(.*?)<\/h2>/is', $html, $matches);
        for ($i = 0; $i < count($matches[1]); $i++) {
            $purl = $matches[1][$i];
            $title = trim(html_entity_decode(strip_tags($matches[2][$i])));
            if (!empty($title) && strpos($purl, '/tag/') === false && strpos($purl, '/category/') === false && strpos($purl, '/topic/') === false) {
                $img_url = '';
                if (preg_match('/<img[^>]+(?:src|data-src)=[\'"]([^\'"]+)[\'"]/i', $matches[0][$i], $im)) {
                    $img_url = $im[1];
                }
                $items[] = [
                    'title' => $title,
                    'page_url' => $purl,
                    'poster' => $img_url,
                ];
            }
        }
    }

    json_response(true, ['items' => $items], 'HDMaal catalog search completed');
}


if ($action === 'fetch_hdmove99_catalog') {
    $query = trim($input['query'] ?? $_POST['query'] ?? $_GET['query'] ?? '');
    $page = intval($input['page'] ?? $_POST['page'] ?? $_GET['page'] ?? 1);
    if ($page <= 0) $page = 1;

    list($skymovies_domain, $hdmaal_domain, $uncutmasti_domain, $hdmove99_domain) = get_scraper_domains($pdo);

    if (!empty($query)) {
        $fetch_url = "$hdmove99_domain/wp-json/wp/v2/posts?search=" . urlencode($query) . "&page=$page&per_page=24&_embed=1";
    } else {
        $fetch_url = "$hdmove99_domain/wp-json/wp/v2/posts?page=$page&per_page=24&_embed=1";
    }

    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $fetch_url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT        => 15,
        CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    ]);
    $res = curl_exec($ch);
    curl_close($ch);

    $items = [];
    $data = @json_decode($res, true);
    if (is_array($data)) {
        foreach ($data as $post) {
            $poster = '';
            if (isset($post['_embedded']['wp:featuredmedia'][0]['source_url'])) {
                $poster = $post['_embedded']['wp:featuredmedia'][0]['source_url'];
            }
            if (empty($poster) && isset($post['content']['rendered'])) {
                if (preg_match('/https?:\/\/blogger\.googleusercontent\.com\/img\/[^\s\'"<>]+/i', $post['content']['rendered'], $bm)) {
                    $poster = $bm[0];
                }
            }
            $raw_date = $post['date'] ?? '';
            $date = !empty($raw_date) ? date('Y-m-d', strtotime($raw_date)) : '';

            $items[] = [
                'title' => html_entity_decode($post['title']['rendered'] ?? ''),
                'page_url' => $post['link'] ?? '',
                'poster' => $poster,
                'date' => $date,
            ];
        }
    }

    json_response(true, ['items' => $items, 'page' => $page], 'HDMove99 catalog fetched');
}

if ($action === 'search_hdmove99_catalog') {
    $query = trim($input['query'] ?? $_POST['query'] ?? '');
    if (empty($query)) json_response(false, [], 'Query required');

    list($skymovies_domain, $hdmaal_domain, $uncutmasti_domain, $hdmove99_domain) = get_scraper_domains($pdo);
    $search_url = "$hdmove99_domain/wp-json/wp/v2/posts?search=" . urlencode($query) . "&per_page=25&_embed=1";
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $search_url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT        => 15,
        CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    ]);
    $res = curl_exec($ch);
    curl_close($ch);

    $items = [];
    $data = @json_decode($res, true);
    if (is_array($data)) {
        foreach ($data as $post) {
            $poster = '';
            if (isset($post['_embedded']['wp:featuredmedia'][0]['source_url'])) {
                $poster = $post['_embedded']['wp:featuredmedia'][0]['source_url'];
            }
            if (empty($poster) && isset($post['content']['rendered'])) {
                if (preg_match('/https?:\/\/blogger\.googleusercontent\.com\/img\/[^\s\'"<>]+/i', $post['content']['rendered'], $bm)) {
                    $poster = $bm[0];
                }
            }
            $items[] = [
                'title' => html_entity_decode($post['title']['rendered'] ?? ''),
                'page_url' => $post['link'] ?? '',
                'poster' => $poster,
            ];
        }
    }

    json_response(true, ['items' => $items], 'HDMove99 catalog search completed');
}

if ($action === 'extract_hdmove99_details') {
    $page_url = trim($input['page_url'] ?? '');
    if (empty($page_url)) json_response(false, [], 'Page URL required');

    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $page_url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT        => 15,
        CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    ]);
    $html = curl_exec($ch);
    curl_close($ch);

    if (!$html) {
        json_response(false, [], 'Failed to fetch HDMove99 page');
    }

    // 1. Extract Title
    $title = '';
    if (preg_match('/<title>\s*(.*?)\s*<\/title>/is', $html, $m)) {
        $title = trim(preg_replace('/ - HDmovie99\.Com| - HDMove99|HDmovie99|HDMove99/i', '', html_entity_decode($m[1])));
    }

    // 2. Extract Portrait Poster (check og:image or Google Blogger poster images)
    $poster = '';
    if (preg_match('/<meta property=[\'"]og:image[\'"] content=[\'"]([^\'"]+)[\'"]/i', $html, $m)) {
        $poster = $m[1];
    } elseif (preg_match('/<img[^\x3e]*src=[\'"](https?:\/\/blogger\.googleusercontent\.com\/img\/[^\'"]+)[\'"]/i', $html, $m)) {
        $poster = $m[1];
    }

    // 3. Extract Release Date
    $release_date = date('Y-m-d');
    if (preg_match('/<meta property=[\'"]article:published_time[\'"] content=[\'"]([^\'"]+)[\'"]/i', $html, $m)) {
        $release_date = date('Y-m-d', strtotime($m[1]));
    } elseif (preg_match('/datetime=[\'"]([^\'"]+)[\'"]/i', $html, $m)) {
        $release_date = date('Y-m-d', strtotime($m[1]));
    }

    // 4. Extract All Video Stream Links (uplinks24, Streamtape, Luluvdo, Direct HLS/MP4)
    $play_links = [];
    $seen_urls = [];

    // Check uplinks24 codes first
    if (preg_match_all('/uplinks24\.com\/view\/([a-zA-Z0-9]+)/i', $html, $um)) {
        $codes = array_unique($um[1]);
        foreach ($codes as $code) {
            $raw_links = resolve_uplinks24_urls("https://uplinks24.com/view/$code");
            foreach ($raw_links as $rlink) {
                $resolved = resolve_server_stream_url($rlink);
                if (!empty($resolved) && !isset($seen_urls[$resolved])) {
                    $seen_urls[$resolved] = true;
                    $seen_urls[$rlink] = true;
                    $serverNum = count($play_links) + 1;
                    $serverType = 'Streamtape Stream';
                    if (strpos($resolved, 'tnmr.org') !== false || strpos($resolved, 'luluvdo') !== false || strpos($resolved, 'lulustream') !== false || strpos($rlink, 'lulu') !== false) {
                        $serverType = 'Luluvdo Stream';
                    } else if (strpos($resolved, '.m3u8') !== false) {
                        $serverType = 'HLS/M3U8 Stream';
                    } else if (strpos($resolved, '.mp4') !== false) {
                        $serverType = 'MP4/MKV Direct Link';
                    }
                    $permUrl = (!empty($rlink) && strpos($rlink, 'http') === 0) ? $rlink : $resolved;
                    $play_links[] = [
                        'name' => "Server $serverNum",
                        'quality' => '720p',
                        'url' => $permUrl,
                        'resolved_url' => $resolved,
                        'type' => $serverType,
                    ];
                }
            }
        }
    }

    // Secondary href check for direct stream links
    preg_match_all('/href=[\'"]([^\'"]+)[\'"]/i', $html, $href_matches);
    foreach ($href_matches[1] as $href) {
        $href = trim($href);
        if (empty($href) || isset($seen_urls[$href])) continue;

        if (strpos($href, 'streamtape') !== false || strpos($href, 'tpead') !== false || strpos($href, 'luluvdo') !== false || strpos($href, 'lulustream') !== false || strpos($href, '.m3u8') !== false || strpos($href, '.mp4') !== false) {
            $resolved = resolve_server_stream_url($href);
            if (!empty($resolved) && !isset($seen_urls[$resolved])) {
                $seen_urls[$resolved] = true;
                $seen_urls[$href] = true;

                $serverNum = count($play_links) + 1;
                $serverType = 'Streamtape Stream';
                if (strpos($resolved, 'tnmr.org') !== false || strpos($resolved, 'luluvdo') !== false || strpos($resolved, 'lulustream') !== false || strpos($href, 'lulu') !== false) {
                    $serverType = 'Luluvdo Stream';
                } else if (strpos($resolved, '.m3u8') !== false) {
                    $serverType = 'HLS/M3U8 Stream';
                } else if (strpos($resolved, '.mp4') !== false) {
                    $serverType = 'MP4/MKV Direct Link';
                }

                $permUrl = (!empty($href) && strpos($href, 'http') === 0) ? $href : $resolved;
                $play_links[] = [
                    'name' => "Server $serverNum",
                    'quality' => '720p',
                    'url' => $permUrl,
                    'resolved_url' => $resolved,
                    'type' => $serverType,
                ];
            }
        }
    }

    $primary_stream = !empty($play_links) ? ($play_links[0]['resolved_url'] ?? $play_links[0]['url']) : '';
    $hosted_poster = !empty($poster) ? download_and_host_image($poster) : '';

    json_response(true, [
        'title' => $title,
        'description' => "Watch $title online in HD.",
        'poster' => $hosted_poster,
        'raw_poster' => $poster,
        'release_date' => $release_date,
        'stream_url' => $primary_stream,
        'play_links' => $play_links,
        'page_url' => $page_url,
    ], 'HDMove99 details extracted');
}

if ($action === 'resolve_server_stream') {
    $url = trim($input['url'] ?? $_POST['url'] ?? $_GET['url'] ?? '');
    if (empty($url)) json_response(false, [], 'URL required');

    $resolved = resolve_server_stream_url($url);
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
}

if ($action === 'search_uncutmasti_catalog') {
    $query = trim($input['query'] ?? $_POST['query'] ?? '');
    if (empty($query)) json_response(false, [], 'Query required');

    list($skymovies_domain, $hdmaal_domain, $uncutmasti_domain, $hdmove99_domain) = get_scraper_domains($pdo);
    $search_url = "$uncutmasti_domain/wp-json/wp/v2/posts?search=" . urlencode($query) . "&per_page=25&_embed=1";
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $search_url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT        => 15,
        CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    ]);
    $res = curl_exec($ch);
    curl_close($ch);

    $items = [];
    $data = @json_decode($res, true);
    if (is_array($data)) {
        foreach ($data as $post) {
            $poster = '';
            if (isset($post['_embedded']['wp:featuredmedia'][0]['source_url'])) {
                $poster = $post['_embedded']['wp:featuredmedia'][0]['source_url'];
            }
            $items[] = [
                'title' => html_entity_decode($post['title']['rendered'] ?? ''),
                'page_url' => $post['link'] ?? '',
                'poster' => $poster,
            ];
        }
    }

    json_response(true, ['items' => $items], 'UncutMasti catalog search completed');
}

if ($action === 'extract_uncutmasti_details') {
    $page_url = trim($input['page_url'] ?? '');
    if (empty($page_url)) json_response(false, [], 'Page URL required');

    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $page_url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT        => 15,
        CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    ]);
    $html = curl_exec($ch);
    curl_close($ch);

    if (!$html) {
        json_response(false, [], 'Failed to fetch UncutMasti page');
    }

    // 1. Extract Title
    $title = '';
    if (preg_match('/<title>(.*?)<\/title>/is', $html, $m)) {
        $title = trim(preg_replace('/ - UncutMasti|UncutMasti/i', '', html_entity_decode($m[1])));
    }

    // 2. Extract Video Stream URL & Poster from clean-tube-player base64 q param
    $mp4_url = '';
    $poster = '';

    if (preg_match('/player-x\.php\?q=([a-zA-Z0-9%=\+\/-]+)/i', $html, $m)) {
        $q_raw = $m[1];
        try {
            $q_decoded = base64_decode(urldecode($q_raw));
            $q_unquoted = urldecode($q_decoded);
            if (preg_match('/src=[\'"]([^\'"]+)[\'"]/i', $q_unquoted, $sm)) {
                $mp4_url = trim($sm[1]);
                if (strpos($mp4_url, ' ') !== false) {
                    $mp4_url = str_replace(' ', '%20', $mp4_url);
                }
            }
            if (preg_match('/poster=[\'"]([^\'"]+)[\'"]/i', $q_unquoted, $pm)) {
                $poster = $pm[1];
            }
        } catch (Exception $e) {}
    }

    // Fallback poster check
    if (empty($poster) && preg_match('/<meta property=[\'"]og:image[\'"] content=[\'"]([^\'"]+)[\'"]/i', $html, $pm)) {
        $poster = $pm[1];
    }

    $hosted_poster = !empty($poster) ? download_and_host_image($poster) : '';

    json_response(true, [
        'title' => $title,
        'description' => "Watch $title online.",
        'poster' => $hosted_poster,
        'raw_poster' => $poster,
        'stream_url' => $mp4_url,
        'page_url' => $page_url,
    ], 'UncutMasti details extracted');
}

if ($action === 'extract_skymovies_details') {
    list($skymovies_domain, $hdmaal_domain) = get_scraper_domains($pdo);
    $page_url = trim($input['page_url'] ?? '');
    if (empty($page_url)) json_response(false, [], 'Page URL required');

    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $page_url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT        => 15,
        CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    ]);
    $html = curl_exec($ch);
    curl_close($ch);

    if (!$html) {
        json_response(false, [], 'Failed to fetch Skymovies page');
    }

    // 1. Extract Title
    $title = '';
    if (preg_match('/<title>\s*(.*?)\s*<\/title>/is', $html, $m)) {
        $title = trim(preg_replace('/Full Movie Download|SkymoviesHD|Download/i', '', html_entity_decode($m[1])));
    }

    // 2. Extract Poster Image
    $poster = '';
    if (preg_match('/<div class=[\'"]movielist[\'"][^>]*>.*?<img src=[\'"]([^\'"]+)[\'"]/is', $html, $m)) {
        $poster = $m[1];
    } elseif (preg_match('/<img src=[\'"](https?:\/\/(?:blogger\.googleusercontent\.com|i\.imageflix\.cam|m\.media-amazon\.com)[^\'"]+)[\'"]/i', $html, $m)) {
        $poster = $m[1];
    }

    if (!empty($poster) && strpos($poster, 'http') === false) {
        $poster = $skymovies_domain . '/' . ltrim($poster, '/');
    }

    // 3. Extract Story / Description
    $desc = '';
    if (preg_match('/<b>Story\s*:\s*<\/b>\s*(.*?)<\/div>/is', $html, $m)) {
        $desc = trim(strip_tags(html_entity_decode($m[1])));
    }

    // 4. Extract All Video Stream Links (Streamtape & Luluvdo)
    $play_links = [];
    $seen_urls = [];
    $howblogs_links = [];

    preg_match_all('/href=[\'"]([^\'"]+)[\'"]/i', $html, $href_matches);
    foreach ($href_matches[1] as $href) {
        $href = trim($href);
        if (empty($href)) continue;

        if (strpos($href, 'streamtape') !== false || strpos($href, 'tpead') !== false || strpos($href, 'luluvdo') !== false || strpos($href, 'lulustream') !== false) {
            $clean_url = strtok($href, "\r\n\t ");
            if (!isset($seen_urls[$clean_url])) {
                $seen_urls[$clean_url] = true;
                $serverType = (strpos($clean_url, 'luluvdo') !== false || strpos($clean_url, 'lulustream') !== false) ? 'Luluvdo Stream' : 'Streamtape Stream';
                $play_links[] = [
                    'name' => ($serverType === 'Streamtape Stream') ? 'Server 1' : 'Server 2',
                    'quality' => '720p',
                    'url' => $clean_url,
                    'type' => $serverType
                ];
            }
        } elseif (strpos($href, 'howblogs') !== false || strpos($href, 'toolkitspro') !== false || strpos($href, 'uplinks') !== false) {
            $howblogs_links[] = $href;
        }
    }

    // Follow howblogs / toolkitspro / uplinks intermediary pages
    if (!empty($howblogs_links)) {
        foreach ($howblogs_links as $hurl) {
            if (isset($seen_urls[$hurl])) continue;
            $seen_urls[$hurl] = true;
            $ch = curl_init();
            curl_setopt_array($ch, [
                CURLOPT_URL            => $hurl,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_FOLLOWLOCATION => true,
                CURLOPT_TIMEOUT        => 10,
                CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            ]);
            $hhtml = curl_exec($ch);
            curl_close($ch);
            if ($hhtml) {
                preg_match_all('/href=[\'"]([^\'"]+)[\'"]/i', $hhtml, $shref_matches);
                foreach ($shref_matches[1] as $shref) {
                    $shref = trim($shref);
                    if (empty($shref)) continue;
                    $clean_shref = strtok($shref, "\r\n\t ");
                    if (strpos($clean_shref, 'streamtape') !== false || strpos($clean_shref, 'tpead') !== false || strpos($clean_shref, 'luluvdo') !== false || strpos($clean_shref, 'lulustream') !== false) {
                        if (!isset($seen_urls[$clean_shref])) {
                            $seen_urls[$clean_shref] = true;
                            $serverType = (strpos($clean_shref, 'luluvdo') !== false || strpos($clean_shref, 'lulustream') !== false) ? 'Luluvdo Stream' : 'Streamtape Stream';
                            $play_links[] = [
                                'name' => ($serverType === 'Streamtape Stream') ? 'Server 1' : 'Server 2',
                                'quality' => '720p',
                                'url' => $clean_shref,
                                'type' => $serverType
                            ];
                        }
                    }
                }
            }
        }
    }

    // Ensure Server 1 = Streamtape, Server 2 = Luluvdo ordering
    usort($play_links, function($a, $b) {
        if ($a['type'] === 'Streamtape Stream' && $b['type'] !== 'Streamtape Stream') return -1;
        if ($a['type'] !== 'Streamtape Stream' && $b['type'] === 'Streamtape Stream') return 1;
        return 0;
    });

    for ($i = 0; $i < count($play_links); $i++) {
        $play_links[$i]['name'] = "Server " . ($i + 1);
    }

    $primary_stream = !empty($play_links) ? $play_links[0]['url'] : '';
    $hosted_poster = !empty($poster) ? download_and_host_image($poster) : '';

    json_response(true, [
        'title' => $title,
        'description' => !empty($desc) ? $desc : "Watch $title online in HD.",
        'poster' => $hosted_poster,
        'raw_poster' => $poster,
        'stream_url' => $primary_stream,
        'play_links' => $play_links,
        'page_url' => $page_url,
    ], 'SkymoviesHD details extracted');
}

if ($action === 'extract_hdmaal_details') {
    list($skymovies_domain, $hdmaal_domain) = get_scraper_domains($pdo);
    $page_url = trim($input['page_url'] ?? '');
    if (empty($page_url)) json_response(false, [], 'HDMaal Page URL required');

    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $page_url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT        => 15,
        CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    ]);
    $html = curl_exec($ch);
    curl_close($ch);

    if (!$html) {
        json_response(false, [], 'Failed to fetch HDMaal page');
    }

    // Extract Title
    $title = '';
    if (preg_match('/<h1 class=[\'"]stitle[\'"][^>]*>Playing:\s*(.*?)<\/h1>/is', $html, $m)) {
        $title = trim(html_entity_decode($m[1]));
    } elseif (preg_match('/"name":\s*"([^"]+)"/i', $html, $m)) {
        $title = trim($m[1]);
    }

    // Extract Poster
    $poster = '';
    if (preg_match('/poster=[\'"]([^\'"]+)[\'"]/i', $html, $m)) {
        $poster = $m[1];
    } elseif (preg_match('/"thumbnailUrl":\s*"([^"]+)"/i', $html, $m)) {
        $poster = stripslashes($m[1]);
    } elseif (preg_match('/<meta\s+property=[\'"]og:image[\'"]\s+content=[\'"]([^\'"]+)[\'"]/i', $html, $m)) {
        $poster = $m[1];
    } elseif (preg_match('/<img[^>]+(?:src|data-src)=[\'"]([^\'"]+)[\'"]/i', $html, $m)) {
        $poster = $m[1];
    }

    // Extract All Stream Links (MP4 direct, Streamtape, Luluvdo)
    $play_links = [];
    $seen_urls = [];

    // Primary: Direct MP4 in <source>
    $mp4_url = '';
    if (preg_match('/<source\s+src=[\'"]([^\'"]+\.mp4)[\'"]/i', $html, $m)) {
        $mp4_url = $m[1];
    } elseif (preg_match('/"contentUrl":\s*"([^"]+\.mp4)"/i', $html, $m)) {
        $mp4_url = stripslashes($m[1]);
    }
    if (!empty($mp4_url) && !isset($seen_urls[$mp4_url])) {
        $seen_urls[$mp4_url] = true;
        $play_links[] = ['name' => 'Server 1', 'quality' => '720p', 'url' => $mp4_url, 'type' => 'MP4/MKV Direct Link'];
    }

    // Secondary: Streamtape / Luluvdo / other embedded links
    preg_match_all('/href=[\'"]([^\'"]+)[\'"]/i', $html, $href_matches);
    foreach ($href_matches[1] as $href) {
        $href = trim($href);
        if (empty($href) || isset($seen_urls[$href])) continue;
        if (strpos($href, 'streamtape') !== false || strpos($href, 'tpead') !== false || strpos($href, 'luluvdo') !== false || strpos($href, 'lulustream') !== false || strpos($href, 'uplinks24') !== false || strpos($href, 'toolkitspro') !== false) {
            $resolved = resolve_server_stream_url($href);
            if (!empty($resolved) && !isset($seen_urls[$resolved])) {
                $seen_urls[$resolved] = true;
                $seen_urls[$href] = true;
                $serverNum = count($play_links) + 1;
                $serverType = (strpos($resolved, 'tnmr.org') !== false || strpos($resolved, 'luluvdo') !== false) ? 'Luluvdo Stream' : 'Streamtape Stream';
                $play_links[] = ['name' => "Server $serverNum", 'quality' => '720p', 'url' => $resolved, 'type' => $serverType];
            }
        }
    }

    $primary_stream = !empty($play_links) ? $play_links[0]['url'] : '';
    $hosted_poster = !empty($poster) ? download_and_host_image($poster) : '';

    json_response(true, [
        'title' => $title,
        'description' => "Watch $title in full HD online.",
        'poster' => $hosted_poster,
        'raw_poster' => $poster,
        'stream_url' => $primary_stream,
        'play_links' => $play_links,
        'page_url' => $page_url,
    ], 'HDMaal details extracted');
}

if ($action === 'search_skymovies_posters') {
    list($skymovies_domain, $hdmaal_domain) = get_scraper_domains($pdo);
    $query = trim($input['query'] ?? $_POST['query'] ?? '');
    if (empty($query)) json_response(false, [], 'Query required');

    $search_url = "$skymovies_domain/search.php?search=" . urlencode($query) . "&cat=All";
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL            => $search_url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT        => 12,
        CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    ]);
    $html = curl_exec($ch);
    curl_close($ch);

    $images = [];
    if ($html) {
        // Find movie detail page links
        preg_match_all('/<div class=[\'"](?:L|Let|Fmvideo)[\'"][^>]*>.*?<a href=[\'"]([^\'"]+)[\'"]/is', $html, $matches);
        $page_links = array_slice($matches[1] ?? [], 0, 8);

        foreach ($page_links as $plink) {
            if (strpos($plink, 'http') === false) {
                $plink = $skymovies_domain . '/' . ltrim($plink, '/');
            }

            $ch2 = curl_init();
            curl_setopt_array($ch2, [
                CURLOPT_URL            => $plink,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_FOLLOWLOCATION => true,
                CURLOPT_TIMEOUT        => 8,
                CURLOPT_USERAGENT      => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            ]);
            $phtml = curl_exec($ch2);
            curl_close($ch2);

            if ($phtml) {
                if (preg_match('/<div class=[\'"]movielist[\'"][^>]*>.*?<img src=[\'"]([^\'"]+)[\'"]/is', $phtml, $pm)) {
                    $img = $pm[1];
                    if (strpos($img, 'http') === false) $img = $skymovies_domain . '/' . ltrim($img, '/');
                    if (!in_array($img, $images)) $images[] = $img;
                } elseif (preg_match('/<img src=[\'"](https?:\/\/(?:blogger\.googleusercontent\.com|i\.imageflix\.cam|m\.media-amazon\.com)[^\'"]+)[\'"]/i', $phtml, $pm)) {
                    $img = $pm[1];
                    if (!in_array($img, $images)) $images[] = $img;
                }
            }
        }
    }

    json_response(true, ['images' => $images], 'Skymovies posters searched');
}

if ($action === 'list_reports' || $action === 'get_reports') {
    try {
        $stmt = $pdo->query("SELECT r.*, u.name as user_name, u.email as user_email FROM user_reports r LEFT JOIN users u ON r.user_id = u.id ORDER BY r.id DESC");
        $reports = $stmt->fetchAll(PDO_FETCH_ASSOC) ?: [];
        json_response(true, ['reports' => $reports], 'Reports fetched');
    } catch (Exception $e) {
        json_response(true, ['reports' => []], 'Reports fetched');
    }
}

if ($action === 'delete_report') {
    $report_id = intval($input['report_id'] ?? $_POST['report_id'] ?? 0);
    if ($report_id <= 0) json_response(false, [], 'Report ID required');
    try {
        $stmt = $pdo->prepare("DELETE FROM user_reports WHERE id = ?");
        $stmt->execute([$report_id]);
        json_response(true, [], 'Report deleted');
    } catch (Exception $e) {
        json_response(false, [], $e->getMessage());
    }
}

if ($action === 'resolve_report') {
    $report_id = intval($input['report_id'] ?? $_POST['report_id'] ?? 0);
    $status = intval($input['status'] ?? $_POST['status'] ?? 1);
    $admin_reply = trim($input['admin_reply'] ?? $_POST['admin_reply'] ?? '');
    if ($report_id <= 0) json_response(false, [], 'Report ID required');
    try {
        $stmt = $pdo->prepare("UPDATE user_reports SET status = ?, admin_reply = ? WHERE id = ?");
        $stmt->execute([$status, $admin_reply, $report_id]);
        json_response(true, [], 'Report resolved');
    } catch (Exception $e) {
        json_response(false, [], $e->getMessage());
    }
}

// Fallback for unknown or missing action
json_response(false, [], 'Unknown or unhandled action: ' . $action);


