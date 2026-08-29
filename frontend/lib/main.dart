import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

const String apiUrl = 'http://localhost:5000';

void main() => runApp(const DevVaultApp());

class DevVaultApp extends StatefulWidget {
  const DevVaultApp({super.key});
  @override
  State<DevVaultApp> createState() => _DevVaultAppState();
}

class _DevVaultAppState extends State<DevVaultApp> {
  bool _isDark = true;
  void _toggleTheme() => setState(() => _isDark = !_isDark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevVault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: _isDark ? Brightness.dark : Brightness.light,
        colorSchemeSeed: const Color(0xFFF5C542),
        useMaterial3: true,
      ),
      home: AuthScreen(onThemeToggle: _toggleTheme, isDark: _isDark),
    );
  }
}

// ===================== LOGIN / REGISTER =====================
class AuthScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDark;
  const AuthScreen({super.key, required this.onThemeToggle, required this.isDark});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool busy = false;
  final _u = TextEditingController();
  final _e = TextEditingController();
  final _p = TextEditingController();
  String dept = 'Personal';

  Future<void> submit() async {
    setState(() => busy = true);
    try {
      if (!isLogin) {
        await http.post(Uri.parse('$apiUrl/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': _u.text.trim(),
              'email': _e.text.trim(),
              'password': _p.text,
              'department': dept,
            }));
      }
      final res = await http.post(Uri.parse('$apiUrl/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': _e.text.trim(), 'password': _p.text}));
      final d = jsonDecode(res.body);
      if (res.statusCode == 200) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => HomeScreen(
                    token: d['token'],
                    username: d['user']['username'],
                    department: d['user']['department'] ?? 'Personal',
                    onThemeToggle: widget.onThemeToggle,
                    isDark: widget.isDark)));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(d['error'] ?? 'Failed')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cannot reach server. Is the backend running?')));
    } finally {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onThemeToggle),
      ]),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.isDark
                ? const [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)]
                : [Colors.blue.shade50, Colors.indigo.shade50, Colors.purple.shade50],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.lock_outline, size: 44, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 8),
                  const Text('DevVault', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  Text('Your offline-first knowledge hub', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  const SizedBox(height: 16),
                  if (!isLogin) ...[
                    TextField(
                        controller: _u,
                        decoration: InputDecoration(
                            labelText: 'Username',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: dept,
                      items: const ['Personal', 'CSC', 'ECE', 'MTH', 'PHY', 'BUS']
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) => setState(() => dept = v!),
                      decoration: InputDecoration(
                          labelText: 'Department (optional)',
                          prefixIcon: const Icon(Icons.school),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                      controller: _e,
                      decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 10),
                  TextField(
                      controller: _p,
                      decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                      obscureText: true),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      onPressed: busy ? null : submit,
                      style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: Text(isLogin ? 'LOGIN' : 'CREATE ACCOUNT',
                          style: const TextStyle(fontSize: 15)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: Text(isLogin ? 'New here? Create account' : 'Have an account? Login',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===================== DASHBOARD HOME =====================
class HomeScreen extends StatefulWidget {
  final String token;
  final String username;
  final String department;
  final VoidCallback onThemeToggle;
  final bool isDark;
  const HomeScreen({
    super.key,
    required this.token,
    required this.username,
    required this.department,
    required this.onThemeToggle,
    required this.isDark,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> notes = [];
  List<dynamic> filtered = [];
  List<dynamic> _hall = [];
  List<String> _halls = ['General'];
  String _currentHall = 'General';
  bool loading = true;
  bool _hallLoading = true;
  int _tab = 0;
  final _sc = TextEditingController();
  final AudioPlayer _ap = AudioPlayer();
  Timer? _clock;
  String _now = '';
  final Set<dynamic> _alerted = {};

  List<Map<String, String>> _photos = [];
  List<Map<String, String>> _music = [];
  List<Map<String, String>> _videos = [];
  List<Map<String, String>> _links = [];

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clock = Timer.periodic(const Duration(seconds: 10), (_) {
      setState(() => _updateTime());
      _checkReminders();
    });
    loadNotes();
    _loadHalls();
    _sc.addListener(_filter);
  }

  @override
  void dispose() {
    _clock?.cancel();
    _ap.dispose();
    super.dispose();
  }

  void _updateTime() {
    final d = DateTime.now();
    _now = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _todayString {
    final d = DateTime.now();
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  int get _pinnedCount => notes.where((n) => n['is_pinned'] == 1).length;
  int get _sharedCount => notes.where((n) => n['shared'] == 1).length;

  int get _totalWords {
    int w = 0;
    for (final n in notes) {
      final t = (n['body'] ?? '').toString().trim();
      if (t.isNotEmpty) w += t.split(RegExp(r'\s+')).length;
    }
    return w;
  }

  String get _fabLabel =>
      ['New Note', 'Add Photo', 'Add Music', 'Add Video', 'Add Link', 'New Note'][_tab];

  IconData get _fabIcon => [
        Icons.add,
        Icons.add_photo_alternate,
        Icons.library_music,
        Icons.video_library,
        Icons.add_link,
        Icons.add
      ][_tab];

  String _cleanName(String url) {
    var name = url.split('/').last;
    name = name.replaceFirst(RegExp(r'^\d+_'), '');
    if (name.isEmpty) name = url;
    return Uri.decodeComponent(name);
  }

  String _preview(String bt) {
    final clean = bt.replaceAll(RegExp(r'\[\w+:.*?\]'), '').trim();
    if (clean.isEmpty) return '📎 Media attached';
    return clean.length > 80 ? '${clean.substring(0, 80)}...' : clean;
  }

  String _fmtRemind(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} (${d.day}/${d.month})';
  }

  void _checkReminders() {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final n in notes) {
      final m = RegExp(r'\[REM:(\d+)\]')
          .firstMatch((n['body'] ?? '').toString());
      if (m != null) {
        final ms = int.tryParse(m.group(1)!) ?? 0;
        final id = n['id'];
        if (ms <= now && !_alerted.contains(id)) {
          _alerted.add(id);
          _ap
              .play(UrlSource(
                  'https://actions.google.com/sounds/v1/alarms/alarm_clock.ogg'))
              .catchError((_) {});
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(children: [
                Icon(Icons.alarm, color: Colors.orange, size: 32),
                SizedBox(width: 8),
                Text('Reminder!'),
              ]),
              content: Text(n['title'] ?? 'You have a pending reminder!',
                  style: const TextStyle(fontSize: 16)),
              actions: [
                FilledButton(
                    onPressed: () {
                      _ap.stop();
                      Navigator.pop(context);
                    },
                    child: const Text('Done')),
              ],
            ),
          );
        }
      }
    }
  }

  void _filter() {
    final q = _sc.text.toLowerCase();
    setState(() {
      filtered = notes.where((n) {
        final title = (n['title'] ?? '').toString().toLowerCase();
        final body = (n['body'] ?? '').toString().toLowerCase();
        final tags = RegExp(r'\[TAG:(.*?)\]')
            .allMatches(body)
            .map((m) => m.group(1)!.toLowerCase())
            .join(' ');
        return title.contains(q) || body.contains(q) || tags.contains(q);
      }).toList();
    });
  }

  void _extractMedia() {
    _photos = [];
    _music = [];
    _videos = [];
    _links = [];
    for (final n in notes) {
      final b = (n['body'] ?? '').toString();
      final t = (n['title'] ?? 'Note').toString();
      for (final m in RegExp(r'\[IMG:(.*?)\]').allMatches(b)) {
        _photos.add({'url': m.group(1)!, 'note': t});
      }
      for (final m in RegExp(r'\[MUSIC:(.*?)\]').allMatches(b)) {
        _music.add({'url': m.group(1)!, 'note': t});
      }
      for (final m in RegExp(r'\[AUDIO:(.*?)\]').allMatches(b)) {
        _music.add({'url': m.group(1)!, 'note': t});
      }
      for (final m in RegExp(r'\[VID:(.*?)\]').allMatches(b)) {
        _videos.add({'url': m.group(1)!, 'note': t});
      }
      for (final m in RegExp(r'\[YT:(.*?)\]').allMatches(b)) {
        _videos.add({'url': m.group(1)!, 'note': t});
      }
      for (final m in RegExp(r'\[LINK:(.*?)\]').allMatches(b)) {
        _links.add({'url': m.group(1)!, 'note': t});
      }
    }
  }

  Future<void> loadNotes() async {
    try {
      final res = await http.get(Uri.parse('$apiUrl/notes'),
          headers: {'Authorization': 'Bearer ${widget.token}'});
      if (res.statusCode == 200) {
        setState(() {
          notes = jsonDecode(res.body);
          notes.sort((a, b) {
            final ap = a['is_pinned'] == 1 ? 1 : 0;
            final bp = b['is_pinned'] == 1 ? 1 : 0;
            return bp.compareTo(ap);
          });
          filtered = List.from(notes);
          _extractMedia();
          loading = false;
        });
        _checkReminders();
      }
    } catch (_) {
      setState(() => loading = false);
    }
  }

  Future<void> _loadHalls() async {
    try {
      final res = await http.get(Uri.parse('$apiUrl/halls'),
          headers: {'Authorization': 'Bearer ${widget.token}'});
      if (res.statusCode == 200) {
        setState(() {
          _halls = List<String>.from(jsonDecode(res.body));
          if (_halls.contains(widget.department)) _currentHall = widget.department;
        });
        _loadHall();
      }
    } catch (_) {}
  }

  Future<void> _loadHall() async {
    setState(() => _hallLoading = true);
    try {
      final res = await http.get(
          Uri.parse('$apiUrl/hall?name=${Uri.encodeComponent(_currentHall)}'),
          headers: {'Authorization': 'Bearer ${widget.token}'});
      if (res.statusCode == 200) {
        setState(() {
          _hall = jsonDecode(res.body);
          _hallLoading = false;
        });
      } else {
        setState(() => _hallLoading = false);
      }
    } catch (_) {
      setState(() => _hallLoading = false);
    }
  }

  Future<void> _createHall() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create New Hall 🏛️'),
        content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
                hintText: 'Hall name e.g. CSC 301 Class, Greenfield High SS3')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final res = await http.post(Uri.parse('$apiUrl/halls'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}'
        },
        body: jsonEncode({'name': name}));
    if (res.statusCode == 200) {
      setState(() {
        _halls = List<String>.from(jsonDecode(res.body));
        _currentHall = name;
      });
      _loadHall();
    }
  }

  Future<void> _copyHall(dynamic h) async {
    final res = await http.post(Uri.parse('$apiUrl/copy/${h['id']}'),
        headers: {'Authorization': 'Bearer ${widget.token}'});
    if (res.statusCode == 200) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to your Shared folder! 📁')));
      loadNotes();
    }
  }

  Future<void> _forwardNote(dynamic h) async {
    String target = _halls.first;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Forward to Hall ↪️'),
          content: DropdownButtonFormField<String>(
            value: target,
            items: _halls
                .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                .toList(),
            onChanged: (v) => setS(() => target = v!),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final res = await http.post(Uri.parse('$apiUrl/forward/${h['id']}'),
                      headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer ${widget.token}'
                      },
                      body: jsonEncode({'hall': target}));
                  if (res.statusCode == 200) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Forwarded to $target! ↪️')));
                    _loadHall();
                  }
                },
                child: const Text('Forward')),
          ],
        ),
      ),
    );
  }

  void _viewHallNote(dynamic h) {
    final bt = (h['body'] ?? '').toString();
    final clean = bt.replaceAll(RegExp(r'\[\w+:.*?\]'), '').trim();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(h['title'] ?? 'Untitled', style: const TextStyle(fontSize: 18)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('by ${h['owner'] ?? 'Unknown'} • ${h['hall'] ?? ''}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  const SizedBox(height: 12),
                  Text(clean.isEmpty ? '📎 Media note' : clean,
                      style: const TextStyle(fontSize: 14, height: 1.5)),
                ]),
          ),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.forward, color: Color(0xFFF5C542)),
              tooltip: 'Forward to another hall',
              onPressed: () {
                Navigator.pop(context);
                _forwardNote(h);
              }),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          FilledButton.icon(
              onPressed: () => _copyHall(h),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Save to My Notes')),
        ],
      ),
    );
  }

  Future<void> _play(String url) async {
    await _ap.stop();
    await _ap.play(UrlSource(url.startsWith('http') ? url : '$apiUrl$url'));
  }

  void _viewPhoto(String url) {
    final full = url.startsWith('http') ? url : '$apiUrl$url';
    showDialog(
        context: context,
        builder: (_) => Dialog(
              backgroundColor: Colors.black,
              child: Stack(children: [
                Center(
                    child: Image.network(full, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image, color: Colors.grey, size: 64))),
                Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context))),
              ]),
            ));
  }

  Future<void> shareNote(int id) async {
    final res = await http.post(Uri.parse('$apiUrl/share'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}'
        },
        body: jsonEncode({'note_id': id}));
    final d = jsonDecode(res.body);
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(children: [
                Icon(Icons.share, color: Color(0xFFF5C542)),
                SizedBox(width: 8),
                Text('Share Link Ready!'),
              ]),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
                  child: SelectableText('$apiUrl${d['link']}',
                      style: const TextStyle(color: Color(0xFFF5C542))),
                ),
                const SizedBox(height: 12),
                const Text('Anyone with this link can view your note',
                    style: TextStyle(color: Colors.grey)),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
              ],
            ));
  }

  Future<void> togglePin(dynamic n) async {
    await http.put(Uri.parse('$apiUrl/notes/${n['id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}'
        },
        body: jsonEncode({
          'title': n['title'],
          'body': n['body'],
          'is_pinned': n['is_pinned'] != 1,
          'folder_id': n['folder_id'],
          'shared': n['shared'] == 1,
          'folder': n['folder'],
          'hall': n['hall'],
        }));
    loadNotes();
  }

  Future<void> toggleShare(dynamic n) async {
    await http.put(Uri.parse('$apiUrl/notes/${n['id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}'
        },
        body: jsonEncode({
          'title': n['title'],
          'body': n['body'],
          'is_pinned': n['is_pinned'] == 1,
          'folder_id': n['folder_id'],
          'shared': n['shared'] != 1,
          'folder': n['folder'],
          'hall': n['hall'],
        }));
    loadNotes();
    _loadHall();
  }

  Future<void> deleteNote(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await http.delete(Uri.parse('$apiUrl/notes/$id'),
          headers: {'Authorization': 'Bearer ${widget.token}'});
      loadNotes();
    }
  }

  void _logout() {
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => AuthScreen(
                onThemeToggle: widget.onThemeToggle, isDark: widget.isDark)));
  }

  Map<String, bool> _media(String b) {
    return {
      'img': b.contains('[IMG:'),
      'aud': b.contains('[AUDIO:') || b.contains('[MUSIC:'),
      'vid': b.contains('[VID:') || b.contains('[YT:'),
    };
  }

  Widget _statCard(IconData ic, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: widget.isDark ? Colors.grey[900] : Colors.grey[200],
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(ic, color: const Color(0xFFF5C542), size: 24),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ]),
        ]),
      ),
    );
  }

  Widget _emptyMsg(String t, String s) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.inbox_outlined, size: 56, color: Colors.grey[600]),
      const SizedBox(height: 12),
      Text(t, style: TextStyle(color: Colors.grey[400], fontSize: 16)),
      Text(s, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
    ]));
  }

  // ---------- TAB CONTENT ----------

  Widget _notesTab() {
    if (filtered.isEmpty) {
      return _emptyMsg('No notes yet', 'Tap + New Note to create your first note');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final n = filtered[i];
        final pin = n['is_pinned'] == 1;
        final shared = n['shared'] == 1;
        final bt = (n['body'] ?? '').toString();
        final m = _media(bt);
        final rem = RegExp(r'\[REM:(\d+)\]').firstMatch(bt)?.group(1);
        final colorHex = RegExp(r'\[COLOR:(.*?)\]').firstMatch(bt)?.group(1);
        final tags = RegExp(r'\[TAG:(.*?)\]').allMatches(bt).map((x) => x.group(1)!).toList();

        final borderColor = colorHex != null && colorHex.isNotEmpty
            ? Color(int.parse('0x$colorHex'))
            : Colors.transparent;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Dismissible(
            key: Key('note_${n['id']}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (_) async {
              await deleteNote(n['id']);
              return false;
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: borderColor, width: 8)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: pin
                            ? const Color(0xFFF5C542).withOpacity(0.2)
                            : (widget.isDark ? Colors.grey[800] : Colors.grey[200]),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(pin ? Icons.push_pin : Icons.description,
                        color: pin ? const Color(0xFFF5C542) : Colors.grey),
                  ),
                  title: Row(children: [
                    Expanded(
                        child: Text(n['title'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600))),
                    if (shared)
                      const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.school, size: 16, color: Color(0xFFF5C542))),
                    if (pin) const Icon(Icons.push_pin, size: 16, color: Color(0xFFF5C542)),
                  ]),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _preview(bt),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ),
                      if (tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: tags
                                .map((tag) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFF5C542).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8)),
                                      child: Text('#$tag',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFFF5C542))),
                                    ))
                                .toList(),
                          ),
                        ),
                      if (m['img']! || m['aud']! || m['vid']! || rem != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(children: [
                            if (m['img']!)
                              const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Icon(Icons.photo, size: 16, color: Color(0xFFF5C542))),
                            if (m['aud']!)
                              const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Icon(Icons.music_note, size: 16, color: Color(0xFFF5C542))),
                            if (m['vid']!)
                              const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Icon(Icons.videocam, size: 16, color: Color(0xFFF5C542))),
                            if (rem != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.alarm, size: 14, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  Text(_fmtRemind(int.parse(rem)),
                                      style: const TextStyle(fontSize: 11, color: Colors.orange)),
                                ]),
                              ),
                          ]),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'share') shareNote(n['id']);
                      if (v == 'pin') togglePin(n);
                      if (v == 'hall') toggleShare(n);
                      if (v == 'delete') deleteNote(n['id']);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'share',
                          child: Row(children: [
                            Icon(Icons.share, size: 20),
                            SizedBox(width: 8),
                            Text('Share')
                          ])),
                      PopupMenuItem(
                          value: 'pin',
                          child: Row(children: [
                            Icon(pin ? Icons.push_pin : Icons.push_pin_outlined, size: 20),
                            const SizedBox(width: 8),
                            Text(pin ? 'Unpin' : 'Pin')
                          ])),
                      PopupMenuItem(
                          value: 'hall',
                          child: Row(children: [
                            const Icon(Icons.school, size: 20, color: Color(0xFFF5C542)),
                            const SizedBox(width: 8),
                            Text(shared ? 'Remove from Hall' : 'Share to Hall')
                          ])),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red))
                          ])),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => NoteEditor(token: widget.token, note: n)));
                    loadNotes();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _hallTab() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _halls.contains(_currentHall) ? _currentHall : _halls.first,
              items: _halls
                  .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                  .toList(),
              onChanged: (v) {
                setState(() => _currentHall = v!);
                _loadHall();
              },
              decoration: InputDecoration(
                  labelText: 'Browse a Hall',
                  prefixIcon: const Icon(Icons.school),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
              onPressed: _createHall,
              icon: const Icon(Icons.add),
              label: const Text('New Hall')),
        ]),
      ),
      Expanded(
        child: _hallLoading
            ? const Center(child: CircularProgressIndicator())
            : _hall.isEmpty
                ? _emptyMsg('$_currentHall Hall is empty',
                    'Share a note here or create your own hall!')
                : ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                    for (final h in _hall)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                              backgroundColor: const Color(0xFFF5C542),
                              child: Text((h['owner'] ?? '?').toString()[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.black))),
                          title: Text(h['title'] ?? 'Untitled',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('by ${h['owner']} • ${h['department']}',
                              style: const TextStyle(fontSize: 11)),
                          trailing: const Icon(Icons.school, color: Color(0xFFF5C542), size: 18),
                          onTap: () => _viewHallNote(h),
                        ),
                      ),
                  ]),
      ),
    ]);
  }

  Widget _photosTab() {
    if (_photos.isEmpty) return _emptyMsg('No photos yet', 'Tap + Add Photo to add one');
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: _photos.length,
      itemBuilder: (_, i) {
        final url = _photos[i]['url']!;
        final full = url.startsWith('http') ? url : '$apiUrl$url';
        return InkWell(
          onTap: () => _viewPhoto(url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(full, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.broken_image, color: Colors.grey))),
          ),
        );
      },
    );
  }

  Widget _musicTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: widget.isDark ? Colors.grey[900] : Colors.grey[200],
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.radio, color: Color(0xFFF5C542), size: 28),
          const SizedBox(width: 8),
          const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Study Beats', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Built-in lo-fi player', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ])),
          IconButton(
              icon: const Icon(Icons.play_arrow, size: 28),
              onPressed: () => _ap.play(UrlSource(
                  'https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3?filename=lofi-study-112191.mp3'))),
          IconButton(icon: const Icon(Icons.pause, size: 28), onPressed: () => _ap.pause()),
          IconButton(icon: const Icon(Icons.stop, size: 28), onPressed: () => _ap.stop()),
        ]),
      ),
      const SizedBox(height: 20),
      Text('Your Music Library (${_music.length})',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      const SizedBox(height: 8),
      if (_music.isEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 20),
            child: _emptyMsg('No music yet', 'Tap + Add Music to upload a song')),
      for (final m in _music)
        Card(
          child: ListTile(
            leading: const Icon(Icons.play_circle_fill, color: Color(0xFFF5C542), size: 32),
            title: Text(_cleanName(m['url']!), overflow: TextOverflow.ellipsis),
            subtitle: Text('From: ${m['note']}', style: const TextStyle(fontSize: 11)),
            onTap: () => _play(m['url']!),
          ),
        ),
    ]);
  }

  Widget _videosTab() {
    if (_videos.isEmpty) return _emptyMsg('No videos yet', 'Tap + Add Video to add one');
    return ListView(padding: const EdgeInsets.all(16), children: [
      for (final v in _videos)
        Card(
          child: ListTile(
            leading: const Icon(Icons.play_circle_fill, color: Colors.red, size: 32),
            title: Text(
                v['url']!.startsWith('http') ? v['url']! : _cleanName(v['url']!),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
            subtitle: Text('From: ${v['note']}', style: const TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () => launchUrl(
                Uri.parse(v['url']!.startsWith('http') ? v['url']! : '$apiUrl${v['url']}'),
                mode: LaunchMode.externalApplication),
          ),
        ),
    ]);
  }

  Widget _linksTab() {
    if (_links.isEmpty) return _emptyMsg('No links yet', 'Tap + Add Link to save one');
    return ListView(padding: const EdgeInsets.all(16), children: [
      for (final l in _links)
        Card(
          child: ListTile(
            leading: const Icon(Icons.link, color: Color(0xFFF5C542), size: 28),
            title: Text(l['url']!, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
            subtitle: Text('From: ${l['note']}', style: const TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () => launchUrl(Uri.parse(l['url']!), mode: LaunchMode.externalApplication),
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ['Notes', 'Photos', 'Music', 'Videos', 'Links', 'Hall'];
    final icons = [
      Icons.sticky_note_2,
      Icons.photo,
      Icons.music_note,
      Icons.videocam,
      Icons.link,
      Icons.school
    ];
    final views = [
      _notesTab(),
      _photosTab(),
      _musicTab(),
      _videosTab(),
      _linksTab(),
      _hallTab()
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.logout), onPressed: _logout, tooltip: 'Logout'),
        title: const Text('DevVault', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
              icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
              onPressed: widget.onThemeToggle),
          CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(widget.username[0].toUpperCase(),
                  style: const TextStyle(color: Colors.black))),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$_greeting, ${widget.username} 👋',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Row(children: [
              Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text('$_todayString • $_now',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            Row(children: [
              _statCard(Icons.sticky_note_2, '${notes.length}', 'Notes'),
              const SizedBox(width: 8),
              _statCard(Icons.push_pin, '$_pinnedCount', 'Pinned'),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _statCard(Icons.school, '$_sharedCount', 'Shared'),
              const SizedBox(width: 8),
              _statCard(Icons.text_fields, '$_totalWords', 'Words'),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _sc,
            decoration: InputDecoration(
              hintText: 'Search notes or tags...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: widget.isDark ? Colors.grey[900] : Colors.grey[200],
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        SizedBox(
          height: 58,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: tabs.length,
            itemBuilder: (_, i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  selected: _tab == i,
                  onSelected: (_) => setState(() => _tab = i),
                  avatar: Icon(icons[i], size: 22),
                  label: Text(tabs[i], style: const TextStyle(fontSize: 14)),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  selectedColor: const Color(0xFFF5C542),
                  labelStyle: TextStyle(
                      color: _tab == i ? Colors.black : Colors.grey,
                      fontWeight: _tab == i ? FontWeight.bold : FontWeight.normal),
                ),
              );
            },
          ),
        ),
        const Divider(height: 16),
        Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : views[_tab]),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final editorTabs = [0, 1, 2, 3, 5, 0];
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => NoteEditor(
                      token: widget.token, initialTab: editorTabs[_tab])));
          loadNotes();
        },
        icon: Icon(_fabIcon, size: 24),
        label: Text(_fabLabel, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}

// ===================== NOTE EDITOR WITH TABS =====================
class NoteEditor extends StatefulWidget {
  final String token;
  final dynamic note;
  final int initialTab;
  const NoteEditor({super.key, required this.token, this.note, this.initialTab = 0});
  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _ytCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  int _tab = 0;
  bool _code = false;
  bool _shared = false;

  final AudioRecorder _rec = AudioRecorder();
  final AudioPlayer _ap = AudioPlayer();
  final ImagePicker _picker = ImagePicker();
  final SpeechToText _speech = SpeechToText();

  bool _speechReady = false;
  bool _listening = false;
  bool _recording = false;
  String? _audioUrl;
  String _lastWords = '';
  DateTime? _remind;
  String _color = '';
  List<String> _tags = [];
  List<String> _halls = ['General'];
  String _hall = 'General';

  List<String> _imgs = [];
  List<String> _vids = [];
  List<String> _music = [];
  List<String> _links = [];
  String? _yt;
  String _folder = 'General';

  static const _noteColors = [
    '',
    'FFD32F2F',
    'FFF57C00',
    'FFFBC02D',
    'FF388E3C',
    'FF1976D2',
    'FF7B1FA2'
  ];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _initSpeech();
    if (widget.note != null) {
      _title.text = widget.note['title'] ?? '';
      _body.text = widget.note['body'] ?? '';
      _folder = widget.note['folder'] ?? 'General';
      _shared = widget.note['shared'] == 1;
      _hall = widget.note['hall'] ?? 'General';
      _parse();
    }
    _loadHalls();
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ap.dispose();
    _rec.dispose();
    super.dispose();
  }

  Future<void> _loadHalls() async {
    try {
      final res = await http.get(Uri.parse('$apiUrl/halls'),
          headers: {'Authorization': 'Bearer ${widget.token}'});
      if (res.statusCode == 200) {
        setState(() {
          _halls = List<String>.from(jsonDecode(res.body));
          if (!_halls.contains(_hall)) _hall = _halls.first;
        });
      }
    } catch (_) {}
  }

  Future<void> _initSpeech() async {
    _speechReady = await _speech.initialize(
      onError: (_) => setState(() => _listening = false),
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          setState(() => _listening = false);
        }
      },
    );
  }

  String _cleanName(String url) {
    var name = url.split('/').last;
    name = name.replaceFirst(RegExp(r'^\d+_'), '');
    if (name.isEmpty) name = url;
    return Uri.decodeComponent(name);
  }

  String _fmtRemind(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}, ${months[d.month - 1]} ${d.day}';
  }

  Future<void> _pickRemind() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        initialDate: _remind ?? now,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)));
    if (date == null) return;
    final time = await showTimePicker(
        context: context,
        initialTime: _remind != null
            ? TimeOfDay.fromDateTime(_remind!)
            : TimeOfDay.fromDateTime(now.add(const Duration(minutes: 1))));
    if (time == null) return;
    setState(() => _remind = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  void _parse() {
    final b = _body.text;
    _imgs = RegExp(r'\[IMG:(.*?)\]').allMatches(b).map((m) => m.group(1)!).toList();
    _audioUrl = RegExp(r'\[AUDIO:(.*?)\]').firstMatch(b)?.group(1);
    _yt = RegExp(r'\[YT:(.*?)\]').firstMatch(b)?.group(1);
    _vids = RegExp(r'\[VID:(.*?)\]').allMatches(b).map((m) => m.group(1)!).toList();
    _music = RegExp(r'\[MUSIC:(.*?)\]').allMatches(b).map((m) => m.group(1)!).toList();
    _links = RegExp(r'\[LINK:(.*?)\]').allMatches(b).map((m) => m.group(1)!).toList();
    _tags = RegExp(r'\[TAG:(.*?)\]').allMatches(b).map((m) => m.group(1)!).toList();

    final remMs = RegExp(r'\[REM:(\d+)\]').firstMatch(b)?.group(1);
    if (remMs != null) {
      _remind = DateTime.fromMillisecondsSinceEpoch(int.parse(remMs));
    }

    _color = RegExp(r'\[COLOR:(.*?)\]').firstMatch(b)?.group(1) ?? '';

    if (_yt != null) _ytCtrl.text = _yt!;
    _body.text = b
        .replaceAll(
            RegExp(
                r'\[IMG:.*?\]|\[AUDIO:.*?\]|\[YT:.*?\]|\[VID:.*?\]|\[MUSIC:.*?\]|\[LINK:.*?\]|\[REM:\d+?\]|\[COLOR:.*?\]|\[TAG:.*?\]'),
            '')
        .trim();
  }

  String _build() {
    String b = _body.text;
    for (final u in _imgs) {
      b += '\n[IMG:$u]';
    }
    for (final u in _vids) {
      b += '\n[VID:$u]';
    }
    for (final u in _music) {
      b += '\n[MUSIC:$u]';
    }
    for (final u in _links) {
      b += '\n[LINK:$u]';
    }
    for (final t in _tags) {
      b += '\n[TAG:$t]';
    }
    if (_audioUrl != null) b += '\n[AUDIO:$_audioUrl]';
    if (_yt != null && _yt!.isNotEmpty) b += '\n[YT:$_yt]';
    if (_remind != null) b += '\n[REM:${_remind!.millisecondsSinceEpoch}]';
    if (_color.isNotEmpty) b += '\n[COLOR:$_color]';
    return b;
  }

  int get _wc {
    final t = _body.text.trim();
    if (t.isEmpty) return 0;
    return t.split(RegExp(r'\s+')).length;
  }

  void _toggleSpeech() {
    if (_listening) {
      _speech.stop();
      setState(() => _listening = false);
    } else if (_speechReady) {
      setState(() {
        _listening = true;
        _lastWords = '';
      });
      _speech.listen(
        onResult: (r) {
          setState(() {
            _lastWords = r.recognizedWords;
            _body.text = '${_body.text} ${r.recognizedWords}';
          });
        },
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 3),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Speech not available. Try Chrome or the mobile app.')));
    }
  }

  Future<void> _toggleRec() async {
    if (_recording) {
      await _rec.stop();
      setState(() => _recording = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Recording stopped!')));
    } else {
      if (await _rec.hasPermission()) {
        await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: '');
        setState(() => _recording = true);
      }
    }
  }

  Future<void> _play(String url) async {
    await _ap.stop();
    await _ap.play(UrlSource('$apiUrl$url'));
  }

  Future<void> _upload(List<int> bytes, String name, {bool audio = false}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiUrl/upload'))
      ..headers['Authorization'] = 'Bearer ${widget.token}'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: name));
    final res = await req.send();
    if (res.statusCode == 200) {
      final d = jsonDecode(await res.stream.bytesToString());
      setState(() {
        if (audio) {
          _music.add(d['url']);
        } else {
          _vids.add(d['url']);
        }
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${audio ? "Music" : "Video"} uploaded!')));
    }
  }

  Future<void> _pickPhoto() async {
    final p = await _picker.pickImage(source: ImageSource.gallery);
    if (p != null) {
      final bytes = await p.readAsBytes();
      final req = http.MultipartRequest('POST', Uri.parse('$apiUrl/upload'))
        ..headers['Authorization'] = 'Bearer ${widget.token}'
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: p.name));
      final res = await req.send();
      if (res.statusCode == 200) {
        final d = jsonDecode(await res.stream.bytesToString());
        setState(() => _imgs.add(d['url']));
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Photo uploaded!')));
      }
    }
  }

  Future<void> _pickVideo() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.video);
    if (r != null && r.files.first.bytes != null) {
      await _upload(r.files.first.bytes!, r.files.first.name);
    }
  }

  Future<void> _pickMusic() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (r != null && r.files.first.bytes != null) {
      await _upload(r.files.first.bytes!, r.files.first.name, audio: true);
    }
  }

  Future<void> save() async {
    final isEdit = widget.note != null;
    final url = isEdit ? '$apiUrl/notes/${widget.note['id']}' : '$apiUrl/notes';
    final h = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${widget.token}'
    };
    final b = jsonEncode({
      'title': _title.text.isEmpty ? _autoTitle() : _title.text,
      'body': _build(),
      'is_pinned': isEdit ? (widget.note['is_pinned'] == 1) : false,
      'folder_id': null,
      'shared': _shared,
      'folder': _folder,
      'hall': _hall,
    });
    if (isEdit) {
      await http.put(Uri.parse(url), headers: h, body: b);
    } else {
      await http.post(Uri.parse(url), headers: h, body: b);
    }
    Navigator.pop(context);
  }

  String _autoTitle() {
    if (_imgs.isNotEmpty) return 'Photo Note';
    if (_music.isNotEmpty) return 'Music Note';
    if (_vids.isNotEmpty || _yt != null) return 'Video Note';
    if (_links.isNotEmpty) return 'Links Note';
    if (_audioUrl != null) return 'Voice Note';
    return 'Untitled Note';
  }

  Widget _tabNote() {
    return Column(children: [
      TextField(
          controller: _title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(labelText: 'Title', border: InputBorder.none)),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          const Text('Color:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          for (final c in _noteColors) ...[
            InkWell(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                      color: c.isEmpty ? Colors.grey[400] : Color(int.parse('0x$c')),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _color == c ? Colors.white : Colors.transparent, width: 3)),
                  child: c.isEmpty
                      ? const Icon(Icons.format_color_reset, size: 14, color: Colors.white)
                      : null,
                )),
            const SizedBox(width: 6)
          ]
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          const Icon(Icons.school, size: 18, color: Color(0xFFF5C542)),
          const SizedBox(width: 8),
          const Expanded(
              child: Text('Share to Hall', style: TextStyle(fontSize: 13))),
          Switch(
              value: _shared,
              activeColor: const Color(0xFFF5C542),
              onChanged: (v) => setState(() => _shared = v)),
        ]),
      ),
      if (_shared)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            const Text('Post to: ', style: TextStyle(fontSize: 12)),
            DropdownButton<String>(
              value: _halls.contains(_hall) ? _hall : _halls.first,
              items: _halls
                  .map((h) => DropdownMenuItem(
                      value: h, child: Text(h, style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (v) => setState(() => _hall = v!),
              underline: const SizedBox(),
              isDense: true,
            ),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in _tags)
              Chip(
                label: Text('#$t', style: const TextStyle(fontSize: 11)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => setState(() => _tags.remove(t)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _tagCtrl,
                decoration: const InputDecoration(
                    hintText: '+ Tag',
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8)),
                onSubmitted: (v) {
                  if (v.isNotEmpty && !_tags.contains(v)) {
                    setState(() {
                      _tags.add(v.trim().toLowerCase());
                      _tagCtrl.clear();
                    });
                  }
                },
              ),
            )
          ],
        ),
      ),
      Row(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DropdownButton<String>(
            value: _folder,
            items: ['General', 'Shared', 'CSC 301', 'CSC 302', 'MTH 201', 'Personal', 'Exam Prep']
                .map((f) => DropdownMenuItem(
                    value: f, child: Text(f, style: const TextStyle(fontSize: 12))))
                .toList(),
            onChanged: (v) => setState(() => _folder = v!),
            underline: const SizedBox(),
            isDense: true,
          ),
        ),
        const Spacer(),
        Text('$_wc words', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        IconButton(
            icon: Icon(_remind != null ? Icons.alarm : Icons.alarm_add,
                size: 20, color: _remind != null ? Colors.orange : null),
            tooltip: 'Set reminder',
            onPressed: _pickRemind),
        IconButton(
            icon: Icon(_code ? Icons.code_off : Icons.code, size: 20),
            onPressed: () => setState(() => _code = !_code)),
      ]),
      if (_remind != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Chip(
            backgroundColor: Colors.orange.withOpacity(0.15),
            avatar: const Icon(Icons.alarm, size: 16, color: Colors.orange),
            label: Text('Remind: ${_fmtRemind(_remind!.millisecondsSinceEpoch)}',
                style: const TextStyle(fontSize: 12, color: Colors.orange)),
            deleteIcon: const Icon(Icons.close, size: 14, color: Colors.orange),
            onDeleted: () => setState(() => _remind = null),
          ),
        ),
      Expanded(
        child: _code
            ? SingleChildScrollView(
                child: HighlightView(
                  _body.text.isEmpty ? '// Code here...' : _body.text,
                  language: 'dart',
                  theme: atomOneDarkTheme,
                  padding: const EdgeInsets.all(16),
                  textStyle: const TextStyle(fontSize: 14),
                ),
              )
            : TextField(
                controller: _body,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontSize: 16, height: 1.5),
                decoration: const InputDecoration(
                    labelText: 'Write anything... ideas, reminders, lecture notes',
                    border: InputBorder.none),
              ),
      ),
      if (_listening)
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.mic, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
                child: Text(_lastWords.isEmpty ? 'Listening...' : _lastWords,
                    style: const TextStyle(color: Colors.red))),
            const Text('REC', style: TextStyle(color: Colors.red, fontSize: 12)),
          ]),
        ),
    ]);
  }

  Widget _tabPhoto() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Photos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (int i = 0; i < _imgs.length; i++)
            Stack(children: [
              Image.network('$apiUrl${_imgs[i]}', width: 100, height: 100, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[800],
                      child: const Icon(Icons.broken_image, color: Colors.grey))),
              Positioned(
                  top: 0,
                  right: 0,
                  child: InkWell(
                      onTap: () => setState(() => _imgs.removeAt(i)),
                      child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.red,
                          child: Icon(Icons.close, size: 14, color: Colors.white)))),
            ]),
          ActionChip(
              avatar: const Icon(Icons.add_photo_alternate),
              label: const Text('Add Photo'),
              onPressed: _pickPhoto),
        ],
      ),
    ]);
  }

  Widget _tabMusic() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Music', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ActionChip(
            avatar: const Icon(Icons.play_arrow),
            label: const Text('Lo-fi Beats'),
            onPressed: () => _ap.play(UrlSource(
                'https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3?filename=lofi-study-112191.mp3'))),
        ActionChip(avatar: const Icon(Icons.pause), label: const Text('Pause'), onPressed: () => _ap.pause()),
        ActionChip(avatar: const Icon(Icons.stop), label: const Text('Stop'), onPressed: () => _ap.stop()),
      ]),
      const SizedBox(height: 16),
      const Text('Uploaded Music', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final u in _music)
          ActionChip(
              avatar: const Icon(Icons.play_circle_fill, color: Color(0xFFF5C542)),
              label: Text(_cleanName(u).length > 14
                  ? '${_cleanName(u).substring(0, 14)}...'
                  : _cleanName(u)),
              onPressed: () => _play(u)),
        ActionChip(
            avatar: const Icon(Icons.library_music),
            label: const Text('Upload Music'),
            onPressed: _pickMusic),
      ]),
    ]);
  }

  Widget _tabVideo() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Videos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      TextField(
          controller: _ytCtrl,
          decoration: const InputDecoration(
              labelText: 'Paste YouTube URL',
              prefixIcon: Icon(Icons.link),
              border: OutlineInputBorder()),
          onChanged: (v) => setState(() => _yt = v)),
      if (_yt != null && _yt!.isNotEmpty) ...[
        const SizedBox(height: 12),
        InkWell(
          onTap: () => launchUrl(Uri.parse(_yt!), mode: LaunchMode.externalApplication),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.play_circle_fill, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(_yt!,
                      style: const TextStyle(color: Color(0xFFF5C542)),
                      overflow: TextOverflow.ellipsis)),
              const Icon(Icons.open_in_new, size: 16),
            ]),
          ),
        ),
      ],
      const SizedBox(height: 16),
      const Text('Uploaded Videos', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final u in _vids)
          InkWell(
            onTap: () => launchUrl(Uri.parse('$apiUrl$u'), mode: LaunchMode.externalApplication),
            child: Container(
              width: 110,
              height: 85,
              decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.play_circle_fill, color: Color(0xFFF5C542), size: 32),
                Text(_cleanName(u).length > 12 ? '${_cleanName(u).substring(0, 12)}...' : _cleanName(u),
                    style: const TextStyle(fontSize: 9),
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          ),
        ActionChip(
            avatar: const Icon(Icons.video_library),
            label: const Text('Upload Video'),
            onPressed: _pickVideo),
      ]),
    ]);
  }

  Widget _tabVoice() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Voice', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      const Text('Voice Recording', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(children: [
        ElevatedButton.icon(
          onPressed: _toggleRec,
          icon: Icon(_recording ? Icons.stop : Icons.mic),
          label: Text(_recording ? 'Stop Recording' : 'Start Recording'),
          style: ElevatedButton.styleFrom(
              backgroundColor: _recording ? Colors.red : Theme.of(context).colorScheme.primary,
              foregroundColor: _recording ? Colors.white : Colors.black),
        ),
        if (_audioUrl != null) ...[
          const SizedBox(width: 12),
          IconButton(
              icon: const Icon(Icons.play_circle_fill, color: Color(0xFFF5C542)),
              onPressed: () => _play(_audioUrl!)),
        ],
      ]),
      if (_recording)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Row(children: [
            Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
            SizedBox(width: 4),
            Text('Recording...', style: TextStyle(color: Colors.red)),
          ]),
        ),
      const SizedBox(height: 24),
      const Text('Voice-to-Text (AI)', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('Tap the mic below, speak, your words appear in the note automatically!',
          style: TextStyle(color: Colors.grey, fontSize: 13)),
      const SizedBox(height: 12),
      ElevatedButton.icon(
        onPressed: _toggleSpeech,
        icon: Icon(_listening ? Icons.stop : Icons.graphic_eq),
        label: Text(_listening ? 'Stop Listening' : 'Speak to Type'),
        style: ElevatedButton.styleFrom(
            backgroundColor: _listening ? Colors.red : Colors.green,
            foregroundColor: Colors.white),
      ),
      if (_listening) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.wifi_tethering, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
                child: Text(_lastWords.isEmpty ? 'Listening... speak now!' : _lastWords,
                    style: const TextStyle(color: Colors.green))),
          ]),
        ),
      ],
    ]);
  }

  Widget _tabLinks() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Links', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      const Text('Saved Links', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      for (final l in _links)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => launchUrl(Uri.parse(l), mode: LaunchMode.externalApplication),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.link, color: Color(0xFFF5C542)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(l,
                        style: const TextStyle(color: Color(0xFFF5C542)),
                        overflow: TextOverflow.ellipsis)),
                const Icon(Icons.open_in_new, size: 16),
              ]),
            ),
          ),
        ),
      const SizedBox(height: 16),
      TextField(
        decoration: const InputDecoration(
            labelText: 'Paste a link and press Enter',
            prefixIcon: Icon(Icons.add_link),
            border: OutlineInputBorder()),
        onSubmitted: (v) {
          if (v.isNotEmpty) setState(() => _links.add(v));
        },
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final tabIcons = [
      Icons.edit_note,
      Icons.photo_camera,
      Icons.music_note,
      Icons.videocam,
      Icons.mic,
      Icons.link,
    ];
    final tabLabels = ['Note', 'Photo', 'Music', 'Video', 'Voice', 'Links'];
    final tabViews = [
      _tabNote(),
      _tabPhoto(),
      _tabMusic(),
      _tabVideo(),
      _tabVoice(),
      _tabLinks(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New Note' : 'Edit Note',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
        actions: [
          if (_listening)
            const Padding(
                padding: EdgeInsets.only(right: 8), child: Icon(Icons.mic, color: Colors.red)),
          IconButton(icon: const Icon(Icons.save), onPressed: save),
        ],
      ),
      body: Column(children: [
        Container(
          height: 66,
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[800]!))),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: tabIcons.length,
            itemBuilder: (_, i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  selected: _tab == i,
                  onSelected: (_) => setState(() => _tab = i),
                  avatar: Icon(tabIcons[i], size: 20),
                  label: Text(tabLabels[i], style: const TextStyle(fontSize: 13)),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  selectedColor: const Color(0xFFF5C542),
                  labelStyle: TextStyle(
                      color: _tab == i ? Colors.black : Colors.grey,
                      fontWeight: _tab == i ? FontWeight.bold : FontWeight.normal),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: Padding(padding: const EdgeInsets.all(16), child: tabViews[_tab]),
        ),
      ]),
    );
  }
}