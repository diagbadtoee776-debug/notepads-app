import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

const String apiUrl = 'http://localhost:5000';

void main() => runApp(const DevVaultApp());

class DevVaultApp extends StatelessWidget {
  const DevVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevVault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFF5C542),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const AuthScreen(),
    );
  }
}

// ---------------- LOGIN / REGISTER ----------------
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool busy = false;
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String department = 'CSC';

  Future<void> submit() async {
    setState(() => busy = true);
    try {
      if (!isLogin) {
        await http.post(Uri.parse('$apiUrl/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': _username.text.trim(),
              'email': _email.text.trim(),
              'password': _password.text,
              'department': department,
            }));
      }
      final res = await http.post(Uri.parse('$apiUrl/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(
              {'email': _email.text.trim(), 'password': _password.text}));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => HomeScreen(
                    token: data['token'],
                    username: data['user']['username'])));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Failed')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cannot reach server. Is npm run dev running?')));
    } finally {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.lock_outline, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('DevVault',
                      style: GoogleFonts.poppins(
                          fontSize: 36, fontWeight: FontWeight.bold)),
                  Text('Your offline-first knowledge hub',
                      style: TextStyle(color: Colors.grey[400])),
                  const SizedBox(height: 32),
                  if (!isLogin) ...[
                    TextField(
                        controller: _username,
                        decoration: InputDecoration(
                            labelText: 'Username',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: department,
                      items: const ['CSC', 'ECE', 'MTH', 'PHY', 'BUS']
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) => setState(() => department = v!),
                      decoration: InputDecoration(
                          labelText: 'Department',
                          prefixIcon: const Icon(Icons.school),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                      controller: _email,
                      decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _password,
                      decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      obscureText: true),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: busy ? null : submit,
                      style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text(isLogin ? 'LOGIN' : 'CREATE ACCOUNT',
                          style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: Text(isLogin
                        ? 'New here? Create account'
                        : 'Have an account? Login'),
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

// ---------------- HOME (NOTES LIST) ----------------
class HomeScreen extends StatefulWidget {
  final String token;
  final String username;
  const HomeScreen({super.key, required this.token, required this.username});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> notes = [];
  List<dynamic> filteredNotes = [];
  bool loading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadNotes();
    _searchController.addListener(_filterNotes);
  }

  void _filterNotes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredNotes = notes.where((n) {
        final title = (n['title'] ?? '').toString().toLowerCase();
        final body = (n['body'] ?? '').toString().toLowerCase();
        return title.contains(query) || body.contains(query);
      }).toList();
    });
  }

  Future<void> loadNotes() async {
    final res = await http.get(Uri.parse('$apiUrl/notes'),
        headers: {'Authorization': 'Bearer ${widget.token}'});
    if (res.statusCode == 200) {
      setState(() {
        notes = jsonDecode(res.body);
        notes.sort((a, b) {
          final aPinned = a['is_pinned'] == 1 ? 1 : 0;
          final bPinned = b['is_pinned'] == 1 ? 1 : 0;
          return bPinned.compareTo(aPinned);
        });
        filteredNotes = List.from(notes);
        loading = false;
      });
    }
  }

  Future<void> shareNote(int id) async {
    final res = await http.post(Uri.parse('$apiUrl/share'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}'
        },
        body: jsonEncode({'note_id': id}));
    final data = jsonDecode(res.body);
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
                  decoration: BoxDecoration(
                      color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
                  child: SelectableText('$apiUrl${data['link']}',
                      style: const TextStyle(color: Color(0xFFF5C542))),
                ),
                const SizedBox(height: 12),
                const Text('Anyone with this link can view your note',
                    style: TextStyle(color: Colors.grey)),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done')),
              ],
            ));
  }

  Future<void> togglePin(dynamic note) async {
    final isPinned = note['is_pinned'] == 1;
    await http.put(Uri.parse('$apiUrl/notes/${note['id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}'
        },
        body: jsonEncode({
          'title': note['title'],
          'body': note['body'],
          'is_pinned': !isPinned,
          'folder_id': note['folder_id'],
        }));
    loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('DevVault', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        actions: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(widget.username[0].toUpperCase(),
                style: const TextStyle(color: Colors.black)),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search notes...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : filteredNotes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.note_add_outlined, size: 64, color: Colors.grey[600]),
                          const SizedBox(height: 16),
                          Text('No notes yet',
                              style: TextStyle(color: Colors.grey[400], fontSize: 18)),
                          const SizedBox(height: 8),
                          Text('Tap + to create your first note',
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredNotes.length,
                      itemBuilder: (_, i) {
                        final n = filteredNotes[i];
                        final isPinned = n['is_pinned'] == 1;
                        final bodyText = (n['body'] ?? '').toString();
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: isPinned
                                      ? const Color(0xFFF5C542).withOpacity(0.2)
                                      : Colors.grey[800],
                                  borderRadius: BorderRadius.circular(8)),
                              child: Icon(
                                isPinned ? Icons.push_pin : Icons.description,
                                color: isPinned ? const Color(0xFFF5C542) : Colors.grey,
                              ),
                            ),
                            title: Row(children: [
                              Expanded(child: Text(n['title'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w600))),
                              if (isPinned)
                                const Icon(Icons.push_pin, size: 16, color: Color(0xFFF5C542)),
                            ]),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                bodyText.length > 80
                                    ? '${bodyText.substring(0, 80)}...'
                                    : bodyText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'share') shareNote(n['id']);
                                if (value == 'pin') togglePin(n);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'share', child: Row(children: [
                                  Icon(Icons.share, size: 20),
                                  SizedBox(width: 8),
                                  Text('Share')
                                ])),
                                PopupMenuItem(value: 'pin', child: Row(children: [
                                  Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined, size: 20),
                                  const SizedBox(width: 8),
                                  Text(isPinned ? 'Unpin' : 'Pin')
                                ])),
                              ],
                            ),
                            onTap: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          NoteEditor(token: widget.token, note: n)));
                              loadNotes();
                            },
                          ),
                        );
                      },
                    ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => NoteEditor(token: widget.token)));
          loadNotes();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
      ),
    );
  }
}

