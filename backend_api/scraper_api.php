<?php
header('Content-Type: application/json; charset=utf-8');

ini_set('display_errors', 0);
error_reporting(0);

// Jina reader round-trips can take 5-30s; keep shared-hosting limits out of the way.
@set_time_limit(120);

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
                'id' => 'xvideos',
                'name' => 'XVIDEOS',
                'logo' => 'https://www.xvideos2.com/static-files/v3/img/skins/default/logo/xv.white.32.png',
                'search_enabled' => true
            ],
            [
                'id' => 'tnaflix',
                'name' => 'TNAFlix',
                'logo' => 'https://www.tnaflix.com/favicon.ico',
                'search_enabled' => true
            ],
            [
                'id' => 'redtube',
                'name' => 'RedTube',
                'logo' => 'https://www.redtube.com/favicon.ico',
                'search_enabled' => true
            ],
            [
                'id' => 'spankbang',
                'name' => 'SpankBang',
                'logo' => 'https://spankbang.com/favicon.ico',
                'search_enabled' => true
            ]
        ]
    ]);
    exit;
}

if ($action === 'fetch_categories') {
    // Curated list for TNAFlix. Slugs are the exact category path segments in
    // real URLs like https://www.tnaflix.com/{slug} (no "/videos" suffix — that
    // returns a 404 page with generic cards). Default stays milf-porn.
    if ($source === 'tnaflix') {
        $cats = [
            ['slug' => 'milf-porn', 'name' => 'MILF'],
            ['slug' => 'amateur-porn', 'name' => 'Amateur'],
            ['slug' => 'asian-porn', 'name' => 'Asian'],
            ['slug' => 'anal-porn', 'name' => 'Anal'],
            ['slug' => 'babe-videos', 'name' => 'Babe'],
            ['slug' => 'bbw-porn', 'name' => 'BBW'],
            ['slug' => 'big-boobs', 'name' => 'Big Boobs'],
            ['slug' => 'big-cock', 'name' => 'Big Dick'],
            ['slug' => 'blonde-porn', 'name' => 'Blonde'],
            ['slug' => 'blowjob-videos', 'name' => 'Blowjob'],
            ['slug' => 'brunette-porn', 'name' => 'Brunette'],
            ['slug' => 'cartoon-porn', 'name' => 'Cartoon'],
            ['slug' => 'czech-porn', 'name' => 'Czech'],
            ['slug' => 'ebony-porn', 'name' => 'Ebony'],
            ['slug' => 'euro-porn', 'name' => 'European'],
            ['slug' => 'fetish-videos', 'name' => 'Fetish'],
            ['slug' => 'gang-bang', 'name' => 'Gang Bang'],
            ['slug' => 'granny-porn', 'name' => 'Granny'],
            ['slug' => 'group-sex', 'name' => 'Group Sex'],
            ['slug' => 'hardcore-porn', 'name' => 'Hardcore'],
            ['slug' => 'hd-videos', 'name' => 'HD'],
            ['slug' => 'hentai-porn', 'name' => 'Hentai'],
            ['slug' => 'interracial-porn', 'name' => 'Interracial'],
            ['slug' => 'japanese-porn', 'name' => 'Japanese'],
            ['slug' => 'latina-porn', 'name' => 'Latina'],
            ['slug' => 'lesbian-porn', 'name' => 'Lesbian'],
            ['slug' => 'masturbation-videos', 'name' => 'Masturbation'],
            ['slug' => 'mature-porn', 'name' => 'Mature'],
            ['slug' => 'pov-porn', 'name' => 'POV'],
            ['slug' => 'redhead-porn', 'name' => 'Redhead'],
            ['slug' => 'russian-porn', 'name' => 'Russian'],
            ['slug' => 'squirting-videos', 'name' => 'Squirt'],
            ['slug' => 'teen-porn', 'name' => 'Teen'],
            ['slug' => 'threesome-sex', 'name' => 'Threesome'],
            ['slug' => 'vr-porn', 'name' => 'VR'],
        ];
        echo json_encode(['status' => 'success', 'source' => $source, 'categories' => $cats]);
        exit;
    }

    if ($source === 'redtube') {
        $cats = [
            ['slug' => 'milf', 'name' => 'MILF'],
            ['slug' => 'teen', 'name' => 'Teen'],
            ['slug' => 'anal', 'name' => 'Anal'],
            ['slug' => 'asian', 'name' => 'Asian'],
            ['slug' => 'blowjob', 'name' => 'Blowjob'],
            ['slug' => 'amateur', 'name' => 'Amateur'],
            ['slug' => 'big-cock', 'name' => 'Big Dick'],
            ['slug' => 'ebony', 'name' => 'Ebony'],
            ['slug' => 'latina', 'name' => 'Latina'],
            ['slug' => 'lesbian', 'name' => 'Lesbian'],
            ['slug' => 'mature', 'name' => 'Mature'],
            ['slug' => 'pov', 'name' => 'POV'],
            ['slug' => 'russian', 'name' => 'Russian'],
            ['slug' => 'creampie', 'name' => 'Cream Pie'],
            ['slug' => 'handjob', 'name' => 'Handjob'],
            ['slug' => 'interracial', 'name' => 'Interracial'],
            ['slug' => 'masturbation', 'name' => 'Masturbation'],
            ['slug' => 'solo', 'name' => 'Solo'],
            ['slug' => 'squirt', 'name' => 'Squirt'],
            ['slug' => 'threesome', 'name' => 'Threesome'],
            ['slug' => 'hd-porn', 'name' => 'HD'],
            ['slug' => 'cartoon', 'name' => 'Cartoon'],
            ['slug' => 'pornstar', 'name' => 'Pornstars'],
            ['slug' => 'public', 'name' => 'Public'],
            ['slug' => 'small-tits', 'name' => 'Small Tits'],
            ['slug' => 'uniform', 'name' => 'Uniform'],
        ];
        echo json_encode(['status' => 'success', 'source' => $source, 'categories' => $cats]);
        exit;
    }

    if ($source === 'spankbang') {
        $cats = [
            ['slug' => 'milf', 'name' => 'MILF'],
            ['slug' => 'teen', 'name' => 'Teen'],
            ['slug' => 'asian', 'name' => 'Asian'],
            ['slug' => 'anal', 'name' => 'Anal'],
            ['slug' => 'amateur', 'name' => 'Amateur'],
            ['slug' => 'blowjob', 'name' => 'Blowjob'],
            ['slug' => 'big-ass', 'name' => 'Big Ass'],
            ['slug' => 'big-cock', 'name' => 'Big Dick'],
            ['slug' => 'big-tits', 'name' => 'Big Tits'],
            ['slug' => 'blonde', 'name' => 'Blonde'],
            ['slug' => 'brunette', 'name' => 'Brunette'],
            ['slug' => 'creampie', 'name' => 'Cream Pie'],
            ['slug' => 'cumshot', 'name' => 'Cumshot'],
            ['slug' => 'ebony', 'name' => 'Ebony'],
            ['slug' => 'gangbang', 'name' => 'Gang Bang'],
            ['slug' => 'granny', 'name' => 'Granny'],
            ['slug' => 'handjob', 'name' => 'Handjob'],
            ['slug' => 'hd-video', 'name' => 'HD'],
            ['slug' => 'interracial', 'name' => 'Interracial'],
            ['slug' => 'japanese', 'name' => 'Japanese'],
            ['slug' => 'lesbian', 'name' => 'Lesbian'],
            ['slug' => 'masturbation', 'name' => 'Masturbation'],
            ['slug' => 'mature', 'name' => 'Mature'],
            ['slug' => 'pov', 'name' => 'POV'],
            ['slug' => 'russian', 'name' => 'Russian'],
            ['slug' => 'squirt', 'name' => 'Squirt'],
            ['slug' => 'threesome', 'name' => 'Threesome'],
            ['slug' => 'toys', 'name' => 'Toys'],
            ['slug' => 'wife', 'name' => 'Wife'],
        ];
        echo json_encode(['status' => 'success', 'source' => $source, 'categories' => $cats]);
        exit;
    }

    echo json_encode(['status' => 'success', 'source' => $source, 'categories' => []]);
    exit;
}

