<?php
require_once "config.php";

$type = $_GET['type'] ?? 'all'; // all, movie, series
$search = trim($_GET['search'] ?? '');
$sort = $_GET['sort'] ?? 'latest'; // latest, name
$genre = trim($_GET['genre'] ?? '');
$network_id = intval($_GET['network_id'] ?? 0);
$limit = 9999;

$order_movie = "ORDER BY m.release_date DESC, m.id DESC";
$order_series = "ORDER BY s.release_date DESC, s.id DESC";
if ($sort === 'name') {
    $order_movie = "ORDER BY m.name ASC";
    $order_series = "ORDER BY s.name ASC";
}

// Build base rows WITHOUT tag subqueries (robust: never throws).
// Tags are fetched separately by content id and merged in PHP.
function base_select($alias, $search, $genre, $network_id, $contentType) {
    $where = ["$alias.status = 1"];
    $params = [];
    if (!empty($search)) {
        $where[] = "($alias.name LIKE ? OR EXISTS (SELECT 1 FROM content_network_log cnl JOIN networks n ON n.id = cnl.network_id WHERE n.name LIKE ? AND cnl.content_id = " . $alias . ".id AND cnl.content_type = " . $contentType . "))";
        $params[] = "%$search%";
        $params[] = "%$search%";
    }
    // OTT filter: network_id (via content_network_log) is authoritative.
    // Don't ALSO apply the genre-name LIKE — OTT names are usually not in the
    // genres column and would wrongly empty the results.
    if ($network_id > 0) {
        $where[] = "EXISTS (SELECT 1 FROM content_network_log cnl WHERE cnl.content_id = " . $alias . ".id AND cnl.content_type = " . $contentType . " AND cnl.network_id = ?)";
        $params[] = $network_id;
    } else if (!empty($genre)) {
        $where[] = "$alias.genres LIKE ?";
        $params[] = "%$genre%";
    }
    // Only hide content with NO active links at all.
    if ($contentType == 1) {
        $where[] = "EXISTS (SELECT 1 FROM movie_play_links a WHERE a.movie_id = $alias.id AND a.status = 1)";
    } else {
        $where[] = "EXISTS (SELECT 1 FROM web_series_episoade ep JOIN episode_play_links epl ON epl.episode_id = ep.id AND epl.status = 1 WHERE ep.season_id IN (SELECT id FROM web_series_seasons WHERE web_series_id = $alias.id))";
    }
    return [implode(" AND ", $where), $params];
}

$items = [];
try {
    if ($type === 'movie' || $type === 'all') {
        list($w, $p) = base_select('m', $search, $genre, $network_id, 1);
        $stmt = $pdo->prepare("SELECT m.id, m.name, m.poster, m.banner, '8.5' AS rating, m.release_date, 'movie' AS item_type FROM movies AS m WHERE $w $order_movie LIMIT $limit");
        $stmt->execute($p);
        foreach ($stmt->fetchAll() as $row) {
            $row['custom_tag'] = 'HD';
            $row['custom_tag_bg'] = '#E50914';
            $row['custom_tag_color'] = '#FFFFFF';
            $items[] = $row;
        }
    }
    if ($type === 'series' || $type === 'all') {
        list($w, $p) = base_select('s', $search, $genre, $network_id, 2);
        $stmt = $pdo->prepare("SELECT s.id, s.name, s.poster, s.banner, '8.5' AS rating, s.release_date, 'series' AS item_type FROM web_series AS s WHERE $w $order_series LIMIT $limit");
        $stmt->execute($p);
        foreach ($stmt->fetchAll() as $row) {
            $row['custom_tag'] = 'HD';
            $row['custom_tag_bg'] = '#E50914';
            $row['custom_tag_color'] = '#FFFFFF';
            $items[] = $row;
        }
    }
} catch (Exception $e) {
    $items = [];
}

// Fetch tags by content id in ONE query (never breaks content listing)
if (!empty($items)) {
    $movieIds = [];
    $seriesIds = [];
    foreach ($items as $it) {
        $id = intval($it['id']);
        if ($it['item_type'] === 'movie') $movieIds[] = $id;
        else $seriesIds[] = $id;
    }
    $tagMap = []; // key: "m:123" or "s:456" => [name, bg, color]
    try {
        $clauses = [];
        $params = [];
        if (!empty($movieIds)) {
            $clauses[] = "(content_type = 1 AND content_id IN (" . implode(',', $movieIds) . "))";
        }
        if (!empty($seriesIds)) {
            $clauses[] = "(content_type = 2 AND content_id IN (" . implode(',', $seriesIds) . "))";
        }
        if (!empty($clauses)) {
            $stmt = $pdo->query("SELECT ctl.content_id, ctl.content_type, ct.name, ct.background_color, ct.text_color
                FROM custom_tag_log ctl JOIN custom_tags ct ON ct.id = ctl.custom_tags_id
                WHERE " . implode(" OR ", $clauses) . " ORDER BY ctl.id DESC");
            foreach ($stmt->fetchAll() as $t) {
                $key = ($t['content_type'] == 1 ? 'm:' : 's:') . intval($t['content_id']);
                if (!isset($tagMap[$key])) {
                    $tagMap[$key] = [
                        'name' => trim($t['name']),
                        'bg' => trim($t['background_color']),
                        'color' => trim($t['text_color']),
                    ];
                }
            }
        }
    } catch (Exception $e) {}

    foreach ($items as &$it) {
        $key = ($it['item_type'] === 'movie' ? 'm:' : 's:') . intval($it['id']);
        if (isset($tagMap[$key]) && $tagMap[$key]['name'] !== '') {
            $it['custom_tag'] = $tagMap[$key]['name'];
            if ($tagMap[$key]['bg'] !== '') $it['custom_tag_bg'] = $tagMap[$key]['bg'];
            if ($tagMap[$key]['color'] !== '') $it['custom_tag_color'] = $tagMap[$key]['color'];
        }
    }
}

// Mixed ordering: interleave movies and series by release date (or name)
if ($type === 'all' && count($items) > 1) {
    usort($items, function ($a, $b) use ($sort) {
        if ($sort === 'name') {
            return strcmp(strtolower((string)($a['name'] ?? '')), strtolower((string)($b['name'] ?? '')));
        }
        $da = (string)($a['release_date'] ?? '');
        $db = (string)($b['release_date'] ?? '');
        return strcmp($db, $da);
    });
}

json_response(true, ["items" => $items], "Content fetched");