// ---------------- NOTE EDITOR WITH MEDIA ----------------
class NoteEditor extends StatefulWidget {
  final String token;
  final dynamic note;
  const NoteEditor({super.key, required this.token, this.note});
  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _isCodeBlock = false;
  
  // Media state
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ImagePicker _picker = ImagePicker();
  
  bool _isRecording = false;
  String? _recordedPath;
  String? _uploadedAudioUrl;
  
  List<String> _attachedImages = [];
  List<String> _uploadedImageUrls = [];
  
  String? _youtubeUrl;
  final _youtubeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _title.text = widget.note['title'] ?? '';
      _body.text = widget.note['body'] ?? '';
      _parseMediaFromBody();
    }
  }

  void _parseMediaFromBody() {
    final body = _body.text;
    final imgRegex = RegExp(r'\[IMG:(.*?)\]');
    final audioRegex = RegExp(r'\[AUDIO:(.*?)\]');
    final ytRegex = RegExp(r'\[YT:(.*?)\]');
    
    _uploadedImageUrls = imgRegex.allMatches(body).map((m) => m.group(1)!).toList();
    _uploadedAudioUrl = audioRegex.firstMatch(body)?.group(1);
    _youtubeUrl = ytRegex.firstMatch(body)?.group(1);
    
    if (_youtubeUrl != null) {
      _youtubeController.text = _youtubeUrl!;
    }
    
    _body.text = body
        .replaceAll(imgRegex, '')
        .replaceAll(audioRegex, '')
        .replaceAll(ytRegex, '')
        .trim();
  }

  String _buildBodyWithMedia() {
    String body = _body.text;
    for (final url in _uploadedImageUrls) {
      body += '\n[IMG:$url]';
    }
    if (_uploadedAudioUrl != null) {
      body += '\n[AUDIO:$_uploadedAudioUrl]';
    }
    if (_youtubeUrl != null && _youtubeUrl!.isNotEmpty) {
      body += '\n[YT:$_youtubeUrl]';
    }
    return body;
  }

  // ---- VOICE RECORDING ----
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _recorder.stop();
      setState(() => _isRecording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording saved! Tap upload to save to note.')),
      );
    } else {
      if (await _recorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        _recordedPath = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _recordedPath!);
        setState(() => _isRecording = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
    }
  }

  Future<void> _uploadAudio() async {
    if (_recordedPath == null) return;
    final file = File(_recordedPath!);
    final request = http.MultipartRequest('POST', Uri.parse('$apiUrl/upload'))
      ..headers['Authorization'] = 'Bearer ${widget.token}'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    
    final response = await request.send();
    if (response.statusCode == 200) {
      final data = jsonDecode(await response.stream.bytesToString());
      setState(() {
        _uploadedAudioUrl = data['url'];
        _recordedPath = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice note uploaded!')),
      );
    }
  }

  Future<void> _playAudio(String url) async {
    await _audioPlayer.play(UrlSource('$apiUrl$url'));
  }

  // ---- PHOTO ATTACHMENTS ----
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _attachedImages.add(picked.path));
    }
  }

  Future<void> _uploadImages() async {
    for (final path in _attachedImages) {
      final file = File(path);
      final request = http.MultipartRequest('POST', Uri.parse('$apiUrl/upload'))
        ..headers['Authorization'] = 'Bearer ${widget.token}'
        ..files.add(await http.MultipartFile.fromPath('file', file.path));
      
      final response = await request.send();
      if (response.statusCode == 200) {
        final data = jsonDecode(await response.stream.bytesToString());
        setState(() => _uploadedImageUrls.add(data['url']));
      }
    }
    setState(() => _attachedImages.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photos uploaded!')),
    );
  }

  // ---- SAVE NOTE ----
  Future<void> save() async {
    if (_recordedPath != null) await _uploadAudio();
    if (_attachedImages.isNotEmpty) await _uploadImages();
    
    final isEdit = widget.note != null;
    final url = isEdit ? '$apiUrl/notes/${widget.note['id']}' : '$apiUrl/notes';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${widget.token}'
    };
    final body = jsonEncode({
      'title': _title.text,
      'body': _buildBodyWithMedia(),
      'is_pinned': isEdit ? (widget.note['is_pinned'] == 1) : false,
      'folder_id': null,
    });
    if (isEdit) {
      await http.put(Uri.parse(url), headers: headers, body: body);
    } else {
      await http.post(Uri.parse(url), headers: headers, body: body);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New Note' : 'Edit Note',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
              icon: Icon(_isCodeBlock ? Icons.code_off : Icons.code),
              onPressed: () => setState(() => _isCodeBlock = !_isCodeBlock),
              tooltip: 'Toggle code block'),
          IconButton(icon: const Icon(Icons.save), onPressed: save),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
              controller: _title,
              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                  labelText: 'Title', border: InputBorder.none)),
          const Divider(height: 1),
          const SizedBox(height: 12),
          
          SizedBox(
            height: 200,
            child: _isCodeBlock
                ? SingleChildScrollView(
                    child: HighlightView(
                      _body.text.isEmpty ? '// Write your code here...' : _body.text,
                      language: 'dart',
                      theme: atomOneDarkTheme,
                      padding: const EdgeInsets.all(16),
                      textStyle: GoogleFonts.firaCode(fontSize: 14),
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
          
          const SizedBox(height: 24),
          const Text('Media Attachments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          // Voice Recording
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.mic, color: Color(0xFFF5C542)),
                  SizedBox(width: 8),
                  Text('Voice Recording', style: TextStyle(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  ElevatedButton.icon(
                    onPressed: _toggleRecording,
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.red : Theme.of(context).colorScheme.primary,
                      foregroundColor: _isRecording ? Colors.white : Colors.black,
                    ),
                  ),
                  if (_recordedPath != null) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _uploadAudio,
                      icon: const Icon(Icons.upload),
                      label: const Text('Upload'),
                    ),
                  ],
                  if (_uploadedAudioUrl != null) ...[
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.play_circle_fill, color: Color(0xFFF5C542)),
                      onPressed: () => _playAudio(_uploadedAudioUrl!),
                      tooltip: 'Play recording',
                    ),
                  ],
                ]),
                if (_isRecording)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(children: [
                      Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
                      SizedBox(width: 4),
                      Text('Recording...', style: TextStyle(color: Colors.red)),
                    ]),
                  ),
              ]),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Photo Attachments
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.photo_camera, color: Color(0xFFF5C542)),
                  SizedBox(width: 8),
                  Text('Photos', style: TextStyle(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final path in _attachedImages)
                      Stack(children: [
                        Image.file(File(path), width: 80, height: 80, fit: BoxFit.cover),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _attachedImages.remove(path)),
                            child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, size: 14, color: Colors.white)),
                          ),
                        ),
                      ]),
                    for (final url in _uploadedImageUrls)
                      Image.network('$apiUrl$url', width: 80, height: 80, fit: BoxFit.cover),
                    ActionChip(
                      avatar: const Icon(Icons.add_photo_alternate),
                      label: const Text('Add Photo'),
                      onPressed: _pickImage,
                    ),
                    if (_attachedImages.isNotEmpty)
                      ActionChip(
                        avatar: const Icon(Icons.upload),
                        label: const Text('Upload All'),
                        onPressed: _uploadImages,
                      ),
                  ],
                ),
              ]),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // YouTube Embed
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.play_circle_outline, color: Color(0xFFF5C542)),
                  SizedBox(width: 8),
                  Text('YouTube Video', style: TextStyle(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _youtubeController,
                  decoration: const InputDecoration(
                    labelText: 'Paste YouTube URL',
                    prefixIcon: Icon(Icons.link),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => _youtubeUrl = val),
                ),
                if (_youtubeUrl != null && _youtubeUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => launchUrl(Uri.parse(_youtubeUrl!), mode: LaunchMode.externalApplication),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.play_circle_fill, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_youtubeUrl!, style: const TextStyle(color: Color(0xFFF5C542)), overflow: TextOverflow.ellipsis)),
                        const Icon(Icons.open_in_new, size: 16),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Music Player
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.music_note, color: Color(0xFFF5C542)),
                  SizedBox(width: 8),
                  Text('Study Music', style: TextStyle(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  ElevatedButton.icon(
                    onPressed: () => _audioPlayer.play(UrlSource('https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3?filename=lofi-study-112191.mp3')),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play Lo-fi Beats'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _audioPlayer.pause(),
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _audioPlayer.stop(),
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