function getCurl($url, $referer = '', $ua = '') {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
    curl_setopt($ch, CURLOPT_TIMEOUT, 15);
    if (empty($ua)) {
        $ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
    }
    curl_setopt($ch, CURLOPT_USERAGENT, $ua);
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

// Eporner fetch that survives DNS poisoning (some regions block *.eporner.com at
// the resolver level). The server's own resolver may also point at a dead IP, so
// we resolve the domain ourselves over DoH (cloudflare-dns.com), pin the returned
// IPs with short per-IP timeouts, and fall back to the static list only if DoH
// fails. DoH JSON is fetched with the same short timeout to keep the grid fast.
// Generic fetch for DNS-poisoned hosts. Resolves the hostname over DoH
// (cloudflare-dns.com), pins the returned IPs plus optional static fallback IPs
// with short per-IP timeouts, and returns only a response that:
//   1. is non-empty, 2. is not a Cloudflare challenge, and 3. (if a $needle is
//   given) contains the expected content marker. The first basic-valid response
//   is remembered and returned as a last resort so the caller still gets a page
//   to parse rather than an empty grid.
function getCurlPinned($url, $host, $needle = '', $staticIps = []) {
    $pinned = [];

    $dns = getCurlDoh($host);
    foreach ($dns as $ip) {
        if (filter_var($ip, FILTER_VALIDATE_IP)) {
            $pinned[] = $ip;
        }
    }

    foreach ($staticIps as $ip) {
        if (!in_array($ip, $pinned)) {
            $pinned[] = $ip;
        }
    }
    if (empty($pinned)) {
        $pinned[] = $host;
    }

    $fallback = '';
    foreach ($pinned as $entry) {
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 4);
        curl_setopt($ch, CURLOPT_TIMEOUT, 8);
        curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
        if (filter_var($entry, FILTER_VALIDATE_IP)) {
            curl_setopt($ch, CURLOPT_RESOLVE, ["{$host}:443:{$entry}"]);
        }
        $html = curl_exec($ch);
        curl_close($ch);
        if (empty($html) || strpos($html, 'Just a moment') !== false || strpos($html, 'Attention Required') !== false) {
            continue;
        }
        if (!empty($needle) && strpos($html, $needle) !== false) {
            return $html;
        }
        if ($fallback === '') {
            $fallback = $html;
        }
    }
    return $fallback;
}

function getCurlEporner($url, $needle = '') {
    return getCurlPinned($url, 'www.eporner.com', $needle, ['94.75.220.3', '94.75.220.2', '94.75.220.10', '94.75.220.1', '94.75.220.9']);
}

function getCurlTnaflix($url, $needle = '') {
    return getCurlPinned($url, 'www.tnaflix.com', $needle, []);
}

// Fetch a source page through the Jina reader proxy. RedTube/SpankBang sit
// behind Cloudflare + an age-gate Turnstile challenge that datacenter IPs
// cannot pass, and their page JS now embeds config in escaped JSON. Jina
// renders the page headlessly (whitelisted crawler, passes the challenge) and
// X-Respond-With: html returns the raw HTML so the existing parsers/resolvers
// keep working on current markup.
function getViaJina($url, $needle = '', $noCache = false) {
    $started = microtime(true);
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, 'https://r.jina.ai/' . $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 10);
    curl_setopt($ch, CURLOPT_TIMEOUT, 55);
    curl_setopt($ch, CURLOPT_ENCODING, '');
    $headers = [
        'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'X-Respond-With: html',
        'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
    ];
    // Anonymous Reader traffic is the lowest-trust pool and the most likely to
    // be blocked/rate-limited from a datacenter IP. If a key is configured in
    // config.php, send it so requests route to the authenticated pool.
    if (defined('JINA_API_KEY') && !empty(JINA_API_KEY)) {
        $headers[] = 'Authorization: Bearer ' . JINA_API_KEY;
    }
    if ($noCache) {
        $headers[] = 'X-No-Cache: true';
    }
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    $html = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err = curl_error($ch);
    curl_close($ch);
    $elapsed = round((microtime(true) - $started) * 1000);

    $GLOBALS['__jina_last'] = [
        'url' => $url,
        'http_code' => $http_code,
        'err' => $err,
        'elapsed_ms' => $elapsed,
        'len' => is_string($html) ? strlen($html) : 0
    ];
    if (empty($html) || $http_code >= 400 || (!empty($needle) && strpos($html, $needle) === false)) {
        return '';
    }
    return $html;
}

// Try the direct pinned fetch first (fast when the datacenter IP is allowed),
// then fall back to Jina raw-HTML for challenge-protected pages.
function fetchPornSource($url, $host, $needle = '', $staticIps = [], $jinaNoCache = false) {
    $html = getCurlPinned($url, $host, $needle, $staticIps);
    if (!empty($html) && (empty($needle) || strpos($html, $needle) !== false)) {
        return $html;
    }
    return getViaJina($url, $needle, $jinaNoCache);
}

