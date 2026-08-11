<?php
require_once "config.php";

$action = $_GET['action'] ?? $_POST['action'] ?? '';

function is_streamtape_link($url) {
    if (empty($url)) return false;
    $host = strtolower(parse_url($url, PHP_URL_HOST) ?: $url);
    $patterns = [
        'streamtape', 'tapepops', 'advtpe', 'streamtp', 's-tpe', 'tpe.com',
        'streamta', 'tapecom', 'tape.gg', 'stp.gg', 'tapemax', 'tapehost',
        'streamtape.xyz', 'streamtape.net', 'streamtape.to',
    ];
    foreach ($patterns as $p) {
        if (strpos($host, $p) !== false) return true;
    }
    return false;
}

// 1. Keep-Alive Service: Pings all active Streamtape links to reset 60-day inactivity timer
if ($action === 'keep_alive') {
    $stmt = $pdo->query("SELECT id, url FROM movie_play_links WHERE status = 1");
    $movie_links = $stmt->fetchAll();

    $stmt = $pdo->query("SELECT id, url FROM episode_play_links WHERE status = 1");
    $ep_links = $stmt->fetchAll();

    $pinged = 0;
    foreach (array_merge($movie_links, $ep_links) as $link) {
        if (!is_streamtape_link($link['url'])) continue;
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $link['url']);
        curl_setopt($ch, CURLOPT_NOBODY, true); // HEAD request
        curl_setopt($ch, CURLOPT_TIMEOUT, 5);
        curl_setopt($ch, CURLOPT_USERAGENT, "Mozilla/5.0");
        curl_exec($ch);
        curl_close($ch);
        $pinged++;
    }

    json_response(true, ["pinged_count" => $pinged], "Streamtape Keep-Alive ping cycle completed");
}

// 2. Dead Link Health Checker: Scans play links for dead/removed status
if ($action === 'check_dead_links') {
    $disabled_movies = 0;
    $disabled_episodes = 0;

    // Scan movie play links
    $stmt = $pdo->query("SELECT id, movie_id, url FROM movie_play_links WHERE status = 1 LIMIT 30");
    $links = $stmt->fetchAll();

    foreach ($links as $l) {
        $is_dead = false;

        if (is_streamtape_link($l['url'])) {
            // Check the actual host of the link first, then fall back to mirrors.
            // Do NOT follow redirects — a 404 redirected to homepage would look like 200.
            $vid = basename(parse_url($l['url'], PHP_URL_PATH) ?: $l['url']);
            $ownHost = strtolower(parse_url($l['url'], PHP_URL_HOST) ?: 'advtpe.com');
            $mirrors = [$ownHost, 'streamtape.com', 'advtpe.com', 'tapepops.com', 'tpead.net'];
            $mirrors = array_unique($mirrors);
            foreach ($mirrors as $mirror) {
                $embedUrl = "https://" . $mirror . "/e/" . $vid;
                $ch = curl_init($embedUrl);
                curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
                curl_setopt($ch, CURLOPT_TIMEOUT, 6);
                curl_setopt($ch, CURLOPT_USERAGENT, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36");
                curl_setopt($ch, CURLOPT_FOLLOWLOCATION, false); // Keep true HTTP status
                $res = curl_exec($ch);
                $code = intval(curl_getinfo($ch, CURLINFO_HTTP_CODE));
                curl_close($ch);
                if ($code === 404 || $code === 410) { $is_dead = true; break; }
                if ($code >= 200 && $code < 300 && $res) {
                    $hasMarker = strpos($res, 'robotlink') !== false
                        || strpos($res, 'ideoolink') !== false
                        || strpos($res, 'botlink') !== false
                        || strpos($res, 'get_video') !== false;
                    $isDead = preg_match('/video not found|file not found|video deleted|file deleted|has been removed|removed by uploader|not available anymore|this video has been removed|video is no longer available|deleted by the creator/i', $res);
                    if ($isDead) { $is_dead = true; break; }
                    if ($hasMarker) { $is_dead = false; break; } // Confirmed live
                }
                // 403/429/timeout/other = uncertain, try next mirror
            }
        }

        if ($is_dead) {
            $pdo->prepare("UPDATE movie_play_links SET status = 0 WHERE id = ?")->execute([$l['id']]);
            $disabled_movies++;
        }
    }

    json_response(true, ["disabled_movies" => $disabled_movies, "disabled_episodes" => $disabled_episodes], "Health check scan completed");
}

// 3. Fetch Dead Links Queue for Admin Panel
if ($action === 'get_dead_links') {
    $stmt = $pdo->query("
        SELECT pl.id as link_id, pl.url, m.id as movie_id, m.name as title, m.poster, 'movie' as type
        FROM movie_play_links pl
        JOIN movies m ON pl.movie_id = m.id
        WHERE pl.status = 0
        UNION ALL
        SELECT epl.id as link_id, epl.url, s.id as movie_id, CONCAT(s.name, ' - Ep ', ep.episoade_order) as title, ep.episoade_image as poster, 'episode' as type
        FROM episode_play_links epl
        JOIN web_series_episoade ep ON epl.episode_id = ep.id
        JOIN web_series_seasons se ON ep.season_id = se.id
        JOIN web_series s ON se.web_series_id = s.id
        WHERE epl.status = 0
    ");
    $dead_links = $stmt->fetchAll();

    json_response(true, ["dead_links" => $dead_links], "Dead links retrieved");
}

// 4. Replace Dead Link & Re-enable Content
if ($action === 'replace_link') {
    $input = json_decode(file_get_contents('php://input'), true) ?? $_POST;
    $link_id = intval($input['link_id'] ?? 0);
    $new_url = trim($input['new_url'] ?? '');
    $type = $input['type'] ?? 'movie';

    if ($link_id <= 0 || empty($new_url)) {
        json_response(false, [], "Link ID and new URL required");
    }

    if ($type === 'movie') {
        $stmt = $pdo->prepare("UPDATE movie_play_links SET url = ?, status = 1 WHERE id = ?");
        $stmt->execute([$new_url, $link_id]);
    } else {
        $stmt = $pdo->prepare("UPDATE episode_play_links SET url = ?, status = 1 WHERE id = ?");
        $stmt->execute([$new_url, $link_id]);
    }

    json_response(true, [], "Link replaced and content re-enabled successfully");
}

json_response(false, [], "Invalid action");
?>
