import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/scraper_service.dart';
import '../services/headless_capture.dart';

/// On-device resolver for RedTube.
///
/// redtube.com is Cloudflare-protected and serves only a stripped interstitial
/// to datacenter / non-browser clients, so the backend cannot scrape it. These
/// resolvers therefore load the pages in a background [HeadlessInAppWebView]
/// (a real Chrome/WebKit engine) — the JS challenge auto-solves and the full
/// page renders — then extract the cards / mediaDefinitions via injected JS and
/// post the JSON back to Dart. Grids, categories and media resolution all run
/// here, on the phone's residential connection.
class RedtubeResolver {
  static const String _handler = 'redtubeCapture';

  static const String _base = 'https://www.redtube.com/';

  static void _log(String msg) => debugPrint('[RedtubeResolver] $msg');

  static bool isRedtubeUrl(String rawUrl) {
    if (rawUrl.isEmpty) return false;
    return rawUrl.toLowerCase().contains('redtube');
  }

  static final List<ScraperCategory> categories = [
    ScraperCategory(slug: 'milf', name: 'MILF'),
    ScraperCategory(slug: 'teen', name: 'Teen'),
    ScraperCategory(slug: 'anal', name: 'Anal'),
    ScraperCategory(slug: 'asian', name: 'Asian'),
    ScraperCategory(slug: 'blowjob', name: 'Blowjob'),
    ScraperCategory(slug: 'amateur', name: 'Amateur'),
    ScraperCategory(slug: 'big-cock', name: 'Big Dick'),
    ScraperCategory(slug: 'ebony', name: 'Ebony'),
    ScraperCategory(slug: 'latina', name: 'Latina'),
    ScraperCategory(slug: 'lesbian', name: 'Lesbian'),
    ScraperCategory(slug: 'mature', name: 'Mature'),
    ScraperCategory(slug: 'pov', name: 'POV'),
    ScraperCategory(slug: 'russian', name: 'Russian'),
    ScraperCategory(slug: 'creampie', name: 'Cream Pie'),
    ScraperCategory(slug: 'handjob', name: 'Handjob'),
    ScraperCategory(slug: 'interracial', name: 'Interracial'),
    ScraperCategory(slug: 'masturbation', name: 'Masturbation'),
    ScraperCategory(slug: 'solo', name: 'Solo'),
    ScraperCategory(slug: 'squirt', name: 'Squirt'),
    ScraperCategory(slug: 'threesome', name: 'Threesome'),
    ScraperCategory(slug: 'hd-porn', name: 'HD'),
    ScraperCategory(slug: 'cartoon', name: 'Cartoon'),
    ScraperCategory(slug: 'pornstar', name: 'Pornstars'),
    ScraperCategory(slug: 'public', name: 'Public'),
    ScraperCategory(slug: 'small-tits', name: 'Small Tits'),
    ScraperCategory(slug: 'uniform', name: 'Uniform'),
  ];

  static String _buildGridUrl({int page = 1, String query = '', String category = ''}) {
    var url = _base;
    if (query.isNotEmpty) {
      url = '${_base}?search=${Uri.encodeComponent(query)}';
      if (page > 1) url += '&page=$page';
    } else if (category.isNotEmpty) {
      url = '$_base$category';
      if (page > 1) url += '?page=$page';
    } else {
      if (page > 1) url += '?page=$page';
    }
    return url;
  }

