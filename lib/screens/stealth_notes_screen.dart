import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/stealth_service.dart';
import 'auth/login_register_screen.dart';
import 'main_layout_screen.dart';

class NoteItem {
  final String id;
  String title;
  String content;
  String date;
  int colorIndex;

  NoteItem({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.colorIndex = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'date': date,
        'colorIndex': colorIndex,
      };

  factory NoteItem.fromJson(Map<String, dynamic> json) => NoteItem(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: json['title'] ?? '',
        content: json['content'] ?? '',
        date: json['date'] ?? '',
        colorIndex: json['colorIndex'] ?? 0,
      );
}

class StealthNotesScreen extends StatefulWidget {
  const StealthNotesScreen({Key? key}) : super(key: key);

  @override
  State<StealthNotesScreen> createState() => _StealthNotesScreenState();
}

class _StealthNotesScreenState extends State<StealthNotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<NoteItem> _allNotes = [];
  List<NoteItem> _filteredNotes = [];
  String _secretPin = StealthService.defaultPin;
  int _headerSecretTaps = 0;
  Timer? _tapTimer;
  bool _isGridView = true;

  final List<Color> _noteColors = const [
    Color(0xFF23252E), // Dark Slate
    Color(0xFF2C253B), // Soft Purple
    Color(0xFF1E2D38), // Oceanic
    Color(0xFF332B1F), // Warm Amber
    Color(0xFF1F332A), // Forest
  ];

  @override
  void initState() {
    super.initState();
    _loadSecretPin();
    _loadNotes();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tapTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSecretPin() async {
    final pin = await StealthService.getSecretPin();
    if (mounted) setState(() => _secretPin = pin.trim());
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('stealth_user_notes');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List list = jsonDecode(raw);
        setState(() {
          _allNotes = list.map((e) => NoteItem.fromJson(e)).toList();
          _filteredNotes = List.from(_allNotes);
        });
        return;
      } catch (_) {}
    }

