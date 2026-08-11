<?php
header('Content-Type: application/json; charset=utf-8');

ini_set('display_errors', 0);
error_reporting(0);

$action = isset($_GET['action']) ? $_GET['action'] : 'list_sources';
$source = isset($_GET['source']) ? $_GET['source'] : 'xhamster';
$page   = isset($_GET['page']) ? intval($_GET['page']) : 1;
if ($page < 1) $page = 1;
$query  = isset($_GET['query']) ? trim($_GET['query']) : '';

if ($action === 'list_sources') {
    echo json_encode([
        'status' => 'success',
        'sources' => [
            [
                'id' => 'xhamster',
                'name' => 'XHamster',
                'logo' => 'https://static.xhpingcdn.com/xh-desktop/images/logo.svg',
                'search_enabled' => true
            ],
            [
                'id' => 'deephot',
                'name' => 'DeepHot',
                'logo' => 'https://deephot.link/wp-content/uploads/2026/08/cropped-favicon-32x32.png',
                'search_enabled' => true
            ],
            [
                'id' => 'missav',
                'name' => 'MissAV',
                'logo' => 'https://missav.ws/img/logo.png',
                'search_enabled' => true
            ]
        ]
    ]);
    exit;
}

function getCurl($url, $referer = '') {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
    curl_setopt($ch, CURLOPT_TIMEOUT, 15);
    curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
    $headers = [
        'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language: en-US,en;q=0.9'
    ];
    if (!empty($referer)) {
        $headers[] = 'Referer: ' . $referer;
    }
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    $html = curl_exec($ch);
    curl_close($ch);
    return $html;
}