  static const String _gridJs = '''
(function() {
  if (window.__rtGridDone) return;
  var done = false;
  function send(obj) {
    if (done) return; done = true;
    try { window.flutter_inappwebview.callHandler('REDTUBE_H', JSON.stringify(obj)); } catch(e) {}
  }
  function diag() {
    var out = [];
    var as = document.querySelectorAll('a[href]');
    for (var i = 0; i < Math.min(as.length, 30); i++) {
      try {
        var a = as[i];
        var cls = (a.className || '').toString();
        var h = (a.href || '').toString();
        if (h.indexOf('redtube') === -1 && cls.indexOf('video') === -1) continue;
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
    var cards = document.querySelectorAll('a.video_link');
    for (var i = 0; i < cards.length; i++) {
      try {
        var a = cards[i];
        var href = a.href || '';
        if (!href || href.indexOf('redtube') === -1) continue;
        var img = a.querySelector('img');
        var poster = a.getAttribute('data-o_thumb') || (img ? (img.getAttribute('data-o_thumb') || img.src || '') : '');
        var title = a.getAttribute('alt') || (img ? (img.getAttribute('alt') || '') : '') || a.getAttribute('title') || '';
        var dur = '';
        var d = a.querySelector('.tm_video_duration, span[class*=duration]');
        if (d) dur = (d.textContent || '').trim();
        if (!title || !poster) continue;
        out.push([title, href, poster, dur]);
      } catch(e) {}
    }
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
      _gridJs.replaceFirst('REDTUBE_H', _handler),
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
      print('RedtubeResolver grid parse error: $e');
      return [];
    }
  }

  static const String _resolveJs = '''
(function() {
  if (window.__rtResolving) return;
  window.__rtResolving = true;
  var done = false;
  function send(arr) {
    if (done) return; done = true;
    try { window.flutter_inappwebview.callHandler('REDTUBE_H', JSON.stringify(arr)); } catch(e) {}
  }
  var tries = 0;
  var iv = setInterval(function() {
    tries++;
    try {
      var md = window.mediaDefinitions || (window.page_params && window.page_params.mediaDefinitions) || (window.player_params && window.player_params.mediaDefinitions) || (window.flashvars && window.flashvars.mediaDefinitions);
      if (!md || !md.length) {
        var html = document.documentElement ? document.documentElement.innerHTML : '';
        var m = /"mediaDefinitions"\s*:\s*(\[\{.*?\}\])/s.exec(html);
        if (m) {
          try { md = JSON.parse(m[1]); } catch(e) {}
        }
      }
      if (md && Object.prototype.toString.call(md) === '[object Array]' && md.length) {
        clearInterval(iv);
        var out = [];
        var pending = 0;
        for (var i = 0; i < md.length; i++) {
          var e = md[i];
          if (!e || !e.videoUrl) continue;
          var u = e.videoUrl;
          if (u.indexOf('http') !== 0) {
            if (u.indexOf('//') === 0) u = 'https:' + u;
            else if (u.indexOf('/') === 0) u = 'https://www.redtube.com' + u;
            else u = 'https://www.redtube.com/' + u;
          }
          if (u.indexOf('/media/') !== -1) {
            pending++;
            (function(endpointUrl, origItem) {
              fetch(endpointUrl, { credentials: 'include' })
                .then(function(r) { return r.json(); })
                .then(function(items) {
                  pending--;
                  if (Array.isArray(items)) {
                    for (var j = 0; j < items.length; j++) {
                      var item = items[j];
                      if (!item || !item.videoUrl) continue;
                      var vu = item.videoUrl;
                      if (vu.indexOf('//') === 0) vu = 'https:' + vu;
                      var q = (item.quality || origItem.quality || '').toString().toLowerCase();
                      if (q === 'preview' || vu.indexOf('preview') !== -1 || vu.indexOf('teaser') !== -1 || vu.indexOf('10s') !== -1) continue;
                      out.push({ q: (item.quality || origItem.quality || '').toString(), f: (item.format || origItem.format || '').toString(), h: (item.height || origItem.height || 0), w: (item.width || origItem.width || 0), u: vu });
                    }
                  }
                  if (pending === 0 && out.length > 0) send(out);
                })
                .catch(function(err) {
                  pending--;
                  if (pending === 0 && out.length > 0) send(out);
                });
            })(u, e);
          } else {
            var q = (e.quality || '').toString().toLowerCase();
            if (q === 'preview' || u.indexOf('preview') !== -1 || u.indexOf('teaser') !== -1 || u.indexOf('10s') !== -1) continue;
            out.push({ q: (e.quality || '').toString(), f: (e.format || '').toString(), h: (e.height || 0), w: (e.width || 0), u: u });
          }
        }
        if (pending === 0 && out.length > 0) send(out);
        return;
      }
      if (tries > 40) {
        clearInterval(iv);
        send([]);
      }
    } catch(e) { if (tries > 40) { clearInterval(iv); send([]); } }
  }, 500);
  setTimeout(function() { send([]); }, 25000);
})();
''';

  /// Resolves the video page's `mediaDefinitions` into per-quality HLS + MP4
  /// links (time-signed CDN URLs, playable from the device).
  static Future<ScraperResolveResult?> resolveItem(String pageUrl) async {
    if (!isRedtubeUrl(pageUrl)) return null;
    final raw = await HeadlessCapture.capture(
      pageUrl,
      _handler,
      _resolveJs.replaceFirst('REDTUBE_H', _handler),
    );
    if (raw == null || raw.isEmpty) {
      _log('resolveItem raw null/empty for $pageUrl');
      return null;
    }
    _log('resolveItem raw len=${raw.length}');
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final Map<String, String> qualities = {};
      for (final item in decoded) {
        try {
          final e = (item as Map).cast<String, dynamic>();
          final url = (e['u'] ?? '').toString();
          if (url.isEmpty) continue;
          final lowerUrl = url.toLowerCase();
          final q = (e['q'] ?? '').toString().toLowerCase();
          if (q == 'preview' || lowerUrl.contains('preview') || lowerUrl.contains('teaser') || lowerUrl.contains('10s')) {
            continue;
          }
          String label = _labelFromEntry(e, url);
          if (label.isEmpty) continue;
          final isHls = (e['f']?.toString() ?? '').toLowerCase() == 'hls' ||
              lowerUrl.contains('.m3u8');
          final key = isHls ? '$label HLS' : label;
          if (!qualities.containsKey(key)) {
            qualities[key] = url;
          }
        } catch (_) {}
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
      print('RedtubeResolver resolve parse error: $e');
      return null;
    }
  }

  static String _labelFromEntry(Map<String, dynamic> e, String url) {
    final q = (e['q'] ?? '').toString().trim();
    if (q.isNotEmpty && num.tryParse(q) != null) {
      final n = int.tryParse(q)!;
      return n >= 4096 ? '4K' : '${n}p';
    }
    final fm = RegExp(r'/(\d{3,4})P_\d+K_', caseSensitive: false).firstMatch(url);
    if (fm != null) {
      final n = int.parse(fm.group(1)!);
      return n >= 4096 ? '4K' : '${n}p';
    }
    final h = int.tryParse((e['h'] ?? 0).toString()) ?? 0;
    final w = int.tryParse((e['w'] ?? 0).toString()) ?? 0;
    final res = h > 0 ? h : (w > 0 ? (w * 0.56).round() : 0);
    if (res >= 1000) return '1080p';
    if (res >= 700) return '720p';
    if (res >= 450) return '480p';
    if (res >= 300) return '360p';
    if (res > 0) return '${res}p';
    return 'HD';
  }
}