<?php
header('Content-Type: application/json; charset=utf-8');

require_once 'config.php';

function safeQuery($pdo, $sql, $params = []) {
    try {
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        return [];
    }
}

// 0. Automatic Monday Weekly Views Reset
function check_and_do_weekly_reset($pdo) {
    try {
        $hasM = $pdo->query("SHOW COLUMNS FROM movies LIKE 'weekly_views'")->fetch();
        if (!$hasM) $pdo->exec("ALTER TABLE movies ADD COLUMN weekly_views INT NOT NULL DEFAULT 0");

        $hasS = $pdo->query("SHOW COLUMNS FROM web_series LIKE 'weekly_views'")->fetch();
        if (!$hasS) $pdo->exec("ALTER TABLE web_series ADD COLUMN weekly_views INT NOT NULL DEFAULT 0");

        // Monday of current week (e.g., '2026-08-17')
        $currentMonday = date('Y-m-d', strtotime('monday this week'));
        $stmt = $pdo->prepare("SELECT svalue FROM app_settings WHERE skey = 'last_weekly_reset_monday'");
        $stmt->execute();
        $lastReset = $stmt->fetchColumn();

        if (!$lastReset || $lastReset !== $currentMonday) {
            $pdo->exec("UPDATE movies SET weekly_views = 0");
            $pdo->exec("UPDATE web_series SET weekly_views = 0");
            $pdo->prepare("REPLACE INTO app_settings (skey, svalue) VALUES ('last_weekly_reset_monday', ?)")->execute([$currentMonday]);
        }
    } catch (Exception $e) {}
}

check_and_do_weekly_reset($pdo);

