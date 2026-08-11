<?php
require_once "config.php";

$search = trim($_GET['search'] ?? '');
$sort = $_GET['sort'] ?? 'latest';
$limit = min(intval($_GET['limit'] ?? 9999), 9999);

$order_clause = "ORDER BY ws.id DESC";
if ($sort === 'name') {
    $order_clause = "ORDER BY ws.name ASC";
}

$where = ["ws.status = 1"];
$params = [];
if (!empty($search)) {
    $where[] = "ws.name LIKE ?";
    $params[] = "%$search%";
}

$where_sql = implode(" AND ", $where);

$stmt = $pdo->prepare("SELECT ws.id, ws.name, ws.description, ws.poster, ws.banner, ws.release_date FROM web_series ws WHERE $where_sql $order_clause LIMIT $limit");
$stmt->execute($params);
$series_list = $stmt->fetchAll();

foreach ($series_list as &$series) {
    $stmt = $pdo->prepare("SELECT id, Session_Name, season_order FROM web_series_seasons WHERE web_series_id = ? AND status = 1 ORDER BY season_order ASC");
    $stmt->execute([$series['id']]);
    $seasons = $stmt->fetchAll();

    foreach ($seasons as &$season) {
        $stmt = $pdo->prepare("SELECT id, Episoade_Name, episoade_image, episoade_description, episoade_order FROM web_series_episoade WHERE season_id = ? AND status = 1 ORDER BY episoade_order ASC");
        $stmt->execute([$season['id']]);
        $episodes = $stmt->fetchAll();

        foreach ($episodes as &$ep) {
            $stmt = $pdo->prepare("SELECT id, name, url, quality, type FROM episode_play_links WHERE episode_id = ? AND status = 1 ORDER BY link_order ASC LIMIT 1");
            $stmt->execute([$ep['id']]);
            $link = $stmt->fetch();
            $ep['play_link'] = $link ?: null;
        }
        $season['episodes'] = $episodes;
    }
    $series['seasons'] = $seasons;
}

json_response(true, ["items" => $series_list], "Series content fetched");
?>