// Fetch one RedTube media/token endpoint (/media/hls or /media/mp4). Tries the
// endpoint directly first; if the datacenter IP cannot reach redtube at all,
// the same endpoint is fetched through Jina (which returns the JSON array
// wrapped in a <pre> block with &amp;-escaped ampersands and \/-escaped
// slashes, both of which we normalize before returning).
function fetchRedtubeTokenJson($format, $token) {
    $url = 'https://www.redtube.com/media/' . $format . '?s=' . $token;
    $json = getCurl($url, 'https://www.redtube.com/');
    if (!empty($json)) {
        return $json;
    }
    $body = getViaJina($url, '"videoUrl"', true);
    if (!empty($body) && preg_match('#<pre[^>]*>(.*?)</pre>#s', $body, $pm)) {
        return str_replace('&amp;', '&', trim($pm[1]));
    }
    return '';
}

// Parse eporner server-rendered card blocks (<div class="mb" data-id="...">).
// Used for BOTH the /cat/{slug}/{page}/ category grid and the /search/{q}/{page}/
// search page so results match the eporner.com website exactly.
function parseEpornerCards($html) {
    $items = [];
    $seen = [];
    if (preg_match_all('#<div class="mb[^"]*" data-id="\d+"[^>]*>.*?<div class="mbunder">.*?</div></div>#s', $html, $cards)) {
        foreach ($cards[0] as $card) {
            if (!preg_match('#href="(/video-[A-Za-z0-9]+/[^"]+/)"#', $card, $hm)) continue;
            $href = 'https://www.eporner.com' . $hm[1];
            if (isset($seen[$href])) continue;

            $title = '';
            if (preg_match('#alt="([^"]*)"#', $card, $tm)) $title = trim($tm[1]);
            if (empty($title) && preg_match('#<p class="mbtit"><a[^>]*>([^<]*)</a>#s', $card, $tm2)) {
                $title = trim($tm2[1]);
            }

            $poster = '';
            if (preg_match('#<img src="([^"]+)"#', $card, $pm)) $poster = trim($pm[1]);

            $duration = '';
            if (preg_match('#<span class="mbtim"[^>]*>([^<]*)</span>#', $card, $dm)) {
                $duration = trim($dm[1]);
            }

            if (!empty($title) && !empty($poster)) {
                $seen[$href] = true;
                $items[] = [
                    'title' => $title,
                    'link' => $href,
                    'poster' => $poster,
                    'duration' => $duration
                ];
            }
        }
    }
    return $items;
}

// Parse eporner official JSON API videos list (fallback when the HTML page
// yields too few cards, e.g. for a category with no recent uploads).
function parseEpornerApi($json) {
    $items = [];
    $seen = [];
    $data = json_decode($json, true);
    if (isset($data['videos']) && is_array($data['videos'])) {
        foreach ($data['videos'] as $v) {
            $title = isset($v['title']) ? trim($v['title']) : '';
            $href = isset($v['url']) ? trim($v['url']) : '';
            if (empty($title) || empty($href) || isset($seen[$href])) continue;

            $poster = '';
            if (isset($v['default_thumb'])) {
                $thumb = $v['default_thumb'];
                if (is_array($thumb)) {
                    foreach (['src_big', 'src', 'src_small'] as $tk) {
                        if (!empty($thumb[$tk])) { $poster = $thumb[$tk]; break; }
                    }
                } elseif (is_string($thumb) && !empty($thumb)) {
                    $poster = $thumb;
                }
            }

            $duration = isset($v['length_min']) ? trim($v['length_min']) : '';

            $seen[$href] = true;
            $items[] = [
                'title' => $title,
                'link' => $href,
                'poster' => $poster,
                'duration' => $duration
            ];
        }
    }
    return $items;
}

// Parse TNAFlix server-rendered card blocks (<div data-vid="...">).
function parseTnaflixCards($html) {
    $items = [];
    $seen = [];
    $hrefRe = '#<a[^>]+class="[^"]*video-thumb[^"]*"[^>]+href="([^"]+)"#';
    $imgRe = '#<img[^>]+class="[^"]*lazyload[^"]*"[^>]+(?:data-src|src)="([^"]+)"[^>]+alt="([^"]*)"#';
    $durRe = '#class="thumb-icon video-duration"[^>]*>([^<]*)</div>#';

    if (preg_match_all('#<div data-vid="\d+"[^>]*>.*?</div>\s*</div>\s*</div>#s', $html, $blocks)) {
        foreach ($blocks[0] as $block) {
            if (!preg_match($hrefRe, $block, $hm)) continue;
            $href = trim($hm[1]);
            if (strpos($href, 'http') !== 0) {
                $href = 'https://www.tnaflix.com' . (strpos($href, '/') === 0 ? '' : '/') . $href;
            }
            if (isset($seen[$href])) continue;

            $title = '';
            $poster = '';
            if (preg_match($imgRe, $block, $pm)) {
                $poster = trim($pm[1]);
                $title = trim($pm[2]);
            }

            $duration = '';
            if (preg_match($durRe, $block, $dm)) {
                $duration = trim($dm[1]);
            }

            if (!empty($title) && !empty($poster)) {
                $seen[$href] = true;
                $items[] = [
                    'title' => $title,
                    'link' => $href,
                    'poster' => $poster,
                    'duration' => $duration
                ];
            }
        }
    }
    return $items;
}

// Parse RedTube classic card blocks (homepage, category and search pages use
// the same pornhub-style markup). The video link is the inner <a> carrying
// href="/{numericId}"; title comes from the thumb img alt, poster from
// data-o_thumb (a time-signed rdtcdn CDN URL), duration from tm_video_duration.
function parseRedtubeCards($html) {
    $items = [];
    $seen = [];
    if (preg_match_all('#<a[^>]+class="[^"]*video_link[^"]*"[^>]*href="(/[0-9]+)"[^>]*>.*?<img[^>]+data-o_thumb="([^"]+)"[^>]*alt="([^"]*)"[^>]*>.*?tm_video_duration">([^<]*)</span>#s', $html, $cards, PREG_SET_ORDER)) {
        foreach ($cards as $card) {
            $href = trim($card[1]);
            $link = 'https://www.redtube.com' . $href;
            if (isset($seen[$link])) continue;

            $poster = trim($card[2]);
            $title = trim($card[3]);
            $duration = isset($card[4]) ? trim($card[4]) : '';

            if (empty($title) || empty($poster)) continue;
            $seen[$link] = true;
            $items[] = [
                'title' => $title,
                'link' => $link,
                'poster' => $poster,
                'duration' => $duration
            ];
        }
    }
    return $items;
}

