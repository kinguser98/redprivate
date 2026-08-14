import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/scraper_service.dart';
import '../services/headless_capture.dart';

/// On-device resolver for SpankBang.
///
/// spankbang.com is Cloudflare-protected and hard-blocks the backend's
/// datacenter IP (0 bytes / "Just a moment"), so all scraping happens here, on
/// the phone, in a background [HeadlessInAppWebView] where the CF JS challenge
/// auto-solves. Grid cards use `<div data-testid="video-item">` markup and the
/// video page config exposes per-quality `'m3u8_240p'/'m3u8_480p'/...` masters
/// (time-token, playable from the device) plus a combined `'m3u8'` master.
class SpankbangResolver {
  static const String _handler = 'spankbangCapture';

  static const String _base = 'https://spankbang.com/';

  static void _log(String msg) => debugPrint('[SpankbangResolver] $msg');

  static bool isSpankbangUrl(String rawUrl) {
    if (rawUrl.isEmpty) return false;
    return rawUrl.toLowerCase().contains('spankbang');
  }

  static final List<ScraperCategory> categories = [
    ScraperCategory(slug: 'milf', name: 'MILF'),
    ScraperCategory(slug: 'teen', name: 'Teen'),
    ScraperCategory(slug: 'asian', name: 'Asian'),
    ScraperCategory(slug: 'anal', name: 'Anal'),
    ScraperCategory(slug: 'amateur', name: 'Amateur'),
    ScraperCategory(slug: 'blowjob', name: 'Blowjob'),
    ScraperCategory(slug: 'big-ass', name: 'Big Ass'),
    ScraperCategory(slug: 'big-cock', name: 'Big Dick'),
    ScraperCategory(slug: 'big-tits', name: 'Big Tits'),
    ScraperCategory(slug: 'blonde', name: 'Blonde'),
    ScraperCategory(slug: 'brunette', name: 'Brunette'),
    ScraperCategory(slug: 'creampie', name: 'Cream Pie'),
    ScraperCategory(slug: 'cumshot', name: 'Cumshot'),
    ScraperCategory(slug: 'ebony', name: 'Ebony'),
    ScraperCategory(slug: 'gangbang', name: 'Gang Bang'),
    ScraperCategory(slug: 'granny', name: 'Granny'),
    ScraperCategory(slug: 'handjob', name: 'Handjob'),
    ScraperCategory(slug: 'hd-video', name: 'HD'),
    ScraperCategory(slug: 'interracial', name: 'Interracial'),
    ScraperCategory(slug: 'japanese', name: 'Japanese'),
    ScraperCategory(slug: 'lesbian', name: 'Lesbian'),
    ScraperCategory(slug: 'masturbation', name: 'Masturbation'),
    ScraperCategory(slug: 'mature', name: 'Mature'),
    ScraperCategory(slug: 'pov', name: 'POV'),
    ScraperCategory(slug: 'russian', name: 'Russian'),
    ScraperCategory(slug: 'squirt', name: 'Squirt'),
    ScraperCategory(slug: 'threesome', name: 'Threesome'),
    ScraperCategory(slug: 'toys', name: 'Toys'),
    ScraperCategory(slug: 'wife', name: 'Wife'),
  ];

  static String _buildGridUrl({int page = 1, String query = '', String category = ''}) {
    var url = _base;
    if (query.isNotEmpty) {
      url = '${_base}s/${Uri.encodeComponent(query)}/';
      if (page > 1) url += '$page/';
    } else if (category.isNotEmpty) {
      url = '${_base}cat/${Uri.encodeComponent(category)}/';
      if (page > 1) url += '$page/';
    } else {
      url = '${_base}trending_videos/';
      if (page > 1) url += '$page/';
    }
    return url;
  }

