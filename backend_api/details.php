<?php
require_once "config.php";

$id = intval($_GET['id'] ?? 0);
$type = $_GET['type'] ?? 'movie';

if ($id <= 0) {
    json_response(false, [], "Invalid content ID");
}

if ($type === 'movie') {
    // Real-time live view counter increment
    try {
        $pdo->prepare("UPDATE movies SET views = IFNULL(views, 0) + 1, weekly_views = IFNULL(weekly_views, 0) + 1 WHERE id = ?")->execute([$id]);
    } catch (Exception $e) {}

    $stmt = $pdo->prepare("SELECT * FROM movies WHERE id = ?");
    $stmt->execute([$id]);
    $details = $stmt->fetch();

    if (!$details) {
        json_response(false, [], "Movie not found");
    }

    // Reject parked content: needs >=1 active link AND zero dead links.
    try {
        $chk = $pdo->prepare("SELECT
            (SELECT COUNT(*) FROM movie_play_links WHERE movie_id = ? AND status = 1) AS active_links,
            (SELECT COUNT(*) FROM movie_play_links WHERE movie_id = ? AND status = 0) AS dead_links");
        $chk->execute([$id, $id]);
        $linksStat = $chk->fetch();
        if (intval($linksStat['active_links']) == 0) {
            json_response(false, [], "Movie not available");
        }
    } catch (Exception $e) {}

    // Custom tag ("A"/"Mal"/"Tam"/...) from custom_tags + custom_tag_log
    $details['custom_tag'] = 'HD';
    try {
        $stmt = $pdo->prepare("SELECT ct.name, ct.background_color, ct.text_color FROM custom_tag_log ctl JOIN custom_tags ct ON ct.id = ctl.custom_tags_id WHERE ctl.content_id = ? AND ctl.content_type = 1 ORDER BY ctl.id DESC LIMIT 1");
        $stmt->execute([$id]);
        $tag = $stmt->fetch();
        if ($tag && !empty($tag['name'])) {
            $details['custom_tag'] = $tag['name'];
            $details['custom_tag_bg'] = $tag['background_color'] ?? '';
            $details['custom_tag_color'] = $tag['text_color'] ?? '';
        }
    } catch (Exception $e) {}

    $playLinks = [];
    $stmt = $pdo->prepare("SELECT * FROM movie_play_links WHERE movie_id = ? AND status = 1 ORDER BY link_order ASC");
    $stmt->execute([$id]);
    $playLinks = $stmt->fetchAll();

    $downloadLinks = [];
    $stmt = $pdo->prepare("SELECT * FROM movie_download_links WHERE movie_id = ? AND status = 1 ORDER BY link_order ASC");
    $stmt->execute([$id]);
    $downloadLinks = $stmt->fetchAll();

    $castMembers = [];
    try {
        $stmt = $pdo->prepare("SELECT n.name, n.logo AS profile_url FROM content_network_log cnl JOIN networks n ON n.id = cnl.network_id WHERE cnl.content_id = ? AND cnl.content_type = 1 AND n.status = 1 ORDER BY n.networks_order ASC");
        $stmt->execute([$id]);
        $castMembers = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        $castMembers = [];
    }

    $ottName = $details['ott_name'] ?? '';
    $ottLogo = $details['ott_logo'] ?? '';
    $ottId = $details['ott_id'] ?? null;

    $genres = [];
    $genreStr = $details['genres'] ?? '';
    if (!empty($genreStr)) {
        $genres = array_filter(array_map('trim', explode(',', $genreStr)));
    }

    // Related content: same genre / OTT (fallback to latest)
    $related = [];
    try {
        if (!empty($genres)) {
            $where = [];
            $params = [$id];
            foreach ($genres as $g) {
                $where[] = "genres LIKE ?";
                $params[] = '%' . $g . '%';
            }
            $stmt = $pdo->prepare("SELECT * FROM movies WHERE status = 1 AND id != ? AND (" . implode(" OR ", $where) . ") ORDER BY id DESC LIMIT 12");
            $stmt->execute($params);
            $related = $stmt->fetchAll();
        }
        if (empty($related)) {
            $stmt = $pdo->prepare("SELECT * FROM movies WHERE status = 1 AND id != ? ORDER BY id DESC LIMIT 12");
            $stmt->execute([$id]);
            $related = $stmt->fetchAll();
        }
    } catch (Exception $e) {
        $related = [];
    }

    json_response(true, [
        "content" => $details,
        "play_links" => $playLinks,
        "download_links" => $downloadLinks,
        "cast_members" => $castMembers,
        "genres" => $genres,
        "ott_name" => $ottName,
        "ott_logo" => $ottLogo,
        "ott_id" => $ottId,
        "related" => $related,
    ], "Movie details fetched");
} else if ($type === 'series') {
    // Real-time live view counter increment
    try {
        $pdo->prepare("UPDATE web_series SET views = IFNULL(views, 0) + 1, weekly_views = IFNULL(weekly_views, 0) + 1 WHERE id = ?")->execute([$id]);
    } catch (Exception $e) {}

    $stmt = $pdo->prepare("SELECT * FROM web_series WHERE id = ?");
    $stmt->execute([$id]);
    $details = $stmt->fetch();

    if (!$details) {
        json_response(false, [], "Web series not found");
    }

    // Reject parked series: needs >=1 active episode link AND zero dead ones.
    try {
        $chk = $pdo->prepare("SELECT
            (SELECT COUNT(*) FROM web_series_episoade ep JOIN episode_play_links epl ON epl.episode_id = ep.id AND epl.status = 1 WHERE ep.season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?)) AS active_links,
            (SELECT COUNT(*) FROM web_series_episoade dep JOIN episode_play_links depl ON depl.episode_id = dep.id AND depl.status = 0 WHERE dep.season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = ?)) AS dead_links");
        $chk->execute([$id, $id]);
        $linksStat = $chk->fetch();
        if (intval($linksStat['active_links']) == 0) {
            json_response(false, [], "Series not available");
        }
    } catch (Exception $e) {}

    // Custom tag ("A"/"Mal"/"Tam"/...) from custom_tags + custom_tag_log (content_type 2)
    $details['custom_tag'] = 'HD';
    try {
        $stmt = $pdo->prepare("SELECT ct.name, ct.background_color, ct.text_color FROM custom_tag_log ctl JOIN custom_tags ct ON ct.id = ctl.custom_tags_id WHERE ctl.content_id = ? AND ctl.content_type = 2 ORDER BY ctl.id DESC LIMIT 1");
        $stmt->execute([$id]);
        $tag = $stmt->fetch();
        if ($tag && !empty($tag['name'])) {
            $details['custom_tag'] = $tag['name'];
            $details['custom_tag_bg'] = $tag['background_color'] ?? '';
            $details['custom_tag_color'] = $tag['text_color'] ?? '';
        }
    } catch (Exception $e) {}

    $seasons = [];
    $stmt = $pdo->prepare("SELECT * FROM web_series_seasons WHERE web_series_id = ? AND status = 1 ORDER BY season_order ASC");
    $stmt->execute([$id]);
    $seasons = $stmt->fetchAll();

    // Bulk-load episodes + links (avoids slow N+1 queries)
    $seasonIds = array_column($seasons, 'id');
    $episodes = [];
    if (!empty($seasonIds)) {
        $sin = implode(',', array_map('intval', $seasonIds));
        $episodes = $pdo->query("SELECT * FROM web_series_episoade WHERE season_id IN ($sin) AND status = 1 ORDER BY season_id ASC, episoade_order ASC")->fetchAll();
    }
    $epIds = array_column($episodes, 'id');
    $playLinks = [];
    $dlLinks = [];
    if (!empty($epIds)) {
        $ein = implode(',', array_map('intval', $epIds));
        $playRows = $pdo->query("SELECT * FROM episode_play_links WHERE episode_id IN ($ein) AND status = 1 ORDER BY episode_id ASC, link_order ASC")->fetchAll();
        foreach ($playRows as $r) { $playLinks[$r['episode_id']][] = $r; }
        $dlRows = $pdo->query("SELECT * FROM episode_download_links WHERE episode_id IN ($ein) AND status = 1 ORDER BY episode_id ASC, link_order ASC")->fetchAll();
        foreach ($dlRows as $r) { $dlLinks[$r['episode_id']][] = $r; }
    }
    $epBySeason = [];
    foreach ($episodes as $e) {
        $e['play_links'] = $playLinks[$e['id']] ?? [];
        $e['download_links'] = $dlLinks[$e['id']] ?? [];
        $epBySeason[$e['season_id']][] = $e;
    }
    foreach ($seasons as &$season) {
        $season['episodes'] = $epBySeason[$season['id']] ?? [];
    }

    $castMembers = [];
    try {
        $stmt = $pdo->prepare("SELECT n.name, n.logo AS profile_url FROM content_network_log cnl JOIN networks n ON n.id = cnl.network_id WHERE cnl.content_id = ? AND cnl.content_type = 2 AND n.status = 1 ORDER BY n.networks_order ASC");
        $stmt->execute([$id]);
        $castMembers = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        $castMembers = [];
    }

    $ottName = $details['ott_name'] ?? '';
    $ottLogo = $details['ott_logo'] ?? '';
    $ottId = $details['ott_id'] ?? null;

    $genres = [];
    $genreStr = $details['genres'] ?? '';
    if (!empty($genreStr)) {
        $genres = array_filter(array_map('trim', explode(',', $genreStr)));
    }

    // Related content: same genre / OTT (fallback to latest)
    $related = [];
    try {
        if (!empty($genres)) {
            $where = [];
            $params = [$id];
            foreach ($genres as $g) {
                $where[] = "genres LIKE ?";
                $params[] = '%' . $g . '%';
            }
            $stmt = $pdo->prepare("SELECT * FROM web_series WHERE status = 1 AND id != ? AND (" . implode(" OR ", $where) . ") ORDER BY id DESC LIMIT 12");
            $stmt->execute($params);
            $related = $stmt->fetchAll();
        }
        if (empty($related)) {
            $stmt = $pdo->prepare("SELECT * FROM web_series WHERE status = 1 AND id != ? ORDER BY id DESC LIMIT 12");
            $stmt->execute([$id]);
            $related = $stmt->fetchAll();
        }
    } catch (Exception $e) {
        $related = [];
    }

    json_response(true, [
        "content" => $details,
        "seasons" => $seasons,
        "cast_members" => $castMembers,
        "genres" => $genres,
        "ott_name" => $ottName,
        "ott_logo" => $ottLogo,
        "ott_id" => $ottId,
        "related" => $related,
    ], "Web series details fetched");
}

json_response(false, [], "Invalid type");
?>
