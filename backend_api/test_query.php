<?php
require_once 'config.php';

$stmt = $pdo->prepare("SELECT s.id, s.name, s.poster, s.banner, 'series' AS item_type, ? AS ott_name FROM web_series s WHERE s.status = 1 AND s.genres LIKE ? ORDER BY RAND() LIMIT 5");
$raw = 'Malayalam';
$stmt->execute([strtoupper($raw), '%' . $raw . '%']);
$res = $stmt->fetchAll(PDO::FETCH_ASSOC);

header('Content-Type: application/json');
echo json_encode(['count' => count($res), 'items' => $res]);
