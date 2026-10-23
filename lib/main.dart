import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const CavacoApp());
}

class CavacoApp extends StatelessWidget {
  const CavacoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cavaco Cifras',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class Song {
  final String title;
  final String artist;
  final String url;
  final String source;
  String content;

  Song({
    required this.title,
    required this.artist,
    required this.url,
    required this.source,
    required this.content,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'artist': artist,
        'url': url,
        'source': source,
        'content': content,
      };

  factory Song.fromMap(Map<String, dynamic> map) => Song(
        title: map['title'] ?? '',
        artist: map['artist'] ?? '',
        url: map['url'] ?? '',
        source: map['source'] ?? 'Cifra',
        content: map['content'] ?? '',
      );
}

final Map<String, List<int>> cavacoChords = {
  "C": [2, 0, 1, 2],
  "C7": [2, 3, 1, 2],
  "C7M": [2, 0, 0, 2],
  "C6": [2, 2, 1, 2],
  "Cm": [1, 0, 1, 1],
  "Cm7": [1, 3, 1, 1],
  "D": [0, 2, 3, 4],
  "D7": [0, 2, 1, 0],
  "D7M": [0, 2, 2, 0],
  "D6": [0, 2, 0, 0],
  "Dm": [3, 2, 3, 0],
  "Dm7": [3, 2, 1, 0],
  "E": [2, 1, 0, 2],
  "E7": [2, 1, 0, 0],
  "E7M": [2, 1, 0, 1],
  "Em": [2, 0, 0, 2],
  "Em7": [0, 0, 0, 2],
  "F": [3, 2, 1, 3],
  "F7": [3, 2, 4, 3],
  "F7M": [3, 2, 1, 2],
  "Fm": [3, 1, 1, 3],
  "F#": [4, 3, 2, 4],
  "F#7": [4, 3, 2, 2],
  "F#m": [4, 2, 2, 4],
  "F#m7": [4, 2, 2, 2],
  "G": [0, 0, 0, 0],
  "G7": [0, 0, 0, 3],
  "G7M": [0, 0, 0, 4],
  "G6": [0, 0, 0, 2],
  "Gm": [0, 3, 3, 0],
  "Gm7": [0, 0, 3, 3],
  "G#": [1, 1, 1, 1],
  "G#7": [1, 1, 1, 4],
  "G#m": [1, 4, 4, 1],
  "A": [2, 2, 2, 2],
  "A7": [2, 0, 2, 2],
  "A7M": [2, 1, 2, 2],
  "A6": [2, 2, 2, 4],
  "Am": [2, 2, 1, 2],
  "Am7": [2, 0, 1, 2],
  "Bb": [3, 3, 3, 3],
  "Bb7": [3, 1, 3, 3],
  "Bbm": [3, 3, 2, 3],
  "B": [4, 4, 4, 4],
  "B7": [1, 2, 0, 1],
  "B7M": [4, 3, 4, 4],
  "Bm": [4, 4, 3, 4],
  "Bm7": [4, 2, 3, 4],
  "Eb": [1, 3, 4, 1],
  "Eb7": [1, 3, 2, 1],
};

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  List<Song> _searchResults = [];
  List<Song> _recentSongs = [];
  List<Song> _favoriteSongs = [];

