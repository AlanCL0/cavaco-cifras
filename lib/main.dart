import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  themeNotifier.value = (prefs.getBool('is_dark_mode') ?? false) ? ThemeMode.dark : ThemeMode.light;
  runApp(const CavacoApp());
}

class CavacoApp extends StatelessWidget {
  const CavacoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp(
        title: 'Cavaco Cifras Global',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.light),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardColor: const Color(0xFF1E1E1E),
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}

class Song {
  final String title, artist, url, source;
  final int popularityRank;
  String content;

  Song({
    required this.title,
    required this.artist,
    required this.url,
    required this.source,
    this.popularityRank = 0,
    required this.content,
  });

  Map<String, dynamic> toMap() => {
    'title': title, 'artist': artist, 'url': url,
    'source': source, 'popularityRank': popularityRank, 'content': content,
  };

  factory Song.fromMap(Map<String, dynamic> m) => Song(
    title: m['title'] ?? '', artist: m['artist'] ?? '', url: m['url'] ?? '',
    source: m['source'] ?? 'Cifra', popularityRank: m['popularityRank'] ?? 0, content: m['content'] ?? '',
  );
}

final Map<String, List<int>> cavacoChords = {
  "C": [2, 0, 1, 2], "C7": [2, 3, 1, 2], "C7M": [2, 0, 0, 2], "C6": [2, 2, 1, 2], "Cm": [1, 0, 1, 1], "Cm7": [1, 3, 1, 1],
  "D": [0, 2, 3, 4], "D7": [0, 2, 1, 0], "D7M": [0, 2, 2, 0], "D6": [0, 2, 0, 0], "Dm": [3, 2, 3, 0], "Dm7": [3, 2, 1, 0],
  "E": [2, 1, 0, 2], "E7": [2, 1, 0, 0], "E7M": [2, 1, 0, 1], "Em": [2, 0, 0, 2], "Em7": [0, 0, 0, 2],
  "F": [3, 2, 1, 3], "F7": [3, 2, 4, 3], "F7M": [3, 2, 1, 2], "Fm": [3, 1, 1, 3], "F#": [4, 3, 2, 4], "F#7": [4, 3, 2, 2], "F#m": [4, 2, 2, 4], "F#m7": [4, 2, 2, 2],
  "G": [0, 0, 0, 0], "G7": [0, 0, 0, 3], "G7M": [0, 0, 0, 4], "G6": [0, 0, 0, 2], "Gm": [0, 3, 3, 0], "Gm7": [0, 0, 3, 3],
  "G#": [1, 1, 1, 1], "G#7": [1, 1, 1, 4], "G#m": [1, 4, 4, 1],
  "A": [2, 2, 2, 2], "A7": [2, 0, 2, 2], "A7M": [2, 1, 2, 2], "A6": [2, 2, 2, 4], "Am": [2, 2, 1, 2], "Am7": [2, 0, 1, 2],
  "Bb": [3, 3, 3, 3], "Bb7": [3, 1, 3, 3], "Bbm": [3, 3, 2, 3],
  "B": [4, 4, 4, 4], "B7": [1, 2, 0, 1], "B7M": [4, 3, 4, 4], "Bm": [4, 4, 3, 4], "Bm7": [4, 2, 3, 4],
  "Eb": [1, 3, 4, 1], "Eb7": [1, 3, 2, 1],
};

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  late TabController _tabCtrl;
  List<Song> _searchResults = [], _recentSongs = [], _favoriteSongs = [];
  bool _isLoading = false, _isArtistSearch = false, _sortSearchAlpha = false, _sortFavsAlpha = false;
  String _statusMsg = "";

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSongs = (prefs.getStringList('recent_songs') ?? []).map((e) => Song.fromMap(jsonDecode(e))).toList();
      _favoriteSongs = (prefs.getStringList('favorite_songs') ?? []).map((e) => Song.fromMap(jsonDecode(e))).toList();
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = themeNotifier.value == ThemeMode.dark;
    themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
    await prefs.setBool('is_dark_mode', !isDark);
  }

  Future<void> _addToRecents(Song s) async {
    final prefs = await SharedPreferences.getInstance();
    _recentSongs.removeWhere((x) => x.title == s.title && x.artist == s.artist);
    _recentSongs.insert(0, s);
    if (_recentSongs.length > 10) _recentSongs = _recentSongs.sublist(0, 10);
    await prefs.setStringList('recent_songs', _recentSongs.map((x) => jsonEncode(x.toMap())).toList());
    setState(() {});
  }

  Future<void> _toggleFav(Song s) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteSongs.any((x) => x.title == s.title && x.artist == s.artist)) {
        _favoriteSongs.removeWhere((x) => x.title == s.title && x.artist == s.artist);
      } else {
        _favoriteSongs.insert(0, s);
      }
    });
    await prefs.setStringList('favorite_songs', _favoriteSongs.map((x) => jsonEncode(x.toMap())).toList());
  }

  String _slug(String t) {
    var s = t.toLowerCase().trim();
    const a = 'àáâãäåèéêëìíîïòóôõöùúûüýñç', b = 'aaaaaaeeeeiiiiooooouuuuync';
    for (int i = 0; i < a.length; i++) s = s.replaceAll(a[i], b[i]);
    return s.replaceAll(RegExp(r'[^a-z0-9 -]'), '').replaceAll(RegExp(r'\s+'), '-');
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() { _isLoading = true; _statusMsg = "Buscando cifras..."; _searchResults.clear(); _isArtistSearch = false; });
    final List<Song> list = [];
    final sl = _slug(q);

    // 1. Artista (Mais Tocadas)
    try {
      final res = await http.get(Uri.parse("https://www.cifraclub.com.br/$sl/"), headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && !res.body.contains("Página não encontrada")) {
        final reg = RegExp(r'<a\s+[^>]*href="/' + RegExp.escape(sl) + r'/([a-z0-9\-]+)/"[^>]*>([\s\S]*?)</a>');
        int r = 1;
        for (final m in reg.allMatches(res.body)) {
          final slug = m.group(1)!;
          final title = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
          if (['discografia', 'fotos', 'albuns'].contains(slug) || title.isEmpty) continue;
          if (!list.any((x) => x.url.endsWith("/$slug/"))) {
            list.add(Song(title: title, artist: q.toUpperCase(), url: "https://www.cifraclub.com.br/$sl/$slug/", source: "Cifra Club", popularityRank: r++, content: ''));
          }
        }
        if (list.isNotEmpty) {
          setState(() { _searchResults = list; _isArtistSearch = true; _isLoading = false; });
          return;
        }
      }
    } catch (_) {}

    // 2. Genius API
    try {
      final res = await http.get(Uri.parse("https://genius.com/api/search/multi?q=${Uri.encodeComponent(q)}")).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final sec = json.decode(res.body)['response']?['sections'] as List? ?? [];
        for (final s in sec) {
          if (s['type'] == 'song') {
            for (final h in (s['hits'] as List? ?? []).take(6)) {
              final r = h['result'];
              if (r != null) list.add(Song(title: r['title'] ?? '', artist: r['primary_artist']?['name'] ?? '', url: r['url'] ?? '', source: "Genius", content: ''));
            }
          }
        }
      }
    } catch (_) {}

    // 3. Ultimate Guitar & Musixmatch
    try {
      final res = await http.get(Uri.parse("https://html.duckduckgo.com/html/?q=site:ultimate-guitar.com/tabs/+chords+${Uri.encodeComponent(q)}"), headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        for (final m in RegExp(r'<a[^>]+class="result__a"[^>]+href="([^"]+)"[^>]*>(.*?)<\/a>').allMatches(res.body).take(5)) {
          var u = m.group(1) ?? '';
          if (u.contains('uddg=')) u = Uri.decodeComponent(u.split('uddg=').last.split('&').first);
          if (u.contains('ultimate-guitar.com') && u.contains('_crd')) {
            final p = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('CHORDS by', '-').split('-');
            list.add(Song(title: p[0].replaceAll('Chords', '').trim(), artist: p.length > 1 ? p[1].trim() : 'Ultimate Guitar', url: u, source: "Ultimate Guitar", content: ''));
          }
        }
      }
    } catch (_) {}

    setState(() { _searchResults = list; _statusMsg = list.isEmpty ? "Nenhuma música encontrada." : ""; _isLoading = false; });
  }

  Future<void> _openSong(Song s) async {
    if (s.content.isNotEmpty) {
      _addToRecents(s);
      _navViewer(s);
      return;
    }
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.indigo)));
    try {
      String? rawCifra;
      if (s.source == "Cifra Club") {
        final res = await http.get(Uri.parse(s.url), headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 8));
        final m = RegExp(r'<pre[^>]*>([\s\S]*?)</pre>').firstMatch(res.body);
        if (m != null) rawCifra = m.group(1);
      }
      if (rawCifra == null) {
        final q = Uri.encodeComponent("${s.artist} ${s.title}");
        final res = await http.get(Uri.parse("https://html.duckduckgo.com/html/?q=site:cifraclub.com.br+\"cifra\"+$q"), headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 8));
        final m = RegExp(r'uddg=https%3A%2F%2Fwww\.cifraclub\.com\.br%2F([a-z0-9\-]+%2F[a-z0-9\-]+%2F)').firstMatch(res.body);
        if (m != null) {
          final realUrl = Uri.decodeComponent("https://www.cifraclub.com.br/${m.group(1)}");
          final cRes = await http.get(Uri.parse(realUrl), headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 8));
          final pm = RegExp(r'<pre[^>]*>([\s\S]*?)</pre>').firstMatch(cRes.body);
          if (pm != null) rawCifra = pm.group(1);
        }
      }
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (rawCifra != null) {
        s.content = rawCifra.replaceAllMapped(RegExp(r'<b>(.*?)</b>'), (x) => '[${x.group(1)}]').replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&nbsp;', ' ').trim();
        _addToRecents(s);
        _navViewer(s);
      } else {
        throw Exception();
      }
    } catch (_) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Não foi possível extrair a cifra desta música.")));
    }
  }

  void _navViewer(Song s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SongViewerPage(
          song: s,
          isFav: _favoriteSongs.any((x) => x.title == s.title && x.artist == s.artist),
          onFavToggle: () => _toggleFav(s),
        ),
      ),
    ).then((_) => _loadData());
  }

  Color _sourceColor(String s) {
    if (s == 'Ultimate Guitar') return Colors.amber.shade900;
    if (s == 'Genius') return Colors.yellow.shade800;
    return Colors.indigo;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final res = List<Song>.from(_searchResults);
    if (_sortSearchAlpha) res.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    else if (_isArtistSearch) res.sort((a, b) => a.popularityRank.compareTo(b.popularityRank));

    final favs = List<Song>.from(_favoriteSongs);
    if (_sortFavsAlpha) favs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cavaco Cifras Global', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: _toggleTheme,
          )
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [Tab(icon: Icon(Icons.history), text: "Recentes (10)"), Tab(icon: Icon(Icons.star), text: "Favoritos")],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(hintText: 'Música, cantor ou trecho...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true),
                    onSubmitted: _search,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Colors.indigo),
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () => _search(_searchCtrl.text),
                ),
              ],
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(color: Colors.indigo),
          if (_statusMsg.isNotEmpty && !_isLoading) Padding(padding: const EdgeInsets.all(8), child: Text(_statusMsg, style: const TextStyle(color: Colors.grey))),
          if (_searchResults.isNotEmpty)
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_isArtistSearch ? "Músicas do Artista:" : "Resultados:", style: const TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            TextButton.icon(
                              icon: Icon(_sortSearchAlpha ? Icons.sort_by_alpha : Icons.local_fire_department, size: 18),
                              label: Text(_sortSearchAlpha ? "A - Z" : (_isArtistSearch ? "Mais Conhecidas" : "Relevância")),
                              onPressed: () => setState(() => _sortSearchAlpha = !_sortSearchAlpha),
                            ),
                            IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => _searchResults.clear())),
                          ],
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: res.length,
                      itemBuilder: (_, i) {
                        final s = res[i];
                        final c = _sourceColor(s.source);
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            leading: _isArtistSearch && !_sortSearchAlpha
                                ? CircleAvatar(backgroundColor: i < 3 ? Colors.indigo : Colors.grey.shade400, foregroundColor: Colors.white, child: Text("#${s.popularityRank}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))
                                : Icon(Icons.music_note, color: c),
                            title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Row(
                              children: [
                                Expanded(child: Text(s.artist, overflow: TextOverflow.ellipsis)),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: c.withAlpha(40), borderRadius: BorderRadius.circular(4), border: Border.all(color: c, width: 0.8)), child: Text(s.source, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold))),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openSong(s),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            )
          else
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _recentSongs.isEmpty
                      ? const Center(child: Text('Nenhuma busca recente.'))
                      : ListView.builder(
                          itemCount: _recentSongs.length,
                          itemBuilder: (_, i) => Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: ListTile(leading: const Icon(Icons.history, color: Colors.indigo), title: Text(_recentSongs[i].title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("${_recentSongs[i].artist} • ${_recentSongs[i].source}"), trailing: const Icon(Icons.chevron_right), onTap: () => _openSong(_recentSongs[i])),
                          ),
                        ),
                  _favoriteSongs.isEmpty
                      ? const Center(child: Text('Nenhuma cifra salva em favoritos.'))
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Total: ${_favoriteSongs.length} cifras", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  TextButton.icon(icon: Icon(_sortFavsAlpha ? Icons.sort_by_alpha : Icons.schedule, size: 18), label: Text(_sortFavsAlpha ? "A - Z" : "Recentes"), onPressed: () => setState(() => _sortFavsAlpha = !_sortFavsAlpha)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: favs.length,
                                itemBuilder: (_, i) => Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  child: ListTile(leading: const Icon(Icons.star, color: Colors.amber), title: Text(favs[i].title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("${favs[i].artist} • ${favs[i].source}"), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey), onPressed: () => _toggleFav(favs[i])), onTap: () => _openSong(favs[i])),
                                ),
                              ),
                            )
                          ],
                        ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class SongViewerPage extends StatefulWidget {
  final Song song;
  final bool isFav;
  final VoidCallback onFavToggle;
  const SongViewerPage({super.key, required this.song, required this.isFav, required this.onFavToggle});

  @override
  State<SongViewerPage> createState() => _SongViewerPageState();
}

