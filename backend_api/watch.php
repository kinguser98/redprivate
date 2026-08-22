<?php
require_once "config.php";

$id = intval($_GET['id'] ?? 0);
$type = strtolower(trim($_GET['type'] ?? 'movie'));
if ($type !== 'movie' && $type !== 'series') {
    $type = 'movie';
}

$title = "Red App";
$poster = "";
$description = "Watch online on Red App";

if ($id > 0) {
    try {
        if ($type === 'movie') {
            $stmt = $pdo->prepare("SELECT name, poster, description FROM movies WHERE id = ?");
            $stmt->execute([$id]);
            $item = $stmt->fetch();
            if ($item) {
                $title = $item['name'] ?? 'Movie';
                $poster = $item['poster'] ?? '';
                $description = !empty($item['description']) ? substr(strip_tags($item['description']), 0, 150) . '...' : 'Watch on Red App';
            }
        } else {
            $stmt = $pdo->prepare("SELECT name, poster, description FROM web_series WHERE id = ?");
            $stmt->execute([$id]);
            $item = $stmt->fetch();
            if ($item) {
                $title = $item['name'] ?? 'Web Series';
                $poster = $item['poster'] ?? '';
                $description = !empty($item['description']) ? substr(strip_tags($item['description']), 0, 150) . '...' : 'Watch on Red App';
            }
        }
    } catch (Exception $e) {}
}

$deepLink = "redapp://watch?type=" . urlencode($type) . "&id=" . $id;

if (isset($_GET['json'])) {
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'title' => $title,
        'poster' => $poster,
        'description' => $description,
        'deep_link' => $deepLink
    ]);
    exit;
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <title><?= htmlspecialchars($title) ?> - Red App</title>
    <meta name="description" content="<?= htmlspecialchars($description) ?>">
    <!-- OpenGraph metadata for rich previews -->
    <meta property="og:title" content="<?= htmlspecialchars($title) ?>">
    <meta property="og:description" content="<?= htmlspecialchars($description) ?>">
    <?php if (!empty($poster)): ?>
    <meta property="og:image" content="<?= htmlspecialchars($poster) ?>">
    <?php endif; ?>
    <meta name="theme-color" content="#E50914">
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;700;900&display=swap" rel="stylesheet">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Outfit', -apple-system, BlinkMacSystemFont, sans-serif; }
        body {
            background-color: #0B0E14;
            color: #FFFFFF;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 20px;
            text-align: center;
            overflow-x: hidden;
            position: relative;
        }
        .bg-glow {
            position: absolute;
            width: 320px;
            height: 320px;
            background: radial-gradient(circle, rgba(229, 9, 20, 0.25) 0%, rgba(11, 14, 20, 0) 70%);
            top: 20%;
            left: 50%;
            transform: translate(-50%, -50%);
            z-index: 0;
            pointer-events: none;
        }
        .card {
            position: relative;
            z-index: 1;
            background: rgba(22, 27, 40, 0.85);
            backdrop-filter: blur(16px);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 24px;
            padding: 28px 22px;
            max-width: 400px;
            width: 100%;
            box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6);
        }
        .poster-container {
            width: 130px;
            height: 185px;
            margin: 0 auto 18px;
            border-radius: 16px;
            overflow: hidden;
            border: 2px solid rgba(229, 9, 20, 0.5);
            box-shadow: 0 10px 25px rgba(229, 9, 20, 0.35);
            background: #141722;
        }
        .poster-container img {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }
        .app-badge {
            display: inline-flex;
            align-items: center;
            background: rgba(229, 9, 20, 0.15);
            border: 1px solid rgba(229, 9, 20, 0.4);
            color: #FF4D58;
            font-size: 11px;
            font-weight: 700;
            padding: 4px 10px;
            border-radius: 20px;
            margin-bottom: 12px;
            letter-spacing: 0.5px;
            text-transform: uppercase;
        }
        h1 {
            font-size: 20px;
            font-weight: 800;
            color: #FFFFFF;
            margin-bottom: 8px;
            line-height: 1.3;
        }
        p {
            font-size: 12.5px;
            color: #8E9BAE;
            margin-bottom: 22px;
            line-height: 1.5;
        }
        .btn-watch {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            width: 100%;
            background: linear-gradient(135deg, #E50914 0%, #B80710 100%);
            color: #FFFFFF;
            text-decoration: none;
            font-size: 15px;
            font-weight: 800;
            padding: 14px 20px;
            border-radius: 14px;
            box-shadow: 0 8px 24px rgba(229, 9, 20, 0.45);
            transition: transform 0.2s, box-shadow 0.2s;
            border: none;
            cursor: pointer;
        }
        .btn-watch:active {
            transform: scale(0.97);
        }
        .footer-text {
            margin-top: 16px;
            font-size: 11px;
            color: #5A6678;
        }
    </style>
</head>
<body>
    <div class="bg-glow"></div>
    <div class="card">
        <div class="app-badge">🔥 Available on Red App</div>
        
        <?php if (!empty($poster)): ?>
        <div class="poster-container">
            <img src="<?= htmlspecialchars($poster) ?>" alt="<?= htmlspecialchars($title) ?>">
        </div>
        <?php endif; ?>

        <h1><?= htmlspecialchars($title) ?></h1>
        <p><?= htmlspecialchars($description) ?></p>

        <a href="<?= htmlspecialchars($deepLink) ?>" class="btn-watch" id="openBtn">
            <span>🎬 OPEN IN RED APP</span>
        </a>

        <div class="footer-text">Click the button above to launch and stream directly in the app.</div>
    </div>

    <script>
        // Automatically attempt to launch the app via custom scheme
        window.addEventListener('DOMContentLoaded', function() {
            setTimeout(function() {
                window.location.href = "<?= $deepLink ?>";
            }, 300);
        });
    </script>
</body>
</html>