  static const String _gridJs = '''
(function() {
  var done = false;
  function send(obj) {
    if (done) return; done = true;
    try { window.flutter_inappwebview.callHandler('SPANGBANG_H', JSON.stringify(obj)); } catch(e) {}
  }
  // Age-gate interstitial ("Confirm to enter"): tap it once if present.
  var gateTried = false;
  function tryGate() {
    if (gateTried) return;
    gateTried = true;
    var el = document.getElementById('age_gate_btn') || document.getElementById('confirm_btn');
    if (!el) {
      var all = document.querySelectorAll('a,button');
      for (var i = 0; i < all.length; i++) {
        try {
          var t = (all[i].textContent || all[i].value || '').toString().toLowerCase();
          if (t.indexOf('over 18') !== -1 || t.indexOf('am 18') !== -1 || (t.indexOf('enter') !== -1 && t.indexOf('confirm') !== -1)) {
            el = all[i]; break;
          }
        } catch(e) {}
      }
    }
    if (el) { try { el.click(); } catch(e) {} }
  }
  function diag() {
    var out = [];
    var as = document.querySelectorAll('a[href]');
    for (var i = 0; i < Math.min(as.length, 30); i++) {
      try {
        var a = as[i];
        var cls = (a.className || '').toString();
        var h = (a.href || '').toString();
        if (h.indexOf('spankbang') === -1 && cls.indexOf('video') === -1) continue;
        out.push(cls.slice(0, 60) + ' || ' + h.slice(0, 90));
      } catch(e) {}
    }
    var body = document.body ? document.body.innerHTML : '';
    return { a: as.length, imgs: document.querySelectorAll('img').length, anchors: out, html: (body || '').replace(/\\s+/g, ' ').substring(0, 1600) };
  }
  var tries = 0;
  var iv = setInterval(function() {
    tries++;
    var out = [];
    var els = document.querySelectorAll('[data-testid="video-item"], .video-item, .v-item, .js-video-item, div.item, a[href*="/video/"]');
    for (var i = 0; i < els.length; i++) {
      try {
        var el = els[i];
        var a = el.tagName.toLowerCase() === 'a' ? el : el.querySelector('a[href*="/video/"], a[href]');
        if (!a) continue;
        var href = a.href || a.getAttribute('href') || '';
        if (!href || (href.indexOf('/video/') === -1 && href.indexOf('video') === -1)) continue;
        if (href.indexOf('http') !== 0) href = 'https://spankbang.com' + (href.indexOf('/') === 0 ? '' : '/') + href;
        var img = el.querySelector('img') || (el.tagName.toLowerCase() === 'img' ? el : null);
        var poster = img ? (img.getAttribute('data-src') || img.getAttribute('data-srcset') || img.getAttribute('data-lazy-src') || img.src || '') : '';
        var title = (a.getAttribute('title') || '').trim();
        if (!title && img) title = (img.getAttribute('alt') || img.getAttribute('title') || '').trim();
        if (!title) {
          var tEl = el.querySelector('.title, .n, .name, a.n');
          if (tEl) title = (tEl.textContent || '').trim();
        }
        if (!title) title = (a.textContent || '').trim();
        var dur = '';
        var d = el.querySelector('[data-testid="video-item-length"], .l, .length, .duration, span.l');
        if (d) dur = (d.textContent || '').replace(/\\s+/g, ' ').trim();
        if (!title || title.length < 3 || !poster) continue;
        out.push([title, href, poster, dur]);
      } catch(e) {}
    }
    if (out.length === 0) tryGate();
    if (out.length > 0 || tries > 40) send({ cards: out, d: diag() });
  }, 500);
  setTimeout(function() { send({ cards: [], d: diag() }); }, 25000);
})();
''';

  /// Fetches the grid (homepage / category / search) on-device.
  static Future<List<ScraperCard>> fetchGrid(
      {int page = 1, String query = '', String category = ''}) async {
    final url = _buildGridUrl(page: page, query: query, category: category);
    _log('fetchGrid url=$url');
    final raw = await HeadlessCapture.capture(
      url,
      _handler,
      _gridJs.replaceFirst('SPANGBANG_H', _handler),
    );
    if (raw == null || raw.isEmpty) {
      _log('fetchGrid raw null/empty');
      return [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final d = decoded['d'];
        if (d is Map) {
          final anchors = (d['anchors'] as List?)?.join(' | ') ?? '';
          final html = (d['html'] ?? '').toString();
          _log('DIAG a=${d['a']} imgs=${d['imgs']} anchors=$anchors html=${html.substring(0, html.length > 800 ? 800 : html.length)}');
        }
        final cardsRaw = decoded['cards'];
        final cardsList = cardsRaw is List ? cardsRaw : <dynamic>[];
        final List<ScraperCard> cards = [];
        final seen = <String>{};
        for (final item in cardsList) {
          if (item is! List || item.length < 3) continue;
          final title = item[0]?.toString() ?? '';
          final link = item[1]?.toString() ?? '';
          final poster = item[2]?.toString() ?? '';
          final duration = item.length > 3 ? (item[3]?.toString() ?? '') : '';
          if (title.isEmpty || poster.isEmpty || link.isEmpty) continue;
          if (!seen.add(link)) continue;
          cards.add(ScraperCard(title: title, link: link, poster: poster, duration: duration));
        }
        _log('fetchGrid cards=${cards.length}');
        return cards;
      }
      _log('fetchGrid decoded=NOT MAP');
      return [];
    } catch (e) {
      print('SpankbangResolver grid parse error: $e');
      return [];
    }
  }