// Parse RedTube official JSON API search results. The API
// (api.redtube.com) is the ONLY redtube endpoint that is not behind the
// Cloudflare age-gate Turnstile, so all grids (search, category, newest) use it.
function parseRedtubeApi($json) {
    $items = [];
    $seen = [];
    $data = json_decode($json, true);
    if (!isset($data['videos']) || !is_array($data['videos'])) {
        return $items;
    }
    foreach ($data['videos'] as $entry) {
        if (!isset($entry['video']) || !is_array($entry['video'])) continue;
        $v = $entry['video'];
        $title = isset($v['title']) ? trim($v['title']) : '';
        $url = isset($v['url']) ? trim($v['url']) : '';
        if (empty($title) || empty($url) || isset($seen[$url])) continue;
        $poster = isset($v['default_thumb']) ? trim($v['default_thumb']) : '';
        $duration = isset($v['duration']) ? trim($v['duration']) : '';
        $seen[$url] = true;
        $items[] = [
            'title' => $title,
            'link' => $url,
            'poster' => $poster,
            'duration' => $duration
        ];
    }
    return $items;
}

// Parse SpankBang video-item cards (homepage, /{cat}/ and /s/{q}/ share the
// same markup). Each card holds the /{base36id}/video/{slug} link, the poster
// <img src>, its alt title and a data-testid="video-item-length" badge.
function parseSpankbangCards($html) {
    $items = [];
    $seen = [];
    if (preg_match_all('#<div data-testid="video-item"[^>]*>.*?<a href="((?:/[a-z0-9]+)/video/[^"]+)"[^>]*>.*?<img[^>]+(?:data-src|src)="([^"]+)"[^>]*alt="([^"]*)"[^>]*>.*?data-testid="video-item-length">\s*([^<]*?)\s*</div>#s', $html, $cards, PREG_SET_ORDER)) {
        foreach ($cards as $card) {
            $link = trim($card[1]);
            if (strpos($link, 'http') !== 0) {
                $link = 'https://spankbang.com' . $link;
            }
            if (isset($seen[$link])) continue;

            $poster = trim($card[2]);
            $title = trim($card[3]);
            $duration = isset($card[4]) ? preg_replace('/\s+/', ' ', trim($card[4])) : '';

            if (empty($title) || empty($poster)) continue;
            $seen[$link] = true;
            $items[] = [
                'title' => $title,
                'link' => $link,
                'poster' => $poster,
                'duration' => $duration
            ];
        }
    }
    return $items;
}

