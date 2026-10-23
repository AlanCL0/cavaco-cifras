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

// Modelo de Música
class Song {
  final String title;
  final String artist;
  final String url;
  final String source; // "Cifra Club", "Banana Cifras" ou "MVHP Portal"
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

// Biblioteca de Acordes do Cavaquinho (Ré - Sol - Si - Ré)
final Map<String, List<int>> cavacoChords = {
  // Dó
  "C": [2, 0, 1, 2],
  "C7": [2, 3, 1, 2],
  "C7M": [2, 0, 0, 2],
  "C6": [2, 2, 1, 2],
  "Cm": [1, 0, 1, 1],
  "Cm7": [1, 3, 1, 1],
  // Ré
  "D": [0, 2, 3, 4],
  "D7": [0, 2, 1, 0],
  "D7M": [0, 2, 2, 0],
  "D6": [0, 2, 0, 0],
  "Dm": [3, 2, 3, 0],
  "Dm7": [3, 2, 1, 0],
  // Mi
  "E": [2, 1, 0, 2],
  "E7": [2, 1, 0, 0],
  "E7M": [2, 1, 0, 1],
  "Em": [2, 0, 0, 2],
  "Em7": [0, 0, 0, 2],
  // Fá
  "F": [3, 2, 1, 3],
  "F7": [3, 2, 4, 3],
  "F7M": [3, 2, 1, 2],
  "Fm": [3, 1, 1, 3],
  "F#": [4, 3, 2, 4],
  "F#7": [4, 3, 2, 2],
  "F#m": [4, 2, 2, 4],
  "F#m7": [4, 2, 2, 2],
  // Sol
  "G": [0, 0, 0, 0],
  "G7": [0, 0, 0, 3],
  "G7M": [0, 0, 0, 4],
  "G6": [0, 0, 0, 2],
  "Gm": [0, 3, 3, 0],
  "Gm7": [0, 0, 3, 3],
  "G#": [1, 1, 1, 1],
  "G#7": [1, 1, 1, 4],
  "G#m": [1, 4, 4, 1],
  // Lá
  "A": [2, 2, 2, 2],
  "A7": [2, 0, 2, 2],
  "A7M": [2, 1, 2, 2],
  "A6": [2, 2, 2, 4],
  "Am": [2, 2, 1, 2],
  "Am7": [2, 0, 1, 2],
  "Bb": [3, 3, 3, 3],
  "Bb7": [3, 1, 3, 3],
  "Bbm": [3, 3, 2, 3],
  // Si
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
      _recentSongs = recentsJson.map((e) => Song.fromMap(jsonDecode(e))).toList();
      _favoriteSongs = favsJson.map((e) => Song.fromMap(jsonDecode(e))).toList();
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

  // Busca conjunta: Cifra Club, Banana Cifras e MVHP Portal de Cifras
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

  // Baixa e extrai a cifra de acordo com o portal
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

      Navigator.pop(context);

      if (res.statusCode == 200) {
        String parsedCifra = "";

        // 1. Extração Cifra Club
        if (song.url.contains('cifraclub.com.br')) {
          final preMatch = RegExp(r'<pre[^>]*>([\s\S]*?)<\/pre>').firstMatch(res.body);
          if (preMatch != null) {
            String raw = preMatch.group(1)!;
            raw = raw.replaceAllMapped(RegExp(r'<b>(.*?)<\/b>'), (m) => '[${m.group(1)}]');
            parsedCifra = _cleanHtml(raw);
          }
        }
        // 2. Extração Banana Cifras
        else if (song.url.contains('bananacifras.com')) {
          final match = RegExp(r'<pre[^>]*>([\s\S]*?)<\/pre>|<div[^>]+class="[^"]*(?:cifra|chords)[^"]*"[^>]*>([\s\S]*?)<\/div>')
              .firstMatch(res.body);
          String raw = match != null ? (match.group(1) ?? match.group(2) ?? '') : res.body;
          raw = raw.replaceAllMapped(RegExp(r'<span[^>]*class="[^"]*chord[^"]*"[^>]*>(.*?)<\/span>|<b>(.*?)<\/b>'),
              (m) => '[${m.group(1) ?? m.group(2)}]');
          parsedCifra = _cleanHtml(raw);
        }
        // 3. Extração MVHP Portal de Cifras
        else if (song.url.contains('mvhp.com.br')) {
          String raw = res.body
              .replaceAll(RegExp(r'<script[\s\S]*?<\/script>', caseSensitive: false), '')
              .replaceAll(RegExp(r'<style[\s\S]*?<\/style>', caseSensitive: false), '')
              .replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n')
              .replaceAll(RegExp(r'<\/p>', caseSensitive: false), '\n\n');
          parsedCifra = _cleanHtml(raw);

          // Corta cabeçalhos desnecessários do MVHP
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
      throw Exception("Não foi possível extrair a cifra.");
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Não foi possível carregar a cifra deste link.")),
      );
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