if ($action === 'fetch_grid') {
    // -------------------------------------------------------------
    // SOURCE 1: XHAMSTER (Un-blurred high-res WebP posters)
    // -------------------------------------------------------------
    if ($source === 'xhamster') {
        $searchKey = !empty($query) ? $query : 'Indian';
        $encodedQuery = urlencode($searchKey);
        
        $targetUrl = "https://xhamster46.desi/search/{$encodedQuery}";
        if ($page > 1) {
            $targetUrl = "https://xhamster46.desi/search/{$encodedQuery}?page={$page}";
        }

        $html = getCurl($targetUrl);
        if (empty($html)) {
            echo json_encode(['status' => 'error', 'message' => "Failed to fetch XHamster grid"]);
            exit;
        }

        $items = [];
        $seenUrls = [];

        if (preg_match('/window\\.initials\\s*=\\s*({.*?});/s', $html, $m)) {
            $data = json_decode($m[1], true);
            if (isset($data['searchResult']['videoThumbProps']) && is_array($data['searchResult']['videoThumbProps'])) {
                foreach ($data['searchResult']['videoThumbProps'] as $v) {
                    $title = isset($v['title']) ? trim($v['title']) : '';
                    $href  = isset($v['pageURL']) ? trim($v['pageURL']) : '';
                    $poster = isset($v['thumbURL']) ? trim($v['thumbURL']) : '';

                    if (!empty($title) && !empty($href) && !empty($poster)) {
                        if (strpos($href, 'http') !== 0) {
                            $href = 'https://xhamster46.desi' . (strpos($href, '/') === 0 ? '' : '/') . $href;
                        }

                        // REMOVE BLUR MODIFIER b(2), WHILE PRESERVING VALID WEBP EXTENSION
                        $poster = str_replace(['/b(2),', 'b(2),'], '', $poster);

                        if (!isset($seenUrls[$href])) {
                            $seenUrls[$href] = true;
                            $items[] = [
                                'title' => $title,
                                'link' => $href,
                                'poster' => $poster,
                            ];
                        }
                    }
                }
            }
        }

        if (count($items) < 10) {
            @$dom = new DOMDocument();
            @$dom->loadHTML($html);
            $xpath = new DOMXPath($dom);
            $links = $xpath->query('//a[contains(@href, "/videos/")]');

            foreach ($links as $link) {
                $href = $link->getAttribute('href');
                if (empty($href) || strpos($href, '/videos/') === false) continue;
                if (strpos($href, 'http') !== 0) {
                    $href = 'https://xhamster46.desi' . (strpos($href, '/') === 0 ? '' : '/') . $href;
                }
                if (isset($seenUrls[$href])) continue;

                $title = '';
                $poster = '';
                $imgs = $link->getElementsByTagName('img');
                if ($imgs->length === 0 && $link->parentNode) {
                    $imgs = $link->parentNode->getElementsByTagName('img');
                }

                if ($imgs->length > 0) {
                    $img = $imgs->item(0);
                    $title = $img->getAttribute('alt');
                    if (empty($title)) $title = $img->getAttribute('title');
                    $poster = $img->getAttribute('data-src');
                    if (empty($poster)) $poster = $img->getAttribute('src');
                }

                if (empty($title)) {
                    $title = trim($link->textContent);
                }

                $title = trim(preg_replace('/\\s+/', ' ', $title));

                if (!empty($title) && strlen($title) > 4 && !empty($poster) && strpos($poster, 'data:image') === false) {
                    $poster = str_replace(['/b(2),', 'b(2),'], '', $poster);
                    $seenUrls[$href] = true;
                    $items[] = [
                        'title' => $title,
                        'link' => $href,
                        'poster' => $poster,
                    ];
                }
            }
        }

        echo json_encode([
            'status' => 'success',
            'page' => $page,
            'query' => $query,
            'items' => $items
        ]);
        exit;
    }

    // -------------------------------------------------------------
    // SOURCE 2: DEEPHOT (Strictly scoped search results without sidebar duplicate noise)
    // -------------------------------------------------------------
    if ($source === 'deephot') {
        $targetUrl = 'https://deephot.link/';
        if (!empty($query)) {
            $targetUrl = 'https://deephot.link/?s=' . urlencode($query);
            if ($page > 1) {
                $targetUrl = 'https://deephot.link/page/' . $page . '/?s=' . urlencode($query);
            }
        } else {
            if ($page > 1) {
                $targetUrl = 'https://deephot.link/page/' . $page . '/';
            }
        }

        $html = getCurl($targetUrl);
        if (empty($html)) {
            echo json_encode(['status' => 'error', 'message' => 'Failed to fetch DeepHot grid']);
            exit;
        }

        @$dom = new DOMDocument();
        @$dom->loadHTML($html);
        $xpath = new DOMXPath($dom);

        // Scope strictly to main search articles
        $articles = $xpath->query('//main//article | //div[contains(@class, "site-main")]//article | //div[contains(@class, "content-area")]//article');

        $items = [];
        $seen = [];

        foreach ($articles as $art) {
            $aTags = $art->getElementsByTagName('a');
            if ($aTags->length === 0) continue;

            $href = '';
            $title = '';
            for ($i = 0; $i < $aTags->length; $i++) {
                $a = $aTags->item($i);
                $h = $a->getAttribute('href');
                $t = $a->getAttribute('title');
                if (empty($t)) $t = trim($a->textContent);
                if (!empty($h) && strpos($h, 'deephot.link') !== false && strlen($t) > 3 && strpos($h, '/category/') === false && strpos($h, '/tag/') === false && strpos($h, '/page/') === false) {
                    $href = $h;
                    $title = $t;
                    break;
                }
            }

            if (empty($href) || isset($seen[$href])) continue;

            $poster = '';
            $imgs = $art->getElementsByTagName('img');
            if ($imgs->length > 0) {
                $img = $imgs->item(0);
                $poster = $img->getAttribute('data-src');
                if (empty($poster)) $poster = $img->getAttribute('src');
                if (empty($poster)) $poster = $img->getAttribute('data-lazy-src');
            }

            if (!empty($title) && !empty($href)) {
                $seen[$href] = true;
                $items[] = [
                    'title' => trim(preg_replace('/\\s+/', ' ', $title)),
                    'link' => $href,
                    'poster' => $poster
                ];
            }
        }

        // Fallback to general links if articles query was empty
        if (count($items) < 5) {
            $links = $xpath->query('//a[contains(@href, "deephot.link/")]');
            foreach ($links as $link) {
                $href = $link->getAttribute('href');
                if (empty($href) || strpos($href, '/category/') !== false || strpos($href, '/tag/') !== false || strpos($href, '/page/') !== false) continue;
                if (isset($seen[$href])) continue;

                $title = '';
                $poster = '';
                $imgs = $link->getElementsByTagName('img');
                if ($imgs->length > 0) {
                    $img = $imgs->item(0);
                    $title = $img->getAttribute('alt');
                    if (empty($title)) $title = $img->getAttribute('title');
                    $poster = $img->getAttribute('data-src');
                    if (empty($poster)) $poster = $img->getAttribute('src');

                    if (!empty($title) && strlen($title) > 3) {
                        $seen[$href] = true;
                        $items[] = [
                            'title' => trim(preg_replace('/\\s+/', ' ', $title)),
                            'link' => $href,
                            'poster' => $poster
                        ];
                    }
                }
            }
        }

        echo json_encode([
            'status' => 'success',
            'page' => $page,
            'query' => $query,
            'items' => $items
        ]);
        exit;
    }

    // -------------------------------------------------------------
    // SOURCE 3: MISSAV (missav.ws/en/)
    // -------------------------------------------------------------
    if ($source === 'missav') {
        $targetUrl = 'https://missav.ws/en/';
        if (!empty($query)) {
            $targetUrl = 'https://missav.ws/en/search/' . urlencode($query);
            if ($page > 1) {
                $targetUrl = 'https://missav.ws/en/search/' . urlencode($query) . '?page=' . $page;
            }
        } else {
            if ($page > 1) {
                $targetUrl = 'https://missav.ws/en/new?page=' . $page;
            }
        }

        $html = getCurl($targetUrl);
        $items = [];
        $seen = [];

        if (!empty($html)) {
            @$dom = new DOMDocument();
            @$dom->loadHTML($html);
            $xpath = new DOMXPath($dom);

            $links = $xpath->query('//a[contains(@href, "missav.ws/en/")] | //a[contains(@href, "/en/")]');
            foreach ($links as $link) {
                $href = $link->getAttribute('href');
                if (empty($href) || strpos($href, '/search') !== false || strpos($href, '/actress') !== false || strpos($href, '/genres') !== false) continue;
                if (strpos($href, 'http') !== 0) {
                    $href = 'https://missav.ws' . (strpos($href, '/') === 0 ? '' : '/') . $href;
                }
                if (isset($seen[$href])) continue;

                $title = '';
                $poster = '';
                $imgs = $link->getElementsByTagName('img');
                if ($imgs->length > 0) {
                    $img = $imgs->item(0);
                    $title = $img->getAttribute('alt');
                    if (empty($title)) $title = $img->getAttribute('title');
                    $poster = $img->getAttribute('data-src');
                    if (empty($poster)) $poster = $img->getAttribute('src');
                }

                if (!empty($title) && strlen($title) > 3) {
                    $seen[$href] = true;
                    $items[] = [
                        'title' => trim(preg_replace('/\\s+/', ' ', $title)),
                        'link' => $href,
                        'poster' => $poster
                    ];
                }
            }
        }

        echo json_encode([
            'status' => 'success',
            'page' => $page,
            'query' => $query,
            'items' => $items
        ]);
        exit;
    }
}