// 1. Hero Slider (Web Series with valid Banners)
$hero_slider = safeQuery($pdo, "
    SELECT s.id, s.name, s.poster, s.banner, s.release_date, 'series' AS item_type,
           COALESCE((SELECT UPPER(g.name) FROM genres g WHERE FIND_IN_SET(g.id, s.genres) LIMIT 1), 'RED EXCLUSIVE') AS ott_name
    FROM web_series s
    WHERE s.status = 1 AND s.banner IS NOT NULL AND s.banner != ''
    ORDER BY s.id DESC LIMIT 10
");

// 2. Cast & Actress Networks
$ott_networks = safeQuery($pdo, "
    SELECT id, name, logo FROM networks
    WHERE status = 1
    ORDER BY networks_order ASC, id ASC
");

// 3. OTT Genres for Home Screen (Only active status = 1)
$ott_genres = safeQuery($pdo, "
    SELECT id, name, icon, 0 AS is_hidden FROM genres
    WHERE status = 1
    ORDER BY sort_order ASC, id ASC
");

// 3b. All OTT Genres for See All Screen (All 110 genres with status=0 marked as is_hidden=1)
$all_ott_genres = safeQuery($pdo, "
    SELECT id, name, icon, CASE WHEN status = 0 THEN 1 ELSE 0 END AS is_hidden FROM genres
    ORDER BY sort_order ASC, id ASC
");

// 4. Newly Added (5 Movies + 5 Series interleaved)
$newly_added_movies = safeQuery($pdo, "
    SELECT m.id, m.name, m.poster, m.banner, m.release_date, 'movie' AS item_type,
           COALESCE((SELECT UPPER(g.name) FROM genres g WHERE FIND_IN_SET(g.id, m.genres) LIMIT 1), 'RED EXCLUSIVE') AS ott_name
    FROM movies m WHERE m.status = 1
    ORDER BY m.id DESC LIMIT 5
");
$newly_added_series = safeQuery($pdo, "
    SELECT s.id, s.name, s.poster, s.banner, s.release_date, 'series' AS item_type,
           COALESCE((SELECT UPPER(g.name) FROM genres g WHERE FIND_IN_SET(g.id, s.genres) LIMIT 1), 'RED EXCLUSIVE') AS ott_name
    FROM web_series s WHERE s.status = 1
    ORDER BY s.id DESC LIMIT 5
");
$newly_added = array_merge($newly_added_movies, $newly_added_series);
usort($newly_added, function($a, $b) {
    return ($b['id'] ?? 0) - ($a['id'] ?? 0);
});
$newly_added = array_slice($newly_added, 0, 10);

// 5. Continue Playing
$continue_playing = [];

// 6. Top 10 Popular (Overall Top Views)
$top_10 = safeQuery($pdo, "
    SELECT s.id, s.name, s.poster, s.banner, '8.8' AS rating,
           COALESCE((SELECT UPPER(g.name) FROM genres g WHERE FIND_IN_SET(g.id, s.genres) LIMIT 1), 'RED EXCLUSIVE') AS ott_name, 'series' AS item_type
    FROM web_series s
    WHERE s.status = 1
    ORDER BY s.views DESC, s.id DESC LIMIT 10
");

// 7. Weekly Trending (Aligned identically with Admin Panel: ordered by weekly_views DESC, views DESC)
$w_movies = safeQuery($pdo, "
    SELECT m.id, m.name, m.poster, m.banner, '8.6' AS rating,
           IFNULL(m.views, 0) as views, IFNULL(m.weekly_views, 0) as weekly_views,
           COALESCE((SELECT UPPER(g.name) FROM genres g WHERE FIND_IN_SET(g.id, m.genres) LIMIT 1), 'RED EXCLUSIVE') AS ott_name, 'movie' AS item_type
    FROM movies m
    WHERE m.status = 1
    ORDER BY m.weekly_views DESC, m.views DESC, m.id DESC LIMIT 15
");
$w_series = safeQuery($pdo, "
    SELECT s.id, s.name, s.poster, s.banner, '8.6' AS rating,
           IFNULL(s.views, 0) as views, IFNULL(s.weekly_views, 0) as weekly_views,
           COALESCE((SELECT UPPER(g.name) FROM genres g WHERE FIND_IN_SET(g.id, s.genres) LIMIT 1), 'RED EXCLUSIVE') AS ott_name, 'series' AS item_type
    FROM web_series s
    WHERE s.status = 1
    ORDER BY s.weekly_views DESC, s.views DESC, s.id DESC LIMIT 15
");
$weekly_trending = array_merge($w_movies, $w_series);
usort($weekly_trending, function($a, $b) {
    if (($b['weekly_views'] ?? 0) != ($a['weekly_views'] ?? 0)) {
        return ($b['weekly_views'] ?? 0) - ($a['weekly_views'] ?? 0);
    }
    return ($b['views'] ?? 0) - ($a['views'] ?? 0);
});
$weekly_trending = array_slice($weekly_trending, 0, 10);

// 8. Web Series Only For You (Randomized on every refresh)
$popular_series = safeQuery($pdo, "
    SELECT s.id, s.name, s.poster, s.banner, '8.7' AS rating,
           COALESCE((SELECT UPPER(g.name) FROM genres g WHERE FIND_IN_SET(g.id, s.genres) LIMIT 1), 'RED EXCLUSIVE') AS ott_name, 'series' AS item_type
    FROM web_series s
    WHERE s.status = 1
    ORDER BY RAND() LIMIT 15
");

// 9. Movies Only For You (Randomized on every refresh)
$popular_movies = safeQuery($pdo, "
    SELECT m.id, m.name, m.poster, m.banner, '8.5' AS rating,
           COALESCE((SELECT UPPER(g.name) FROM genres g WHERE FIND_IN_SET(g.id, m.genres) LIMIT 1), 'RED EXCLUSIVE') AS ott_name, 'movie' AS item_type
    FROM movies m
    WHERE m.status = 1
    ORDER BY RAND() LIMIT 15
");

// 10. Dynamic OTT Sections (For each visible OTT on home screen, mixed & randomized content)
$ott_sections = [];
$active_ott_genres = safeQuery($pdo, "
    SELECT id, name, icon FROM genres
    WHERE status = 1
    ORDER BY sort_order ASC, id ASC
");

foreach ($active_ott_genres as $og) {
    $gId = intval($og['id']);
    $rawName = trim($og['name']);
    $gName = strtoupper($rawName);
    $gLike = '%' . $rawName . '%';

    $g_movies = safeQuery($pdo, "
        SELECT m.id, m.name, m.poster, m.banner, 'movie' AS item_type, ? AS ott_name, m.release_date
        FROM movies m
        WHERE m.status = 1 AND (
            m.genres LIKE ?
            OR FIND_IN_SET(?, m.genres)
            OR EXISTS (SELECT 1 FROM content_network_log cnl WHERE cnl.content_id = m.id AND cnl.content_type = 1 AND cnl.network_id = ?)
        )
        ORDER BY RAND() LIMIT 12
    ", [$gName, $gLike, $gId, $gId]);

    $g_series = safeQuery($pdo, "
        SELECT s.id, s.name, s.poster, s.banner, 'series' AS item_type, ? AS ott_name, s.release_date
        FROM web_series s
        WHERE s.status = 1 AND (
            s.genres LIKE ?
            OR FIND_IN_SET(?, s.genres)
            OR EXISTS (SELECT 1 FROM content_network_log cnl WHERE cnl.content_id = s.id AND cnl.content_type = 2 AND cnl.network_id = ?)
        )
        ORDER BY RAND() LIMIT 12
    ", [$gName, $gLike, $gId, $gId]);

    $mixed = array_merge($g_movies, $g_series);
    if (!empty($mixed)) {
        shuffle($mixed);
        $ott_sections[] = [
            'network_id' => $gId,
            'title' => $gName,
            'logo' => $og['icon'] ?? '',
            'items' => array_slice($mixed, 0, 15)
        ];
    }
}

// 11. Active Push Campaign & Announcement Engine
$active_campaign = null;
try {
    $stmt = $pdo->query("SELECT * FROM push_campaigns WHERE status = 1 ORDER BY id DESC LIMIT 1");
    $c = $stmt->fetch();
    if ($c) {
        $rawItems = json_decode($c['items'], true) ?: [];
        $detailedItems = [];
        foreach ($rawItems as $itm) {
            $itemId = intval($itm['id'] ?? 0);
            $itemType = $itm['type'] ?? 'movie';
            if ($itemId <= 0) continue;
            if ($itemType === 'movie') {
                $rowStmt = $pdo->prepare("SELECT m.id, m.name, m.poster, m.banner, m.release_date, 'movie' as item_type, 'RED EXCLUSIVE' as ott_name FROM movies m WHERE m.id = ?");
            } else {
                $rowStmt = $pdo->prepare("SELECT s.id, s.name, s.poster, s.banner, s.release_date, 'series' as item_type, 'RED EXCLUSIVE' as ott_name FROM web_series s WHERE s.id = ?");
            }
            $rowStmt->execute([$itemId]);
            $row = $rowStmt->fetch(PDO::FETCH_ASSOC);
            if ($row) {
                $detailedItems[] = $row;
            }
        }
        if (!empty($detailedItems)) {
            $active_campaign = [
                "id" => intval($c['id']),
                "title" => $c['title'],
                "expiry_at" => $c['expiry_at'],
                "items" => $detailedItems
            ];
        }
    }
} catch (Exception $e) {}

$active_announcement = null;
try {
    $stmt = $pdo->query("SELECT * FROM announcements WHERE status = 1 ORDER BY id DESC LIMIT 1");
    $ann = $stmt->fetch(PDO::FETCH_ASSOC);
    if ($ann) {
        $active_announcement = [
            "id" => intval($ann['id']),
            "title" => $ann['title'],
            "message" => $ann['message'],
            "image_url" => $ann['image_url'],
            "expiry_at" => $ann['expiry_at']
        ];
    }
} catch (Exception $e) {}

// Return combined JSON
echo json_encode([
    'status' => 'success',
    'hero_slider' => $hero_slider,
    'ott_networks' => $ott_networks,
    'ott_genres' => $ott_genres,
    'all_ott_genres' => $all_ott_genres,
    'newly_added' => $newly_added,
    'continue_playing' => $continue_playing,
    'top_10' => $top_10,
    'weekly_trending' => $weekly_trending,
    'popular_series' => $popular_series,
    'popular_movies' => $popular_movies,
    'ott_sections' => $ott_sections,
    'push_campaign' => $active_campaign,
    'announcement' => $active_announcement,
    'telegram_link' => 'https://t.me/red_ott_channel'
]);