// Resolve a hostname's A records via Cloudflare's public DoH JSON endpoint.
// Returns a list of IPs (or [] if DoH is unreachable).
function getCurlDoh($host) {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, 'https://cloudflare-dns.com/dns-query?name=' . urlencode($host) . '&type=A');
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 4);
    curl_setopt($ch, CURLOPT_TIMEOUT, 6);
    curl_setopt($ch, CURLOPT_USERAGENT, 'curl');
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['accept: application/dns-json']);
    $json = curl_exec($ch);
    curl_close($ch);
    if (empty($json)) return [];
    $data = json_decode($json, true);
    $ips = [];
    if (isset($data['Answer']) && is_array($data['Answer'])) {
        foreach ($data['Answer'] as $a) {
            if (isset($a['type']) && $a['type'] === 1 && isset($a['data']) && filter_var($a['data'], FILTER_VALIDATE_IP)) {
                $ips[] = $a['data'];
            }
        }
    }
    return $ips;
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
    // SOURCE: XVIDEOS (www.xvideos2.com mirror) - default feed = Indian search
    // -------------------------------------------------------------
    if ($source === 'xvideos') {
        $targetUrl = 'https://www.xvideos2.com/';
        if (!empty($query)) {
            $targetUrl = 'https://www.xvideos2.com/?k=' . urlencode($query);
            if ($page > 1) $targetUrl .= '&p=' . $page;
        } else {
            // Default home = Indian content
            $targetUrl = 'https://www.xvideos2.com/?k=indian';
            if ($page > 1) $targetUrl .= '&p=' . $page;
        }

        $html = getCurl($targetUrl, 'https://www.xvideos2.com/');
        if (empty($html)) {
            echo json_encode(['status' => 'error', 'message' => 'Failed to fetch XVIDEOS grid']);
            exit;
        }

        $items = [];
        $seen = [];
        @$dom = new DOMDocument();
        @$dom->loadHTML($html);
        $xpath = new DOMXPath($dom);
        $blocks = $xpath->query('//div[contains(concat(" ", normalize-space(@class), " "), " thumb-block ")]');

        foreach ($blocks as $blk) {
            // Video detail link (first /video... anchor inside the block)
            $href = '';
            $anchors = $xpath->query('.//a[starts-with(@href, "/video")]', $blk);
            if ($anchors->length > 0) {
                $href = $anchors->item(0)->getAttribute('href');
            }
            if (empty($href) || isset($seen[$href])) continue;

            // Title from the .title link's `title` attribute
            $title = '';
            $titleA = $xpath->query('.//p[contains(@class, "title")]/a', $blk)->item(0);
            if ($titleA != null) {
                $title = $titleA->getAttribute('title');
                if (empty($title)) $title = trim($titleA->textContent);
            }
            if (empty($title)) $title = $anchors->item(0)->getAttribute('title');

            // Poster from the thumb img data-src
            $poster = '';
            $img = $xpath->query('.//img', $blk)->item(0);
            if ($img != null) {
                $poster = $img->getAttribute('data-src');
                if (empty($poster)) $poster = $img->getAttribute('data-sfwthumb');
                if (empty($poster)) $poster = $img->getAttribute('src');
            }

            // Duration badge (e.g. "4 min", "90 sec")
            $duration = '';
            $durNode = $xpath->query('.//span[contains(@class, "duration")]', $blk)->item(0);
            if ($durNode != null) {
                $duration = trim($durNode->textContent);
            }

            if (!empty($title) && !empty($poster) && strpos($poster, 'blank.gif') === false) {
                if (strpos($href, 'http') !== 0) {
                    $href = 'https://www.xvideos2.com' . (strpos($href, '/') === 0 ? '' : '/') . $href;
                }
                $seen[$href] = true;
                $items[] = [
                    'title' => trim(preg_replace('/\\s+/', ' ', $title)),
                    'link' => $href,
                    'poster' => $poster,
                    'duration' => $duration
                ];
            }
        }

        // Regex fallback if DOM yielded nothing (site markup change)
        if (count($items) < 5) {
            if (preg_match_all('#<p class="title"><a href="([^"]+)" title="([^"]*)">#i', $html, $tm)) {
                preg_match_all('#<img[^>]+data-src="([^"]+)"#i', $html, $tp);
                for ($i = 0; $i < count($tm[1]); $i++) {
                    $href = trim($tm[1][$i]);
                    if (isset($seen[$href])) continue;
                    $poster = isset($tp[1][$i]) ? trim($tp[1][$i]) : '';
                    if (strpos($href, 'http') !== 0) {
                        $href = 'https://www.xvideos2.com' . (strpos($href, '/') === 0 ? '' : '/') . $href;
                    }
                    $seen[$href] = true;
                    $items[] = [
                        'title' => trim($tm[2][$i]),
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

    // -------------------------------------------------------------
    // SOURCE: TNAFLIX (server-rendered page parsing)
    // Grid data comes from www.tnaflix.com directly. Playable streams are
    // signed and must be captured ON-DEVICE by the app (TnaflixResolver).
    // Category pages are served at /{slug} with pagination /{slug}/featured/{n}.
    // (The /{slug}/videos URLs are 404 pages that still render generic cards.)
    // -------------------------------------------------------------
    if ($source === 'tnaflix') {
        $category = isset($_GET['category']) ? trim($_GET['category']) : '';
        if (!empty($query)) {
            // /search?what=... returns the same <div data-vid> card markup.
            $targetUrl = "https://www.tnaflix.com/search?what=" . urlencode($query);
            if ($page > 1) {
                $targetUrl .= "&page={$page}";
            }
        } else {
            // Default to MILF when nothing is selected (matches the app).
            if (empty($category)) {
                $category = 'milf-porn';
            }
            $targetUrl = "https://www.tnaflix.com/{$category}";
            if ($page > 1) {
                $targetUrl .= "/featured/{$page}";
            }
        }

        $html = getCurlTnaflix($targetUrl, 'data-vid="');
        $items = $html !== '' ? parseTnaflixCards($html) : [];

        echo json_encode([
            'status' => 'success',
            'page' => $page,
            'query' => $query,
            'category' => $category,
            'items' => $items
        ]);
        exit;
    }

    // -------------------------------------------------------------
    // SOURCE: REDTUBE (official JSON API)
    // www.redtube.com pages are stuck behind the Cloudflare age-gate Turnstile
    // (datacenter IPs get only the interstitial), but the official JSON API at
    // api.redtube.com serves grids without any challenge. Search, category and
    // "newest" all go through redtube.Videos.searchVideos. Detail URLs are the
    // numeric video id; streams resolve via the embed page + /media tokens.
    // -------------------------------------------------------------
    if ($source === 'redtube') {
        $category = isset($_GET['category']) ? trim($_GET['category']) : '';
        if (!empty($query)) {
            $targetUrl = 'https://api.redtube.com/?data=redtube.Videos.searchVideos&search=' . urlencode($query) . '&thumbsize=medium&page=' . $page . '&limit=40';
        } elseif (!empty($category)) {
            $targetUrl = 'https://api.redtube.com/?data=redtube.Videos.searchVideos&search=&category=' . urlencode($category) . '&thumbsize=medium&page=' . $page . '&limit=40';
        } else {
            $targetUrl = 'https://api.redtube.com/?data=redtube.Videos.searchVideos&search=&ordering=newest&thumbsize=medium&page=' . $page . '&limit=40';
        }

        $json = getCurl($targetUrl);
        $items = $json !== '' ? parseRedtubeApi($json) : [];

        $out = [
            'status' => 'success',
            'page' => $page,
            'query' => $query,
            'category' => $category,
            'items' => $items
        ];
        if (isset($_GET['debug'])) {
            $out['debug'] = [
                'api_url' => $targetUrl,
                'json_len' => strlen($json ?? ''),
                'head' => substr(preg_replace('/\s+/', ' ', $json ?? ''), 0, 160)
            ];
        }
        echo json_encode($out);
        exit;
    }

    // -------------------------------------------------------------
    // SOURCE: SPANKBANG (server-rendered video-item cards)
    // Homepage, /{cat}/ and /s/{q}/ all share data-testid="video-item"
    // markup. Playable streams are time-token HLS resolved in resolve_item.
    // -------------------------------------------------------------
    if ($source === 'spankbang') {
        $category = isset($_GET['category']) ? trim($_GET['category']) : '';
        if (!empty($query)) {
            $targetUrl = "https://spankbang.com/s/" . rawurlencode($query) . "/";
            if ($page > 1) $targetUrl .= "?page={$page}";
        } elseif (!empty($category)) {
            // Category browsing moved to /s/{slug}/ (search-style URLs).
            $targetUrl = "https://spankbang.com/s/" . rawurlencode($category) . "/";
            if ($page > 1) $targetUrl .= "?page={$page}";
        } else {
            $targetUrl = "https://spankbang.com/";
            if ($page > 1) $targetUrl .= "?page={$page}";
        }

        $html = fetchPornSource($targetUrl, 'spankbang.com', 'video-item');
        $items = $html !== '' ? parseSpankbangCards($html) : [];

        $out = [
            'status' => 'success',
            'page' => $page,
            'query' => $query,
            'category' => $category,
            'items' => $items
        ];
        if (isset($_GET['debug'])) {
            $out['debug'] = [
                'html_len' => strlen($html ?? ''),
                'jina' => isset($GLOBALS['__jina_last']) ? $GLOBALS['__jina_last'] : null,
                'head' => substr(preg_replace('/\s+/', ' ', $html ?? ''), 0, 220)
            ];
        }
        echo json_encode($out);
        exit;
    }
}

if ($action === 'resolve_item') {
    $detailUrl = isset($_GET['url']) ? $_GET['url'] : '';
    if (empty($detailUrl)) {
        echo json_encode(['status' => 'error', 'message' => 'Missing detail URL']);
        exit;
    }

    $isXvideos = (strpos($detailUrl, 'xvideos') !== false || strpos($detailUrl, 'xv-cdn') !== false);
    $uaUsed = 'chrome';
    $html = $isXvideos ? getCurl($detailUrl, 'https://www.xvideos2.com/') : getCurl($detailUrl);
    if ($isXvideos && (empty($html) || strpos($html, '.m3u8') === false)) {
        // Some datacenter IPs get a stripped page with the default UA.
        // Retry with a Googlebot-like UA, which is served the full player page.
        $html = getCurl($detailUrl, 'https://www.xvideos2.com/', 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)');
        $uaUsed = 'googlebot';
    }
    $qualities = [];

    // -------------------------------------------------------------
    // XVIDEOS: resolve HLS master into quality variants (360p/480p/...)
    // -------------------------------------------------------------
    if ($isXvideos) {
        $masterUrl = '';
        if (preg_match('#https?://hls[^"\x27\s<>]*\.m3u8(?:\?[^"\x27\s<>]*)?#i', $html, $h)) {
            $masterUrl = trim($h[0]);
        }
        if (empty($masterUrl) && preg_match('#https?://[^\s"\x27<>]+\.m3u8(?:\?[^"\x27\s<>]*)?#i', $html, $h)) {
            $masterUrl = trim($h[0]);
        }
        $sdMp4 = '';
        if (preg_match('#https?://mp4[^"\x27\s<>]*\.mp4(?:\?[^"\x27\s<>]*)?#i', $html, $m3)) {
            $sdMp4 = trim($m3[0]);
        }
        if (empty($sdMp4) && preg_match('#https?://[^\s"\x27<>]+\.mp4(?:\?[^"\x27\s<>]*)?#i', $html, $m3)) {
            $sdMp4 = trim($m3[0]);
        }

        if (!empty($masterUrl)) {
            $pl = getCurl($masterUrl, 'https://www.xvideos2.com/');
            $base = substr($masterUrl, 0, strrpos($masterUrl, '/') + 1);
            if (!empty($pl) && preg_match_all('#EXT-X-STREAM-INF:[^\r\n]*RESOLUTION=[0-9]+x([0-9]+)[^\r\n]*\r?\n\s*([^\r\n]+)#i', $pl, $pm, PREG_SET_ORDER)) {
                foreach ($pm as $pv) {
                    $res = intval($pv[1]);
                    $line = trim($pv[2]);
                    if (empty($line) || strpos($line, '#') === 0) continue;
                    if (strpos($line, 'http') !== 0) $line = $base . $line;
                    $label = $res >= 720 ? ($res . 'p HD') : ($res . 'p');
                    $qualities[$label] = $line;
                }
                uksort($qualities, function ($a, $b) {
                    $na = (int) preg_replace('/[^0-9]/', '', $a);
                    $nb = (int) preg_replace('/[^0-9]/', '', $b);
                    return $nb <=> $na;
                });
            } else {
                // Server cannot reach the CDN to verify/parse the master playlist.
                // Pass it straight through - the app player/downloader resolves it
                // client-side (tokens are not IP-bound, verified via SD MP4 playback).
                $qualities['480p HLS'] = $masterUrl;
            }
        }

        // Always offer the direct SD MP4 as an additional (download-friendly) quality
        if (!empty($sdMp4)) {
            $qualities['SD MP4'] = $sdMp4;
        }

        if (!empty($qualities)) {
            $out = [
                'status' => 'success',
                'qualities' => $qualities
            ];
            // Server-driven HTTP headers the app must send when playing/downloading
            // these streams. Lets new sites be added without an app update: the
            // client just forwards whatever Referer/Origin the resolver declares.
            if ($isXvideos) {
                $out['headers'] = [
                    'Referer' => 'https://www.xvideos2.com/',
                    'Origin' => 'https://www.xvideos2.com'
                ];
            }
            if (isset($_GET['debug'])) {
                $out['debug'] = [
                    'ua' => $uaUsed,
                    'html_len' => strlen($html),
                    'master_url' => $masterUrl,
                    'master_len' => isset($pl) ? strlen($pl) : 0,
                    'mp4' => $sdMp4
                ];
            }
            echo json_encode($out);
            exit;
        }
    }

    // -------------------------------------------------------------
    // REDTUBE: player page embeds mediaDefinitions tokens for /media/hls?
    // and /media/mp4?. Each token endpoint returns a JSON array of
    // {format, quality/height, videoUrl} entries (time-signed CDN links,
    // NOT IP-bound), so per-quality HLS + direct MP4 are resolved
    // server-side without a separate CDN call.
    // -------------------------------------------------------------
    if (strpos($detailUrl, 'redtube') !== false) {
        // Player config: the www.redtube.com page is age-gated, but the embed
        // player (embed.redtube.com/?id=<videoId>) leaks the SAME mediaDefinitions
        // JSON with zero challenge. Extract the numeric id from the detail URL.
        $videoId = '';
        if (preg_match('#/(\d+)(?:[/?]|$)#', $detailUrl, $idm)) {
            $videoId = $idm[1];
        }
        $html = '';
        if (!empty($videoId)) {
            $html = getCurl('https://embed.redtube.com/?id=' . $videoId);
        }
        // Fallback: the age-gated page (jina -> direct) as a last resort.
        if (empty($html) || strpos($html, 'mediaDefinitions') === false) {
            $html = fetchPornSource($detailUrl, 'www.redtube.com', 'mediaDefinitions', [], true);
        }
        // Player config is now embedded in escaped JSON (\/media\/hls?s=...).
        // Unescape before the token regex so both old plain and new escaped
        // slash forms match.
        $html = str_replace('\\/', '/', $html);
        $tokens = [];
        if (!empty($html) && preg_match_all('#\\/media\\/(hls|mp4)\\?s=([A-Za-z0-9._\-]{10,})#', $html, $tm, PREG_SET_ORDER)) {
            foreach ($tm as $tv) {
                if (!isset($tokens[$tv[1]])) {
                    $tokens[$tv[1]] = $tv[2];
                }
            }
        }

        // Decode one token endpoint into qualities ({label} => videoUrl).
        // Prefer the "quality" field (240/360/480/720/1080); fall back to
        // deriving the label from the height/width fields.
        $redtubeDecode = function ($json) {
            $map = [];
            if (empty($json)) return $map;
            $cleanJson = html_entity_decode(stripslashes($json));
            $data = json_decode($cleanJson, true);
            if (!is_array($data)) {
                $data = json_decode($json, true);
            }
            if (!is_array($data)) return $map;
            foreach ($data as $e) {
                if (!is_array($e) || empty($e['videoUrl'])) continue;
                $url = $e['videoUrl'];
                $q = isset($e['quality']) ? trim((string) $e['quality']) : '';
                $lowerUrl = strtolower($url);
                if (strtolower($q) === 'preview' || strpos($lowerUrl, 'preview') !== false || strpos($lowerUrl, 'teaser') !== false || strpos($lowerUrl, '10s') !== false) {
                    continue;
                }
                if (strpos($url, '//') === 0) $url = 'https:' . $url;
                if ($q !== '' && is_numeric($q)) {
                    $label = ($q >= 4096) ? '4K' : ($q . 'p');
                } elseif (preg_match('#/(\d{3,4})P_\d+K_#i', $url, $fm)) {
                    $q = intval($fm[1]);
                    $label = ($q >= 4096) ? '4K' : ($q . 'p');
                } else {
                    $h = isset($e['height']) ? intval($e['height']) : 0;
                    $w = isset($e['width']) ? intval($e['width']) : 0;
                    $res = max($h, $w > $h ? intval(round($w * 0.56)) : 0);
                    if ($res >= 1000) $label = '1080p';
                    elseif ($res >= 700) $label = '720p';
                    elseif ($res >= 450) $label = '480p';
                    elseif ($res >= 300) $label = '360p';
                    else $label = $res > 0 ? ($res . 'p') : 'HD';
                }
                $map[$label] = $url;
            }
            return $map;
        };

        if (!empty($tokens['hls'])) {
            // Token is base64url (A-Za-z0-9._-) — URL-safe raw, keep as-is.
            $hlsJson = fetchRedtubeTokenJson('hls', $tokens['hls']);
            if (!empty($hlsJson)) {
                foreach ($redtubeDecode($hlsJson) as $label => $url) {
                    $qualities[$label . ' HLS'] = $url;
                }
            }
        }
        if (!empty($tokens['mp4'])) {
            $mp4Json = fetchRedtubeTokenJson('mp4', $tokens['mp4']);
            if (!empty($mp4Json)) {
                foreach ($redtubeDecode($mp4Json) as $label => $url) {
                    $qualities[$label] = $url;
                }
            }
        }

        if (!empty($qualities)) {
            uksort($qualities, function ($a, $b) {
                $na = (int) preg_replace('/[^0-9]/', '', $a);
                $nb = (int) preg_replace('/[^0-9]/', '', $b);
                return $nb <=> $na;
            });
            echo json_encode([
                'status' => 'success',
                'qualities' => $qualities,
                'headers' => [
                    'Referer' => 'https://www.redtube.com/',
                    'Origin' => 'https://www.redtube.com'
                ]
            ]);
            exit;
        }
        if (isset($_GET['debug'])) {
            echo json_encode([
                'status' => 'error',
                'message' => 'RedTube resolve failed',
                'debug' => [
                    'host' => 'www.redtube.com',
                    'html_len' => strlen($html ?? ''),
                    'jina' => isset($GLOBALS['__jina_last']) ? $GLOBALS['__jina_last'] : null,
                    'has_mediaDefinitions' => $html !== null && strpos($html, 'mediaDefinitions') !== false,
                    'tokens' => array_keys($tokens),
                    'hls_json_len' => isset($hlsJson) ? strlen($hlsJson) : 0,
                    'mp4_json_len' => isset($mp4Json) ? strlen($mp4Json) : 0,
                    'hls_json_sample' => isset($hlsJson) ? substr($hlsJson, 0, 500) : '',
                    'head' => substr(preg_replace('/\s+/', ' ', $html ?? ''), 0, 200)
                ]
            ]);
            exit;
        }
    }

    // -------------------------------------------------------------
    // SPANKBANG: the video page config exposes per-quality HLS masters via
    // 'm3u8_240p'/'m3u8_480p'/... keys (time-token, not IP-bound) plus a
    // combined 'm3u8' master. When only the combined master is present, the
    // quality list is inside the URL itself (hls/.../{id}-,480p,240p,.mp4.
    // urlset/master.m3u8), so per-quality URLs are derived by substituting
    // the variant list. Some cards also carry direct 'sd'/'hd' mp4 entries.
    // -------------------------------------------------------------
    if (strpos($detailUrl, 'spankbang') !== false) {
        $html = fetchPornSource($detailUrl, 'spankbang.com', 'm3u8', [], true);
        if (!empty($html)) {
            // Per-quality masters first (most reliable).
            if (preg_match_all("#'m3u8_(\d+)p':\s*\['([^']+\.m3u8[^']*)'\]#", $html, $qm, PREG_SET_ORDER)) {
                foreach ($qm as $qmv) {
                    $res = intval($qmv[1]);
                    if ($res > 0) {
                        $label = $res >= 2160 ? '4K' : ($res . 'p');
                        $qualities[$label . ' HLS'] = trim($qmv[2]);
                    }
                }
            }
            // Fallback: derive single-quality URLs from the combined master.
            // The variant list lives inside the URL itself:
            //   hls/{a}/{b}/{tid}-,240p,480p,.mp4.urlset/master.m3u8?...secure=...
            // so we rebuild the URL keeping only one variant at a time.
            if (empty($qualities) && preg_match("#'m3u8':\s*\['([^']+\.m3u8[^']*)'\]#", $html, $cv)) {
                $combined = trim($cv[1]);
                if (preg_match('#^(https?://hls[^/]+/hls/)([^"]*?/)(\d+)-,([0-9a-z,]+)(,\.mp4\.urlset/master\.m3u8.*)$#i', $combined, $cm)) {
                    $variants = array_filter(explode(',', $cm[4]));
                    foreach ($variants as $vq) {
                        if (!preg_match('/^(\d+)p$/', $vq, $vm)) continue;
                        $label = intval($vm[1]) >= 2160 ? '4K' : ($vm[1] . 'p');
                        $qualities[$label . ' HLS'] = $cm[1] . $cm[2] . $cm[3] . '-,' . $vq . $cm[5];
                    }
                }
                if (empty($qualities)) {
                    $qualities['HLS'] = $combined;
                }
            }
            // Optional direct MP4 entries in the config.
            if (preg_match_all("#'mp4(?:_\d+p)?':\s*\[([^]]*)\]#", $html, $dm, PREG_SET_ORDER)) {
                foreach ($dm as $dv) {
                    if (preg_match_all('#(https?://[^\s"\'<>]+\.mp4(?:\\?[^\s"\'<>]*)?)#i', $dv[1], $du)) {
                        foreach ($du[1] as $idx => $mp4url) {
                            $mp4url = trim($mp4url);
                            if (empty($mp4url)) continue;
                            $label = 'Direct MP4' . ($idx > 0 ? ' ' . ($idx + 1) : '');
                            if (!isset($qualities[$label])) {
                                $qualities[$label] = $mp4url;
                            }
                        }
                    }
                }
            }
        }

        if (!empty($qualities)) {
            uksort($qualities, function ($a, $b) {
                $na = (int) preg_replace('/[^0-9]/', '', $a);
                $nb = (int) preg_replace('/[^0-9]/', '', $b);
                return $nb <=> $na;
            });
            echo json_encode([
                'status' => 'success',
                'qualities' => $qualities,
                'headers' => [
                    'Referer' => 'https://spankbang.com/',
                    'Origin' => 'https://spankbang.com'
                ]
            ]);
            exit;
        }
        if (isset($_GET['debug'])) {
            echo json_encode([
                'status' => 'error',
                'message' => 'SpankBang resolve failed',
                'debug' => [
                    'host' => 'spankbang.com',
                    'html_len' => strlen($html ?? ''),
                    'jina' => isset($GLOBALS['__jina_last']) ? $GLOBALS['__jina_last'] : null,
                    'has_m3u8_keys' => $html !== null && strpos($html, "m3u8_") !== false,
                    'head' => substr(preg_replace('/\s+/', ' ', $html ?? ''), 0, 200)
                ]
            ]);
            exit;
        }
    }

    // 0. TNAFLIX: video page <source size="NNN"> qualities. Fetched with the
    //    pinned resolver because tnaflix.com is DNS-poisoned in some regions.
    if (strpos($detailUrl, 'tnaflix') !== false) {
        $html = getCurlTnaflix($detailUrl, '<source');
        if (!empty($html)) {
            if (preg_match_all('#<source[^>]+src="([^"]+)"[^>]+type="video/mp4"[^>]+size="(\d+)"#i', $html, $sm, PREG_SET_ORDER)) {
                foreach ($sm as $sv) {
                    $url = trim($sv[1]);
                    $res = intval($sv[2]);
                    if (empty($url)) continue;
                    $label = $res >= 4096 ? '4K' : ($res . 'p');
                    $qualities[$label] = $url;
                }
            }
            if (empty($qualities) && preg_match_all('#<source[^>]+src="([^"]+)"[^>]+type="video/mp4"#i', $html, $sm2)) {
                foreach ($sm2[1] as $url) {
                    $url = trim($url);
                    if (!empty($url)) {
                        $qualities['Direct MP4'] = $url;
                    }
                }
            }
        }
        if (!empty($qualities)) {
            echo json_encode([
                'status' => 'success',
                'qualities' => $qualities,
                'headers' => [
                    'Referer' => 'https://www.tnaflix.com/',
                    'Origin' => 'https://www.tnaflix.com'
                ]
            ]);
            exit;
        }
    }

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
        $out = ['status' => 'error', 'message' => 'Could not resolve playable media links'];
        if (isset($_GET['debug'])) {
            $out['debug'] = [
                'url' => $detailUrl,
                'target_branch' => strpos($detailUrl, 'redtube') !== false ? 'redtube' : (strpos($detailUrl, 'spankbang') !== false ? 'spankbang' : (strpos($detailUrl, 'tnaflix') !== false ? 'tnaflix' : 'other')),
                'is_xvideos' => $isXvideos,
                'html_len' => strlen($html ?? ''),
                'head' => substr(preg_replace('/\s+/', ' ', $html ?? ''), 0, 160)
            ];
        }
        echo json_encode($out);
        exit;
    }

    echo json_encode([
        'status' => 'success',
        'qualities' => $qualities
    ]);
    exit;
}

if ($action === 'diag') {
    @set_time_limit(120);
    $out = [
        'status' => 'success',
        'php' => [
            'curl' => function_exists('curl_init'),
            'allow_url_fopen' => ini_get('allow_url_fopen'),
            'jina_key' => (defined('JINA_API_KEY') && !empty(JINA_API_KEY)) ? 'set' : 'empty'
        ],
        'jina_tests' => [],
        'direct_tests' => []
    ];
    $targets = [
        ['name' => 'jina-example', 'url' => 'https://example.com', 'needle' => 'Example Domain', 'host' => ''],
        ['name' => 'spankbang-grid', 'url' => 'https://spankbang.com/s/milf/', 'needle' => 'video-item', 'host' => 'spankbang.com'],
        ['name' => 'spankbang-video', 'url' => 'https://spankbang.com/a50mv/video/girlsway+new+girl+gets+her+leotard+peeled+off+her+tight+pussy+licked+by+the+entire+workout+class', 'needle' => 'm3u8', 'host' => 'spankbang.com'],
        ['name' => 'redtube-api', 'url' => 'https://api.redtube.com/?data=redtube.Videos.searchVideos&search=milf&thumbsize=medium&limit=5', 'needle' => '"video"', 'host' => 'api.redtube.com'],
        ['name' => 'redtube-embed', 'url' => 'https://embed.redtube.com/?id=264550271', 'needle' => 'mediaDefinitions', 'host' => 'embed.redtube.com'],
        ['name' => 'redtube-video', 'url' => 'https://www.redtube.com/264550271', 'needle' => 'mediaDefinitions', 'host' => 'www.redtube.com'],
        ['name' => 'xkcd-plain', 'url' => 'https://xkcd.com/1930/', 'needle' => 'xkcd', 'host' => 'xkcd.com'],
    ];

    // Jina path (shows whether the jina proxy is usable at all from this IP).
    foreach ($targets as $t) {
        $j = getViaJina($t['url'], '', true);
        $out['jina_tests'][] = [
            'name' => $t['name'],
            'jina' => isset($GLOBALS['__jina_last']) ? $GLOBALS['__jina_last'] : null,
            'needle' => $t['needle'],
            'needle_hits' => ($j === '') ? 0 : substr_count($j, $t['needle'])
        ];
    }

    // Direct path: plain getCurl + DoH-pinned getCurlPinned for each target.
    foreach ($targets as $t) {
        $plain = getCurl($t['url']);
        $plainInfo = [
            'len' => is_string($plain) ? strlen($plain) : 0,
            'needle_hits' => (is_string($plain) && $plain !== '') ? substr_count($plain, $t['needle']) : 0,
            'head' => (is_string($plain) && $plain !== '') ? substr(preg_replace('/\s+/', ' ', trim($plain)), 0, 160) : ''
        ];
        $pinned = '';
        if (!empty($t['host'])) {
            $pinned = getCurlPinned($t['url'], $t['host'], $t['needle']);
        }
        $out['direct_tests'][] = [
            'name' => $t['name'],
            'getCurl' => $plainInfo,
            'getCurlPinned_len' => is_string($pinned) ? strlen($pinned) : 0,
            'getCurlPinned_needle_hits' => (is_string($pinned) && $pinned !== '') ? substr_count($pinned, $t['needle']) : 0
        ];
    }
    echo json_encode($out);
    exit;
}

echo json_encode(['status' => 'error', 'message' => 'Invalid action']);