class _SongViewerPageState extends State<SongViewerPage> {
  final ScrollController _scroll = ScrollController();
  bool _isAuto = false;
  Timer? _timer;
  double _speed = 1.0;
  late bool _fav;

  @override
  void initState() {
    super.initState();
    _fav = widget.isFav;
  }

  void _toggleAuto() {
    setState(() {
      _isAuto = !_isAuto;
      if (_isAuto) {
        _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
          if (_scroll.hasClients) {
            if (_scroll.offset >= _scroll.position.maxScrollExtent) _toggleAuto();
            else _scroll.jumpTo(_scroll.offset + _speed);
          }
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _showChord(String c) {
    String clean = c.replaceAll(RegExp(r'[\[\]\(\)\,\.]'), '').replaceAll('+', '7M').trim();
    List<int>? frets = cavacoChords[clean] ?? (clean.length > 1 ? cavacoChords[clean.substring(0, 2)] ?? cavacoChords[clean.substring(0, 1)] : null);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Acorde: $clean (Cavaquinho)', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Text('Afinação: Ré - Sol - Si - Ré', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 15),
            frets != null ? CustomPaint(size: const Size(160, 180), painter: CavacoChordPainter(frets)) : Text('Formação de $clean em breve!'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.song.content.trim().split('\n');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.song.title),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_fav ? Icons.star : Icons.star_border, color: _fav ? Colors.amber : Colors.white),
            onPressed: () { setState(() => _fav = !_fav); widget.onFavToggle(); },
          )
        ],
      ),
      bottomNavigationBar: Container(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              onPressed: _toggleAuto,
              icon: Icon(_isAuto ? Icons.pause : Icons.play_arrow),
              label: Text(_isAuto ? 'Pausar' : 'Rolagem'),
            ),
            Row(
              children: [
                IconButton(icon: const Icon(Icons.remove), onPressed: () { if (_speed > 0.5) setState(() => _speed -= 0.5); }),
                Text('${_speed}x'),
                IconButton(icon: const Icon(Icons.add), onPressed: () => setState(() => _speed += 0.5)),
              ],
            )
          ],
        ),
      ),
      body: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        itemCount: lines.length,
        itemBuilder: (_, idx) {
          final line = lines[idx];
          final regex = RegExp(r'(\[[A-G][b#]?[^\]]*\]|\b[A-G][b#]?(?:m|M|maj|min|dim|aug|sus|\+|º)?[0-9]*(?:\/[A-G][b#]?)?\b)');
          final matches = regex.allMatches(line);

          if (matches.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(line, style: const TextStyle(fontSize: 16, fontFamily: 'monospace')));

          final spans = <InlineSpan>[];
          int last = 0;
          for (final m in matches) {
            if (m.start > last) spans.add(TextSpan(text: line.substring(last, m.start), style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black87, fontFamily: 'monospace')));
            final chord = m.group(0)!;
            spans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: GestureDetector(
                  onTap: () => _showChord(chord),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: isDark ? Colors.indigo.shade900 : Colors.indigo.shade100, borderRadius: BorderRadius.circular(4)),
                    child: Text(chord.replaceAll('[', '').replaceAll(']', ''), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.indigoAccent : Colors.indigo, fontSize: 16)),
                  ),
                ),
              ),
            );
            last = m.end;
          }
          if (last < line.length) spans.add(TextSpan(text: line.substring(last), style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black87, fontFamily: 'monospace')));
          return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text.rich(TextSpan(children: spans)));
        },
      ),
    );
  }
}

class CavacoChordPainter extends CustomPainter {
  final List<int> frets;
  CavacoChordPainter(this.frets);

  @override
  void paint(Canvas canvas, Size size) {
    final lineP = Paint()..color = Colors.grey.shade800..strokeWidth = 2;
    final nutP = Paint()..color = Colors.black..strokeWidth = 6;
    final dotP = Paint()..color = Colors.indigo..style = PaintingStyle.fill;
    final spX = size.width / 3;
    final spY = size.height / 4;

    canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), nutP);
    for (int i = 0; i < 4; i++) canvas.drawLine(Offset(i * spX, 0), Offset(i * spX, size.height), lineP);
    for (int i = 1; i <= 4; i++) canvas.drawLine(Offset(0, i * spY), Offset(size.width, i * spY), lineP);

    for (int i = 0; i < frets.length; i++) {
      final f = frets[i];
      if (f > 0) {
        canvas.drawCircle(Offset(i * spX, (f * spY) - (spY / 2)), 8, dotP);
      } else {
        canvas.drawCircle(Offset(i * spX, -8), 4, Paint()..color = Colors.grey.shade800..style = PaintingStyle.stroke..strokeWidth = 2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