if ($action === 'resolve_item') {
    $detailUrl = isset($_GET['url']) ? $_GET['url'] : '';
    if (empty($detailUrl)) {
        echo json_encode(['status' => 'error', 'message' => 'Missing detail URL']);
        exit;
    }

    $html = getCurl($detailUrl);
    $qualities = [];

    // 1. DeepHot iframe Base64 extraction
    if (preg_match('#player-x\.php\?q=([a-zA-Z0-9+/=]+)#i', $html, $bq)) {
        $decoded = urldecode(base64_decode($bq[1]));
        if (preg_match('#<source[^\>]+src=["\x27]([^"\x27]+)["\x27]#i', $decoded, $sm)) {
            $qualities['1080p Full HD'] = $sm[1];
        }
    }

    // 2. Direct M3U8 or MP4 extraction
    if (empty($qualities)) {
        if (preg_match_all('#https?://[^\s"\x27<>]+\.m3u8[^\s"\x27<>]*#i', $html, $m)) {
            $qualities['720p HD'] = $m[0][0];
        } else if (preg_match_all('#https?://[^\s"\x27<>]+\.mp4[^\s"\x27<>]*#i', $html, $m2)) {
            $qualities['Direct MP4'] = $m2[0][0];
        }
    }

    if (empty($qualities)) {
        echo json_encode(['status' => 'error', 'message' => 'Could not resolve playable media links']);
        exit;
    }

    echo json_encode([
        'status' => 'success',
        'qualities' => $qualities
    ]);
    exit;
}

echo json_encode(['status' => 'error', 'message' => 'Invalid action']);
