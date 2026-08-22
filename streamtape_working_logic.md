# Streamtape Video Playback & Download - Working Logic (Red App)

## Architecture Overview

1. **User taps Play or Download** on a movie or web series episode
2. `video_launcher.dart`'s `playVideo()` or `download_helper.dart`'s `_startDownload()` is called
3. If URL is a direct media file (`.mp4`, `.mkv`, `tapecontent.net`, `archive.org`, `koyeb.app`, etc.) → passes directly to `VideoPlayerScreen` or `DownloadManager`
4. If URL is a Streamtape embed (`tpead.net`, `tapepops.com`, `streamtape.com`, `strcloud.club`, `advtpe.com`) → calls `StreamtapeService.getDirectStreamUrl()` for resolution on the phone
5. If resolution fails → falls back to `EmbedResolver` (headless WebView + PHP backend resolver)
6. Resolved `tapecontent.net` direct URL → passed to `VideoPlayerScreen` or `DownloadManager`

## Streamtape Resolution (`lib/services/streamtape_service.dart`)

**Strategy order:**
1. **Direct API domains** (4 domains with 3 retries each, 8s timeout):
   - `api.strcloud.club`
   - `api.streamtape.com`
   - `api.streamtape.to`
   - `api.streamtape.net`
   - Steps: Get ticket → wait `wait_time` seconds → get download URL
2. **PHP backend fallback**: `http://ott.redapp.space/redapp/api/streamtape_resolver.php?url=...`
3. Both return `tapecontent.net` direct video URLs

**Credentials:**
- Login: `a43e89ab9e67b46b371f`
- Key: `8wykGo0eJkto7yZ`

## DNS Proxy & Routing Rules (`lib/services/dns_proxy.dart`)

- Local proxy starts on `127.0.0.1:<random_port>` in `main.dart`
- `MyHttpOverrides` routes API ticket requests for blocked watch domains through the DoH proxy (`streamtape`, `strcloud`, `tpead.net`, `tapepops.com`, `advtpe.com`)
- **CRITICAL ROUTING RULE**: `tapecontent.net` (direct video content CDN) MUST RETURN `'DIRECT'` in `findProxyFromEnvironment()`. Routing binary stream data through local HTTP `CONNECT` proxy sockets causes `ClientException: Connection closed before full header was received`. Returning `DIRECT` enables `HttpClient` / `DownloadManager` to stream video data directly from the CDN with 0 socket drops and full network speed.
- `media_kit` requests are NOT affected by `HttpOverrides` (libmpv uses its own HTTP stack)

## Streamtape Video Download Architecture (`lib/services/download_service.dart` & `lib/screens/download_helper.dart`)

1. **IP Ticket Matching**: Downloads MUST resolve Streamtape tickets directly on the mobile phone (`StreamtapeService.getDirectStreamUrl` → `EmbedResolver.resolve`). This ensures the ticket IP matches the device's IP address and prevents HTTP 403 Forbidden blocks from `tapecontent.net`.
2. **Single-Threaded Streaming**: Streamtape CDNs (`tapecontent.net`) enforce single-connection downloads per ticket. Multi-threaded range segmenting is disabled for Streamtape URLs to prevent CDN socket termination.
3. **Auto-Ticket Refresh on Expiration**: Stores `originalUrl` in `DownloadTask`. If a Streamtape link returns HTTP 403 or `retry` (ticket expired mid-download or on retry), `_attempt()` automatically calls `StreamtapeService.getDirectStreamUrl(task.originalUrl)` on the mobile phone to obtain a fresh ticket on the device's IP and seamlessly resumes the download without throwing "failed after retries".
4. **No Stream Chunk Timeouts**: Individual video stream chunks in the download loop stream continuously without a 30-second chunk timeout, avoiding premature download failures on large files over mobile connections.
5. **Sequential Chunk Bursting (15 MB Blocks)**: Streamtape CDNs apply bandwidth shaping / rate limiting on continuous long-lived HTTP GET streams after 5-10 seconds (~100-300 KB/s). By requesting sequential finite 15 MB `Range: bytes=start-end` blocks in `_downloadSingle()`, every block initiates a fresh HTTP request that triggers Streamtape's initial unthrottled max burst speed (~10-15 MB/s). This maintains perpetual maximum download speed throughout the entire download without requiring manual pause/resume.

## Video Player (`lib/screens/video_player_screen.dart`)

- Uses `media_kit` (`Player()` + `VideoController()`)
- `PlayerConfiguration(bufferSize: 64 * 1024 * 1024)`
- `player.open(Media(videoUrl), play: true)` — no custom headers
- Non-extension streaming URLs append `#video.mp4` format hint fragment so `media_kit` demuxer identifies MP4 container instantly

## Critical Files

| File | Role |
|------|------|
| `lib/services/streamtape_service.dart` | URL resolution logic |
| `lib/services/dns_proxy.dart` | Local DNS proxy + HttpOverrides (DIRECT for `tapecontent.net`) |
| `lib/services/download_service.dart` | `DownloadManager` single-threaded engine & auto-ticket refresh |
| `lib/screens/download_helper.dart` | Resolves stream links via `StreamtapeService` + `EmbedResolver` fallback |
| `lib/services/embed_resolver.dart` | Headless WebView fallback resolver |
| `lib/screens/video_player_screen.dart` | media_kit native video player |
| `lib/screens/video_launcher.dart` | Routing: playback resolution pipeline |
| `lib/screens/details_screen.dart` | Movie detail screen (_playVideo / handleDownloadAction) |
| `lib/screens/web_series_detail_screen.dart` | Series detail screen (_playEpisode / handleDownloadAction) |
| `backend_api/streamtape_resolver.php` | Server-side PHP resolver |
| `backend_api/admin_api.php` | Admin backend API (full content delete & list operations) |