  static const String _resolveJs = '''
(function() {
  var done = false;
  function send(obj) {
    if (done) return; done = true;
    try { window.flutter_inappwebview.callHandler('SPANGBANG_H', JSON.stringify(obj)); } catch(e) {}
  }
  // Age-gate interstitial ("Confirm to enter"): tap it once if present.
  var gateTried = false;
  function tryGate() {
    if (gateTried) return;
    gateTried = true;
    var el = document.getElementById('age_gate_btn') || document.getElementById('confirm_btn');
    if (!el) {
      var all = document.querySelectorAll('a,button');
      for (var i = 0; i < all.length; i++) {
        try {
          var t = (all[i].textContent || all[i].value || '').toString().toLowerCase();
          if (t.indexOf('over 18') !== -1 || t.indexOf('am 18') !== -1 || (t.indexOf('enter') !== -1 && t.indexOf('confirm') !== -1)) {
            el = all[i]; break;
          }
        } catch(e) {}
      }
    }
    if (el) { try { el.click(); } catch(e) {} }
  }
  var tries = 0;
  var iv = setInterval(function() {
    tries++;
    try {
      var html = document.documentElement ? document.documentElement.innerHTML : '';
      var out = [];
      var re = /'(?:m3u8_|stream_url_)?(\\d+p?)'\s*:\s*\\['([^']+\\.(?:m3u8|mp4)[^']*)'\\]/gi;
      var m;
      while ((m = re.exec(html)) !== null) {
        out.push({ q: m[1], u: m[2] });
      }
      var re2 = /"(?:m3u8_|stream_url_)?(\\d+p?)"\s*:\s*\\["([^"]+\\.(?:m3u8|mp4)[^"]*)"\\]/gi;
      while ((m = re2.exec(html)) !== null) {
        out.push({ q: m[1], u: m[2] });
      }
      var re3 = /"stream_url_?(\\d+p?)"\s*:\s*"([^"]+)"/gi;
      while ((m = re3.exec(html)) !== null) {
        out.push({ q: m[1], u: m[2] });
      }
      var combined = '';
      var cm = /'(?:m3u8|stream_url)'\s*:\s*\\['([^']+\\.m3u8[^']*)'\\]/i.exec(html);
      if (!cm) cm = /"(?:m3u8|stream_url)"\s*:\s*\\["([^"]+\\.m3u8[^"]*)"\\]/i.exec(html);
      if (cm) combined = cm[1];
      if (out.length === 0) tryGate();
      if (out.length > 0 || combined !== '' || tries > 50) {
        send({ items: out, combined: combined });
      }
    } catch(e) { if (tries > 50) send({ items: [], combined: '' }); }
  }, 500);
  setTimeout(function() { send({ items: [], combined: '' }); }, 30000);
})();
''';

  /// Resolves the video page config into per-quality HLS links.
  static Future<ScraperResolveResult?> resolveItem(String pageUrl) async {
    if (!isSpankbangUrl(pageUrl)) return null;
    final raw = await HeadlessCapture.capture(
      pageUrl,
      _handler,
      _resolveJs.replaceFirst('SPANGBANG_H', _handler),
    );
    if (raw == null || raw.isEmpty) {
      _log('resolveItem raw null/empty for $pageUrl');
      return null;
    }
    _log('resolveItem raw len=${raw.length}');
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final Map<String, String> qualities = {};

      final items = decoded['items'];
      if (items is List) {
        for (final item in items) {
          if (item is! Map) continue;
          final q = (item['q'] ?? '').toString().trim();
          final u = (item['u'] ?? '').toString().trim();
          final n = int.tryParse(q) ?? 0;
          if (u.isEmpty || n <= 0) continue;
          final label = n >= 2160 ? '4K' : '${n}p';
          qualities.putIfAbsent('$label HLS', () => u);
        }
      }

      final combined = (decoded['combined'] ?? '').toString().trim();
      if (qualities.isEmpty && combined.isNotEmpty) {
        final cm = RegExp(
                r'^(https?://hls[^/]+/hls/)([^"]*?/)(\d+)-,([0-9a-z,]+)(,\.mp4\.urlset/master\.m3u8.*)$',
                caseSensitive: false)
            .firstMatch(combined);
        if (cm != null) {
          final variants = cm.group(4)!.split(',').where((v) => v.isNotEmpty);
          for (final vq in variants) {
            final vm = RegExp(r'^(\d+)p$').firstMatch(vq);
            if (vm == null) continue;
            final n = int.parse(vm.group(1)!);
            final label = n >= 2160 ? '4K' : '${n}p';
            qualities.putIfAbsent(
              '$label HLS',
              () => '${cm.group(1)}${cm.group(2)}${cm.group(3)}-,$vq${cm.group(5)}',
            );
          }
        }
        if (qualities.isEmpty) {
          qualities['HLS'] = combined;
        }
      }

      if (qualities.isEmpty) return null;
      final ordered = <String, String>{};
      final keys = qualities.keys.toList()
        ..sort((a, b) {
          final na = int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '') ?? 0;
          final nb = int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '') ?? 0;
          return nb.compareTo(na);
        });
      for (final k in keys) {
        ordered[k] = qualities[k]!;
      }
      return ScraperResolveResult(
        qualities: ordered,
        headers: {
          'Referer': _base,
          'Origin': _base.replaceFirst(RegExp(r'/$'), ''),
        },
      );
    } catch (e) {
      print('SpankbangResolver resolve parse error: $e');
      return null;
    }
  }
}