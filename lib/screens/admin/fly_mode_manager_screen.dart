import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';

/// Hidden admin panel → Fly Mode Manager.
/// Lets the admin reorder the foreign sites, temporarily hide them, and change
/// their domains when a new mirror comes — all without touching app code.
class FlyModeManagerScreen extends StatefulWidget {
  const FlyModeManagerScreen({super.key});

  @override
  State<FlyModeManagerScreen> createState() => _FlyModeManagerScreenState();
}

class _FlyModeManagerScreenState extends State<FlyModeManagerScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _sources = [];
  final Map<String, TextEditingController> _domainCtrls = {};
  final Map<String, TextEditingController> _nameCtrls = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _domainCtrls.values) {
      c.dispose();
    }
    for (final c in _nameCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<Map<String, dynamic>> _adminPhpApi(
      String action, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(
            Uri.parse(ApiConfig.adminUrl),
            body: json.encode({...body, 'action': action}),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));
      final String raw = res.body.trim();
      if (raw.startsWith('{') && raw.endsWith('}')) {
        return json.decode(raw);
      }
      return {'status': 'error', 'message': 'Server output: $raw'};
    } catch (e) {
      return {'status': 'error', 'message': '$e'};
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await _adminPhpApi('list_scraper_sources', {});
    if (!mounted) return;
    if (res['status'] == 'success' && res['data']?['sources'] != null) {
      final list = (res['data']['sources'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _sources = list;
        _loading = false;
        _rebuildControllers();
      });
    } else {
      setState(() {
        _loading = false;
        _error = res['message']?.toString() ?? 'Failed to load sources';
      });
    }
  }

  void _rebuildControllers() {
    _domainCtrls.clear();
    _nameCtrls.clear();
    for (final s in _sources) {
      final id = s['id'].toString();
      _domainCtrls[id] = TextEditingController(text: s['domain']?.toString() ?? '');
      _nameCtrls[id] = TextEditingController(text: s['name']?.toString() ?? '');
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _sources.removeAt(oldIndex);
      _sources.insert(newIndex, item);
    });
  }

  void _toggleHidden(String id, bool value) {
    setState(() {
      final idx = _sources.indexWhere((s) => s['id'] == id);
      if (idx >= 0) _sources[idx]['is_hidden'] = value ? 1 : 0;
    });
  }

  void _toggleSearch(String id, bool value) {
    setState(() {
      final idx = _sources.indexWhere((s) => s['id'] == id);
      if (idx >= 0) _sources[idx]['search_enabled'] = value ? 1 : 0;
    });
  }

  Future<void> _save() async {
    final payload = <Map<String, dynamic>>[];
    for (int i = 0; i < _sources.length; i++) {
      final s = _sources[i];
      final id = s['id'].toString();
      payload.add({
        'id': id,
        'name': _nameCtrls[id]?.text.trim() ?? s['name'],
        'logo': s['logo']?.toString() ?? '',
        'domain': _domainCtrls[id]?.text.trim() ?? '',
        'search_enabled': s['search_enabled'] ?? 1,
        'is_hidden': s['is_hidden'] ?? 0,
        'sort_order': i + 1,
      });
    }
    final res = await _adminPhpApi('save_scraper_sources', {'sources': payload});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['status'] == 'success'
            ? "Fly Mode sources saved!"
            : "Save failed: ${res['message']}"),
        backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10121A),
        elevation: 0,
        title: const Text(
          "Fly Mode Manager",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.cyanAccent),
            onPressed: _load,
          ),
          TextButton.icon(
            onPressed: _loading ? null : _save,
            icon: const Icon(Icons.save_rounded, color: Colors.greenAccent, size: 18),
            label: const Text("SAVE",
                style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: Colors.white38, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: Colors.white54),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text("Retry")),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      color: const Color(0xFF10121A),
                      child: const Text(
                        "Drag the handle to reorder. Toggle the switch to temporarily hide a site from users. Edit the domain box when a new mirror arrives, then hit SAVE.",
                        style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _sources.length,
                        onReorder: _onReorder,
                        itemBuilder: (ctx, index) {
                          final s = _sources[index];
                          final id = s['id'].toString();
                          final hidden = (s['is_hidden'] ?? 0) == 1;
                          final searchEnabled = (s['search_enabled'] ?? 1) == 1;
                          return Container(
                            key: ValueKey(id),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: hidden
                                  ? const Color(0xFF1A1420)
                                  : const Color(0xFF161B26),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: hidden
                                    ? Colors.redAccent.withOpacity(0.4)
                                    : Colors.white12,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      ReorderableDragStartListener(
                                        index: index,
                                        child: const Padding(
                                          padding: EdgeInsets.only(right: 8),
                                          child: Icon(Icons.drag_handle_rounded,
                                              color: Colors.white38, size: 22),
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            TextField(
                                              controller: _nameCtrls[id],
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                border: InputBorder.none,
                                              ),
                                            ),
                                            Text("#$id  •  order ${index + 1}",
                                                style: TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 11)),
                                          ],
                                        ),
                                      ),
                                      if (hidden)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text("HIDDEN",
                                              style: TextStyle(
                                                  color: Colors.redAccent,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Current domain + edit box
                                  TextField(
                                    controller: _domainCtrls[id],
                                    style: const TextStyle(
                                        color: Colors.cyanAccent,
                                        fontSize: 13,
                                        fontFamily: 'monospace'),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      labelText: "Current Domain",
                                      labelStyle: const TextStyle(
                                          color: Colors.white38, fontSize: 11),
                                      prefixIcon: const Icon(Icons.language_rounded,
                                          color: Colors.cyanAccent, size: 16),
                                      filled: true,
                                      fillColor: const Color(0xFF090A0F),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: Colors.white12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(Icons.visibility_rounded,
                                                color: Colors.white54, size: 15),
                                            const SizedBox(width: 4),
                                            const Text("Visible to users",
                                                style: TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 11)),
                                            const SizedBox(width: 8),
                                            Switch(
                                              value: !hidden,
                                              onChanged: (v) =>
                                                  _toggleHidden(id, !v),
                                              activeColor: Colors.greenAccent,
                                              activeTrackColor:
                                                  Colors.greenAccent.withOpacity(0.3),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.search_rounded,
                                          color: Colors.white38, size: 14),
                                      const SizedBox(width: 4),
                                      Switch(
                                        value: searchEnabled,
                                        onChanged: (v) => _toggleSearch(id, v),
                                        activeColor: Colors.cyanAccent,
                                        activeTrackColor:
                                            Colors.cyanAccent.withOpacity(0.3),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}