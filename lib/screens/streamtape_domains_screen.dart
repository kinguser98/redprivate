import 'package:flutter/material.dart';
import '../services/streamtape_service.dart';
import '../themes/app_colors.dart';

class StreamtapeDomainsScreen extends StatefulWidget {
  const StreamtapeDomainsScreen({Key? key}) : super(key: key);

  @override
  State<StreamtapeDomainsScreen> createState() => _StreamtapeDomainsScreenState();
}

class _StreamtapeDomainsScreenState extends State<StreamtapeDomainsScreen> {
  List<String> _apiDomains = [];
  List<String> _familyDomains = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDomains();
  }

  Future<void> _loadDomains() async {
    setState(() => _loading = true);
    final api = await StreamtapeService.getApiDomains();
    final family = await StreamtapeService.getFamilyDomains();
    setState(() {
      _apiDomains = api;
      _familyDomains = family;
      _loading = false;
    });
  }

  Future<void> _addApiDomainDialog() async {
    final controller = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Add Streamtape API Domain",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "e.g. api.streamtape.xyz",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF12121A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text("ADD", style: TextStyle(color: Colors.white)),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx, text);
              }
            },
          ),
        ],
      ),
    );

    if (added != null && added.isNotEmpty) {
      if (!_apiDomains.contains(added)) {
        final updated = List<String>.from(_apiDomains)..add(added);
        await StreamtapeService.saveApiDomains(updated);
        await _loadDomains();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Added API Domain: $added"), backgroundColor: Colors.green),
          );
        }
      }
    }
  }

  Future<void> _addFamilyDomainDialog() async {
    final controller = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Add Watch / CDN Domain",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "e.g. strcontent.net",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF12121A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text("ADD", style: TextStyle(color: Colors.white)),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx, text);
              }
            },
          ),
        ],
      ),
    );

    if (added != null && added.isNotEmpty) {
      if (!_familyDomains.contains(added)) {
        final updated = List<String>.from(_familyDomains)..add(added);
        await StreamtapeService.saveFamilyDomains(updated);
        await _loadDomains();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Added Watch Domain: $added"), backgroundColor: Colors.green),
          );
        }
      }
    }
  }

  Future<void> _removeApiDomain(String domain) async {
    final updated = List<String>.from(_apiDomains)..remove(domain);
    await StreamtapeService.saveApiDomains(updated);
    await _loadDomains();
  }

  Future<void> _removeFamilyDomain(String domain) async {
    final updated = List<String>.from(_familyDomains)..remove(domain);
    await StreamtapeService.saveFamilyDomains(updated);
    await _loadDomains();
  }

  Future<void> _resetDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Reset Domains?",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Restore default system Streamtape API and watch domains?",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TextButton(
            child: const Text("RESET", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StreamtapeService.resetDomainsToDefault();
      await _loadDomains();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Streamtape domains reset to default!"), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text("Streamtape Domains",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.restore, color: Colors.white),
            tooltip: "Reset to defaults",
            onPressed: _resetDefaults,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Streamtape API & Watch Domains",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Manage active domains used to resolve and stream Streamtape videos. If Streamtape changes its domain, add the new domain below.",
                    style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),

                  // --- API Domains Card ---
                  _buildSectionHeader("Resolution API Domains", Icons.api, _addApiDomainDialog),
                  const SizedBox(height: 10),
                  ..._apiDomains.map((domain) => _buildDomainTile(
                        domain,
                        isDefault: StreamtapeService.defaultApiDomains.contains(domain),
                        onDelete: () => _removeApiDomain(domain),
                      )),

                  const SizedBox(height: 24),

                  // --- Family / Watch Domains Card ---
                  _buildSectionHeader("Watch & CDN Domains", Icons.ondemand_video, _addFamilyDomainDialog),
                  const SizedBox(height: 10),
                  ..._familyDomains.map((domain) => _buildDomainTile(
                        domain,
                        isDefault: StreamtapeService.defaultWatchCdnDomains.contains(domain),
                        onDelete: () => _removeFamilyDomain(domain),
                      )),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, VoidCallback onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent.withOpacity(0.2),
            foregroundColor: AppColors.accent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.add, size: 16),
          label: const Text("ADD DOMAIN", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          onPressed: onAdd,
        ),
      ],
    );
  }

  Widget _buildDomainTile(String domain, {required bool isDefault, required VoidCallback onDelete}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isDefault ? Icons.verified : Icons.link,
                color: isDefault ? Colors.blueAccent : Colors.amberAccent,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                domain,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDefault ? Colors.blue.withOpacity(0.15) : Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDefault ? "DEFAULT" : "CUSTOM",
                  style: TextStyle(
                    color: isDefault ? Colors.blueAccent : Colors.amberAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!isDefault) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
