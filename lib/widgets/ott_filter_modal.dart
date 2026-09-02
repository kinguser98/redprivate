import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_image_cache.dart';

class OttFilterModal extends StatefulWidget {
  final List<dynamic> ottList;
  final Set<int> selectedOttIds;
  final Function(Set<int> selectedIds, List<String> selectedNames) onApply;

  const OttFilterModal({
    super.key,
    required this.ottList,
    required this.selectedOttIds,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required List<dynamic> ottList,
    required Set<int> selectedOttIds,
    required Function(Set<int> selectedIds, List<String> selectedNames) onApply,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => OttFilterModal(
        ottList: ottList,
        selectedOttIds: selectedOttIds,
        onApply: onApply,
      ),
    );
  }

  @override
  State<OttFilterModal> createState() => _OttFilterModalState();
}

class _OttFilterModalState extends State<OttFilterModal> {
  late Set<int> _tempSelectedIds;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tempSelectedIds = Set<int>.from(widget.selectedOttIds);
  }

  void _toggleOtt(int id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_tempSelectedIds.contains(id)) {
        _tempSelectedIds.remove(id);
      } else {
        _tempSelectedIds.add(id);
      }
    });
  }

  void _clearAll() {
    HapticFeedback.lightImpact();
    setState(() {
      _tempSelectedIds.clear();
    });
  }

  void _apply() {
    HapticFeedback.mediumImpact();
    final names = widget.ottList
        .where((o) => _tempSelectedIds.contains(int.tryParse('${o['id']}') ?? 0))
        .map((o) => (o['name'] ?? '').toString())
        .toList();
    widget.onApply(_tempSelectedIds, names);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = widget.ottList.where((o) {
      final name = (o['name'] ?? '').toString().toLowerCase();
      return _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
    }).toList();

    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0E16).withValues(alpha: 0.94),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white12, width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8E2DE2).withValues(alpha: 0.18),
              blurRadius: 36,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag indicator
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title & Close Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8E2DE2), Color(0xFFE50914)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.tv_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "FILTER BY OTT PLATFORMS",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          _tempSelectedIds.isEmpty
                              ? "Showing all platforms"
                              : "${_tempSelectedIds.length} platform(s) selected",
                          style: TextStyle(
                            color: _tempSelectedIds.isEmpty ? Colors.white54 : const Color(0xFF00E676),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Quick Search in OTT List
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF181B26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: "Search OTT platform...",
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.white38, size: 18),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(height: 14),

              // Grid View of OTTs
              Expanded(
                child: filteredList.isEmpty
                    ? const Center(
                        child: Text(
                          "No platforms found",
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      )
                    : GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.95,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: filteredList.length,
                        itemBuilder: (context, idx) {
                          final o = filteredList[idx];
                          final id = int.tryParse('${o['id']}') ?? 0;
                          final name = (o['name'] ?? '').toString();
                          final logo = (o['icon'] ?? o['logo'] ?? o['image'] ?? '').toString().trim();
                          final isSelected = _tempSelectedIds.contains(id);

                          return InkWell(
                            onTap: () => _toggleOtt(id),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFE50914).withValues(alpha: 0.16)
                                    : const Color(0xFF161924),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFE50914)
                                      : Colors.white.withValues(alpha: 0.08),
                                  width: isSelected ? 1.8 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFE50914).withValues(alpha: 0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // OTT Logo
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: Colors.black38,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: logo.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: logo,
                                                    fit: BoxFit.contain,
                                                    cacheManager: AppImageCache.posters,
                                                    errorWidget: (_, __, ___) => _buildFallbackLogo(name),
                                                  )
                                                : _buildFallbackLogo(name),
                                          ),
                                        ),
                                        const SizedBox(height: 6),

                                        // OTT Name
                                        Text(
                                          name,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : Colors.white70,
                                            fontSize: 11,
                                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Active checkmark badge in top right
                                  if (isSelected)
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE50914),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),

              // Bottom Action Buttons: Clear & Apply / OK
              Row(
                children: [
                  // Clear Button
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _tempSelectedIds.isEmpty ? null : _clearAll,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        disabledForegroundColor: Colors.white24,
                        side: BorderSide(
                          color: _tempSelectedIds.isEmpty ? Colors.white10 : Colors.white24,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        "CLEAR ALL",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Apply / OK Button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE50914),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                      child: Text(
                        _tempSelectedIds.isEmpty
                            ? "SHOW ALL"
                            : "APPLY FILTER (${_tempSelectedIds.length})",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackLogo(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'O',
        style: const TextStyle(
          color: Color(0xFFE50914),
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
    );
  }
}