  bool _isLoading = false;
  String _statusMessage = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStoredData();
  }

  Future<void> _loadStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    final recentsJson = prefs.getStringList('recent_songs') ?? [];
    final favsJson = prefs.getStringList('favorite_songs') ?? [];

    setState(() {
      _recentSongs = recentsJson.map((e) => Song.fromMap(jsonDecode(e) as Map<String, dynamic>)).toList();
      _favoriteSongs = favsJson.map((e) => Song.fromMap(jsonDecode(e) as Map<String, dynamic>)).toList();
    });
  }

  Future<void> _addToRecents(Song song) async {
    final prefs = await SharedPreferences.getInstance();
    _recentSongs.removeWhere((s) => s.title == song.title && s.artist == song.artist);
    _recentSongs.insert(0, song);

    if (_recentSongs.length > 10) {
      _recentSongs = _recentSongs.sublist(0, 10);
    }

    final list = _recentSongs.map((s) => jsonEncode(s.toMap())).toList();
    await prefs.setStringList('recent_songs', list);
    setState(() {});
  }

  Future<void> _toggleFavorite(Song song) async {
    final prefs = await SharedPreferences.getInstance();
    final exists = _favoriteSongs.any((s) => s.title == song.title && s.artist == song.artist);

    setState(() {
      if (exists) {
        _favoriteSongs.removeWhere((s) => s.title == song.title && s.artist == song.artist);
      } else {
        _favoriteSongs.insert(0, song);
      }
    });

    final list = _favoriteSongs.map((s) => jsonEncode(s.toMap())).toList();
    await prefs.setStringList('favorite_songs', list);
  }

  bool _isFavorite(Song song) {
    return _favoriteSongs.any((s) => s.title == song.title && s.artist == song.artist);
  }

  Future<void> _searchOnline(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = "Buscando no Cifra Club, Banana Cifras e MVHP...";
      _searchResults.clear();
    });

    try {
      final searchUri = Uri.parse(
        "https://html.duckduckgo.com/html/?q=site%3Acifraclub.com.br+OR+site%3Abananacifras.com+OR+site%3Amvhp.com.br+${Uri.encodeComponent(query)}",
      );

      final res = await http.get(searchUri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36',
      }).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final body = res.body;
        final regex = RegExp(r'<a[^>]+class="result__a"[^>]+href="([^"]+)"[^>]*>(.*?)<\/a>');
        final matches = regex.allMatches(body);

        final List<Song> found = [];
        for (final m in matches) {
          final rawHref = m.group(1) ?? '';
          final rawTitle = m.group(2) ?? '';

          String url = rawHref;
          if (rawHref.contains('uddg=')) {
            final part = rawHref.split('uddg=').last.split('&').first;
            url = Uri.decodeComponent(part);
          }

          String source = "";
          if (url.contains('cifraclub.com.br') && !url.contains('/blog/')) {
            source = "Cifra Club";
          } else if (url.contains('bananacifras.com')) {
            source = "Banana Cifras";
          } else if (url.contains('mvhp.com.br')) {
            source = "MVHP Portal";
          }

          if (source.isNotEmpty) {
            String cleanTitle = rawTitle
                .replaceAll(RegExp(r'<[^>]*>'), '')
                .replaceAll('- Cifra Club', '')
                .replaceAll('- Banana Cifras', '')
                .replaceAll('- MVHP', '')
                .replaceAll('MV Portal de Cifras', '')
                .trim();

            final parts = cleanTitle.split('-');
            final songName = parts[0].trim();
            final artistName = parts.length > 1 ? parts[1].trim() : source;

            found.add(Song(
              title: songName,
              artist: artistName,
              url: url,
              source: source,
              content: '',
            ));
          }
        }

        setState(() {
          _searchResults = found;
          _statusMessage = _searchResults.isEmpty ? "Nenhuma cifra encontrada para essa busca." : "";
        });
      } else {
        setState(() => _statusMessage = "Erro ao conectar aos portais.");
      }
    } catch (e) {
      setState(() => _statusMessage = "Falha de conexão. Verifique sua internet.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openSong(Song song) async {
    if (song.content.isNotEmpty) {
      _addToRecents(song);
      _navigateToViewer(song);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
    );

    try {
      final res = await http.get(Uri.parse(song.url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36',
      }).timeout(const Duration(seconds: 12));

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (res.statusCode == 200) {
        String parsedCifra = "";

        if (song.url.contains('cifraclub.com.br')) {
          final preMatch = RegExp(r'<pre[^>]*>([\s\S]*?)<\/pre>').firstMatch(res.body);
          if (preMatch != null) {
            String raw = preMatch.group(1)!;
            raw = raw.replaceAllMapped(RegExp(r'<b>(.*?)<\/b>'), (m) => '[${m.group(1)}]');
            parsedCifra = _cleanHtml(raw);
          }
        } else if (song.url.contains('bananacifras.com')) {
          final match = RegExp(r'<pre[^>]*>([\s\S]*?)<\/pre>|<div[^>]+class="[^"]*(?:cifra|chords)[^"]*"[^>]*>([\s\S]*?)<\/div>')
              .firstMatch(res.body);
          String raw = match != null ? (match.group(1) ?? match.group(2) ?? '') : res.body;
          raw = raw.replaceAllMapped(RegExp(r'<span[^>]*class="[^"]*(?:chord|cifra)[^"]*"[^>]*>(.*?)<\/span>|<b>(.*?)<\/b>'),
              (m) => '[${m.group(1) ?? m.group(2)}]');
          parsedCifra = _cleanHtml(raw);
        } else if (song.url.contains('mvhp.com.br')) {
          String raw = res.body
              .replaceAll(RegExp(r'<script[\s\S]*?<\/script>', caseSensitive: false), '')
              .replaceAll(RegExp(r'<style[\s\S]*?<\/style>', caseSensitive: false), '')
              .replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n')
              .replaceAll(RegExp(r'<\/p>', caseSensitive: false), '\n\n');
          parsedCifra = _cleanHtml(raw);

          if (parsedCifra.contains('Tom:')) {
            final idx = parsedCifra.indexOf('Tom:');
            final startIdx = parsedCifra.lastIndexOf('\n', idx > 40 ? idx - 40 : 0);
            if (startIdx != -1) parsedCifra = parsedCifra.substring(startIdx).trim();
          }
        }

        if (parsedCifra.trim().isNotEmpty) {
          song.content = parsedCifra;
          _addToRecents(song);
          _navigateToViewer(song);
          return;
        }
      }
      throw Exception("Cifra vazia");
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Não foi possível carregar a cifra deste link.")),
        );
      }
    }
  }

  String _cleanHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"')
        .trim();
  }

  void _navigateToViewer(Song song) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SongViewerPage(
          song: song,
          isFav: _isFavorite(song),
          onFavToggle: () => _toggleFavorite(song),
        ),
      ),
    ).then((_) => _loadStoredData());
  }

  Color _getSourceColor(String source) {
    switch (source) {
      case 'Cifra Club':
        return Colors.deepOrange;
      case 'Banana Cifras':
        return Colors.amber.shade800;
      case 'MVHP Portal':
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cavaco Cifras Brasil', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.history), text: "Recentes (10)"),
            Tab(icon: Icon(Icons.star), text: "Favoritos"),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Música, cantor ou trecho...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    onSubmitted: _searchOnline,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Colors.deepOrange),
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () => _searchOnline(_searchController.text),
                ),
              ],
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(color: Colors.deepOrange),
          if (_statusMessage.isNotEmpty && !_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_statusMessage, style: const TextStyle(color: Colors.grey)),
            ),

          if (_searchResults.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Resultados Encontrados:', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () => setState(() => _searchResults.clear()),
                          child: const Text('Limpar'),
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final song = _searchResults[index];
                        final badgeColor = _getSourceColor(song.source);

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Row(
                              children: [
                                Text(song.artist),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withAlpha(40),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: badgeColor, width: 0.8),
                                  ),
                                  child: Text(
                                    song.source,
                                    style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openSong(song),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _recentSongs.isEmpty
                      ? const Center(child: Text('Nenhuma música recente.'))
                      : ListView.builder(
                          itemCount: _recentSongs.length,
                          itemBuilder: (context, index) {
                            final song = _recentSongs[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: ListTile(
                                leading: const Icon(Icons.history, color: Colors.deepOrange),
                                title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text("${song.artist} • ${song.source}"),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openSong(song),
                              ),
                            );
                          },
                        ),
                  _favoriteSongs.isEmpty
                      ? const Center(child: Text('Nenhuma cifra salva em favoritos.'))
                      : ListView.builder(
                          itemCount: _favoriteSongs.length,
                          itemBuilder: (context, index) {
                            final song = _favoriteSongs[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: ListTile(
                                leading: const Icon(Icons.star, color: Colors.amber),
                                title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text("${song.artist} • ${song.source}"),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                  onPressed: () => _toggleFavorite(song),
                                ),
                                onTap: () => _openSong(song),
                              ),
                            );
                          },
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

  const SongViewerPage({
    super.key,
    required this.song,
    required this.isFav,
    required this.onFavToggle,
  });

  @override
  State<SongViewerPage> createState() => _SongViewerPageState();
}

class _SongViewerPageState extends State<SongViewerPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isAutoScrolling = false;
  Timer? _scrollTimer;
  double _scrollSpeed = 1.0;
  late bool _fav;

  @override
  void initState() {
    super.initState();
    _fav = widget.isFav;
  }

  void _toggleAutoScroll() {
    setState(() {
      _isAutoScrolling = !_isAutoScrolling;
      if (_isAutoScrolling) {
        _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
          if (_scrollController.hasClients) {
            final max = _scrollController.position.maxScrollExtent;
            final current = _scrollController.offset;
            if (current >= max) {
              _toggleAutoScroll();
            } else {
              _scrollController.jumpTo(current + _scrollSpeed);
            }
          }
        });
      } else {
        _scrollTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _showChordDialog(String chord) {
    String clean = chord.replaceAll(RegExp(r'[\[\]\(\)\,\.]'), '').trim();
    clean = clean.replaceAll('+', '7M');

    List<int>? frets = cavacoChords[clean];
    if (frets == null && clean.length > 1) {
      frets = cavacoChords[clean.substring(0, 2)] ?? cavacoChords[clean.substring(0, 1)];
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Acorde: $clean (Cavaquinho)', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Text('Afinação: Ré - Sol - Si - Ré', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            frets != null
                ? CustomPaint(size: const Size(160, 200), painter: CavacoChordPainter(frets))
                : Text('Formação de $clean em breve!'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.song.content.trim().split('\n');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.song.title),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_fav ? Icons.star : Icons.star_border, color: _fav ? Colors.amber : Colors.white),
            onPressed: () {
              setState(() => _fav = !_fav);
              widget.onFavToggle();
            },
          )
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.grey.shade200,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton.icon(
              onPressed: _toggleAutoScroll,
              icon: Icon(_isAutoScrolling ? Icons.pause : Icons.play_arrow),
              label: Text(_isAutoScrolling ? 'Pausar' : 'Rolagem'),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    if (_scrollSpeed > 0.5) setState(() => _scrollSpeed -= 0.5);
                  },
                ),
                Text('${_scrollSpeed}x'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => setState(() => _scrollSpeed += 0.5),
                ),
              ],
            )
          ],
        ),
      ),
      body: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          final regex = RegExp(r'(\[[A-G][b#]?[^\]]*\]|\b[A-G][b#]?(?:m|M|maj|min|dim|aug|sus|\+|º)?[0-9]*(?:\/[A-G][b#]?)?\b)');
          final matches = regex.allMatches(line);

          if (matches.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Text(line, style: const TextStyle(fontSize: 16, fontFamily: 'monospace')),
            );
          }

          final spans = <InlineSpan>[];
          int lastMatchEnd = 0;

          for (final match in matches) {
            if (match.start > lastMatchEnd) {
              spans.add(TextSpan(
                text: line.substring(lastMatchEnd, match.start),
                style: const TextStyle(fontSize: 16, color: Colors.black, fontFamily: 'monospace'),
              ));
            }
            final chord = match.group(0)!;
            spans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: GestureDetector(
                  onTap: () => _showChordDialog(chord),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      chord.replaceAll('[', '').replaceAll(']', ''),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 16),
                    ),
                  ),
                ),
              ),
            );
            lastMatchEnd = match.end;
          }

          if (lastMatchEnd < line.length) {
            spans.add(TextSpan(
              text: line.substring(lastMatchEnd),
              style: const TextStyle(fontSize: 16, color: Colors.black, fontFamily: 'monospace'),
            ));
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text.rich(TextSpan(children: spans)),
          );
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
    final linePaint = Paint()..color = Colors.black..strokeWidth = 2;
    final nutPaint = Paint()..color = Colors.black..strokeWidth = 6;
    final dotPaint = Paint()..color = Colors.deepOrange..style = PaintingStyle.fill;

    const numStrings = 4;
    const numFrets = 4;
    final stringSpacing = size.width / (numStrings - 1);
    final fretSpacing = size.height / numFrets;

    canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), nutPaint);

    for (int i = 0; i < numStrings; i++) {
      final x = i * stringSpacing;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }

    for (int i = 1; i <= numFrets; i++) {
      final y = i * fretSpacing;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    for (int i = 0; i < frets.length; i++) {
      final fret = frets[i];
      final x = i * stringSpacing;

      if (fret > 0) {
        final y = (fret * fretSpacing) - (fretSpacing / 2);
        canvas.drawCircle(Offset(x, y), 8, dotPaint);
      } else {
        final openPaint = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2;
        canvas.drawCircle(Offset(x, -8), 4, openPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