    // Default starter sample notes for realistic appearance
    setState(() {
      _allNotes = [
        NoteItem(
          id: '1',
          title: 'Grocery Checklist',
          content: '• Organic Almond Milk\n• Greek Yogurt & Berries\n• Fresh Avocados\n• Dark Chocolate 85%\n• Coffee Beans',
          date: 'Yesterday',
          colorIndex: 3,
        ),
        NoteItem(
          id: '2',
          title: 'Meeting Highlights',
          content: 'Discussed Q4 roadmap targets and performance metrics with design team. Follow-up scheduled for next Tuesday.',
          date: 'Aug 28',
          colorIndex: 1,
        ),
        NoteItem(
          id: '3',
          title: 'Book Recommendations',
          content: '1. Atomic Habits - James Clear\n2. Thinking, Fast and Slow\n3. Deep Work - Cal Newport',
          date: 'Aug 24',
          colorIndex: 2,
        ),
        NoteItem(
          id: '4',
          title: 'Project Ideas 2026',
          content: 'Clean minimalist productivity dashboard with cross-device sync and smart reminders.',
          date: 'Aug 20',
          colorIndex: 0,
        ),
      ];
      _filteredNotes = List.from(_allNotes);
    });
    _saveNotes();
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_allNotes.map((n) => n.toJson()).toList());
    await prefs.setString('stealth_user_notes', raw);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    // Check for secret 3-digit unlock PIN in search bar!
    if (query == _secretPin) {
      _searchController.clear();
      _unlockAndLaunchMainApp();
      return;
    }

    setState(() {
      if (query.isEmpty) {
        _filteredNotes = List.from(_allNotes);
      } else {
        _filteredNotes = _allNotes
            .where((n) =>
                n.title.toLowerCase().contains(query.toLowerCase()) ||
                n.content.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _handleHeaderTap() {
    _headerSecretTaps++;
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 900), () {
      _headerSecretTaps = 0;
    });

    if (_headerSecretTaps >= 3) {
      _headerSecretTaps = 0;
      _showSecretCodePromptDialog();
    }
  }

  void _showSecretCodePromptDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1F26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: Colors.amber, size: 20),
            SizedBox(width: 10),
            Text(
              'Protected Access',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your 3-digit security PIN to unlock:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 3,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 6),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: const Color(0xFF14151B),
                hintText: '•••',
                hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (val) {
                if (val.trim() == _secretPin) {
                  Navigator.pop(ctx);
                  _unlockAndLaunchMainApp();
                } else {
                  HapticFeedback.heavyImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Incorrect PIN code'), duration: Duration(seconds: 2)),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim() == _secretPin) {
                Navigator.pop(ctx);
                _unlockAndLaunchMainApp();
              } else {
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Incorrect PIN code'), duration: Duration(seconds: 2)),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Unlock', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _unlockAndLaunchMainApp() async {
    HapticFeedback.mediumImpact();
    // Fetch user session
    final savedUser = await ApiService.getUserSession();
    if (!mounted) return;

    if (savedUser != null) {
      AppSession.user = savedUser;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, anim, __) => FadeTransition(
            opacity: anim,
            child: MainLayoutScreen(user: savedUser),
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, anim, __) => FadeTransition(
            opacity: anim,
            child: const LoginRegisterScreen(),
          ),
        ),
      );
    }
  }

  void _openNoteEditor([NoteItem? note]) {
    final titleCtrl = TextEditingController(text: note?.title ?? '');
    final contentCtrl = TextEditingController(text: note?.content ?? '');
    int selectedColor = note?.colorIndex ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B1C22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    note == null ? 'New Note' : 'Edit Note',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      if (note != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                          onPressed: () {
                            setState(() {
                              _allNotes.removeWhere((n) => n.id == note.id);
                              _filteredNotes.removeWhere((n) => n.id == note.id);
                            });
                            _saveNotes();
                            Navigator.pop(ctx);
                          },
                        ),
                      ElevatedButton(
                        onPressed: () {
                          final title = titleCtrl.text.trim();
                          final content = contentCtrl.text.trim();
                          if (title.isEmpty && content.isEmpty) {
                            Navigator.pop(ctx);
                            return;
                          }
                          setState(() {
                            if (note == null) {
                              final newNote = NoteItem(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                title: title.isEmpty ? 'Untitled' : title,
                                content: content,
                                date: 'Just now',
                                colorIndex: selectedColor,
                              );
                              _allNotes.insert(0, newNote);
                            } else {
                              note.title = title.isEmpty ? 'Untitled' : title;
                              note.content = content;
                              note.colorIndex = selectedColor;
                              note.date = 'Edited just now';
                            }
                            _filteredNotes = List.from(_allNotes);
                          });
                          _saveNotes();
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Color selector
              Row(
                children: List.generate(_noteColors.length, (idx) {
                  final isSelected = selectedColor == idx;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedColor = idx),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _noteColors[idx],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.amber : Colors.white24,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 16, color: Colors.amber)
                          : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: 'Title',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 17),
                  border: InputBorder.none,
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              TextField(
                controller: contentCtrl,
                maxLines: 8,
                style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                decoration: const InputDecoration(
                  hintText: 'Type your note here...',
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 15),
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14151B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14151B),
        elevation: 0,
        titleSpacing: 20,
        title: GestureDetector(
          onTap: _handleHeaderTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description_rounded, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Notes',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_allNotes.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_agenda_outlined : Icons.grid_view_rounded, color: Colors.white70, size: 21),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar (disguised PIN unlock)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1E2029),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.4), size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // Notes List / Grid
          Expanded(
            child: _filteredNotes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notes_rounded, size: 48, color: Colors.white.withOpacity(0.15)),
                        const SizedBox(height: 12),
                        Text(
                          _searchController.text.isNotEmpty ? 'No matching notes found' : 'No notes yet',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : _isGridView
                    ? GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.95,
                        ),
                        itemCount: _filteredNotes.length,
                        itemBuilder: (ctx, i) => _buildNoteCard(_filteredNotes[i]),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                        itemCount: _filteredNotes.length,
                        itemBuilder: (ctx, i) => _buildNoteListTile(_filteredNotes[i]),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNoteEditor(),
        backgroundColor: Colors.amber.shade700,
        icon: const Icon(Icons.add, color: Colors.black, size: 22),
        label: const Text('New Note', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  Widget _buildNoteCard(NoteItem note) {
    final bg = _noteColors[note.colorIndex % _noteColors.length];
    return GestureDetector(
      onTap: () => _openNoteEditor(note),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                note.content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              note.date,
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteListTile(NoteItem note) {
    final bg = _noteColors[note.colorIndex % _noteColors.length];
    return GestureDetector(
      onTap: () => _openNoteEditor(note),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  note.date,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            if (note.content.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                note.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
