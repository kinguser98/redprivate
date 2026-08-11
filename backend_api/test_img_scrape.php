<?php
$query = "avatar poster";
$url = "https://www.google.com/search?q=" . urlencode($query) . "&tbm=isch";

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36');
$html = curl_exec($ch);
curl_close($ch);

// Match all gstatic.com images
preg_match_all('/src="([^"]+gstatic\.com[^"]+)"/', $html, $matches);

print_r($matches[1]);
