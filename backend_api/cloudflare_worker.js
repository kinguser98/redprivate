/**
 * Cloudflare Worker: 100% Free Reverse Proxy & Deep Link Launcher
 * 
 * Features:
 * 1. 100% Masks your origin backend server (Zero server URL exposed).
 * 2. Instant Deep Link trigger to Red App (redapp://watch?type=...&id=...).
 * 3. Modern Dark-Mode OTT Fallback page with "OPEN IN RED APP" button.
 * 4. Proxies poster and stream data from your backend invisibly.
 */

const ORIGIN_BACKEND = "https://red.goprivate.fun";

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // 1. Handle API proxy if requested: /api/... -> ORIGIN/api/...
    if (url.pathname.startsWith("/api/")) {
      const upstream = ORIGIN_BACKEND + url.pathname + url.search;
      return fetch(upstream, {
        method: request.method,
        headers: request.headers,
        body: request.method === "GET" ? undefined : request.body,
      });
    }

    // 2. Handle Deep Link Watch Page: /watch?type=series&id=123 or /series/123 or /movie/123
    let type = url.searchParams.get("type") || "series";
    let id = url.searchParams.get("id");

    if (!id) {
      const parts = url.pathname.split("/").filter(Boolean);
      if (parts.length >= 2) {
        if (parts[0] === "series" || parts[0] === "movie") {
          type = parts[0];
          id = parts[1];
        }
      } else if (parts.length === 1 && !isNaN(parts[0])) {
        id = parts[0];
      }
    }

    id = id ? parseInt(id, 10) : 0;
    if (!id || id <= 0) {
      return new Response("Red App Deep Link Hub Active", {
        headers: { "content-type": "text/plain;charset=UTF-8" }
      });
    }

    const appScheme = `redapp://watch?type=${encodeURIComponent(type)}&id=${id}`;

    // Optionally fetch item info invisibly from origin backend for rich preview
    let title = "Red App Title";
    let poster = "";
    try {
      const metaRes = await fetch(`${ORIGIN_BACKEND}/api/watch.php?type=${type}&id=${id}&json=1`, {
        cf: { cacheTtl: 300 }
      });
      if (metaRes.ok) {
        const meta = await metaRes.json();
        if (meta && meta.title) {
          title = meta.title;
          poster = meta.poster || "";
        }
      }
    } catch (_) {}

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <title>${title} - Red App</title>
    <meta property="og:title" content="${title}">
    <meta property="og:description" content="Watch online in HD on Red App">
    ${poster ? `<meta property="og:image" content="${poster}">` : ''}
    <script>
      // Immediately launch the app
      window.location.href = "${appScheme}";
    </script>
    <style>
      * { box-sizing: border-box; margin: 0; padding: 0; }
      body {
        background: #090B10;
        color: #fff;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        display: flex;
        align-items: center;
        justify-content: center;
        min-height: 100vh;
        padding: 16px;
      }
      .card {
        background: #121622;
        border: 1px solid rgba(255,255,255,0.08);
        border-radius: 20px;
        max-width: 360px;
        width: 100%;
        padding: 24px;
        text-align: center;
        box-shadow: 0 20px 50px rgba(0,0,0,0.8);
      }
      .poster {
        width: 100%;
        height: 200px;
        border-radius: 14px;
        object-fit: cover;
        margin-bottom: 16px;
        border: 1px solid rgba(255,255,255,0.1);
      }
      .logo {
        font-size: 36px;
        margin-bottom: 8px;
      }
      h1 {
        font-size: 18px;
        font-weight: 700;
        margin-bottom: 6px;
        color: #fff;
      }
      p {
        font-size: 12px;
        color: rgba(255,255,255,0.6);
        margin-bottom: 20px;
        line-height: 1.4;
      }
      .btn {
        display: block;
        width: 100%;
        padding: 14px;
        background: linear-gradient(135deg, #E50914, #B81D24);
        color: #fff;
        text-decoration: none;
        border-radius: 12px;
        font-weight: bold;
        font-size: 14px;
        letter-spacing: 0.5px;
        box-shadow: 0 4px 20px rgba(229, 9, 20, 0.4);
      }
      .footer {
        margin-top: 14px;
        font-size: 11px;
        color: rgba(255,255,255,0.3);
      }
    </style>
</head>
<body>
    <div class="card">
        ${poster ? `<img class="poster" src="${poster}" alt="Poster" />` : '<div class="logo">🍿</div>'}
        <h1>${title}</h1>
        <p>Launching Red App player on your device...</p>
        <a href="${appScheme}" class="btn">🎬 OPEN IN RED APP</a>
        <div class="footer">If nothing happens, tap the button above.</div>
    </div>
</body>
</html>`;

    return new Response(html, {
      headers: {
        "content-type": "text/html;charset=UTF-8",
        "cache-control": "no-cache"
      }
    });
  }
};
