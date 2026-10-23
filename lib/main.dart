import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Gerenciador global de Tema (Claro / Escuro)
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark_mode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  runApp(const CavacoApp());
}

class CavacoApp extends StatelessWidget {
  const CavacoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Cavaco Cifras',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepOrange,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepOrange,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            useMaterial3: true,
          ),
          home: const HomePage(),
        );
      },
    );
  }
}

// Modelo de Música
class Song {
  final String title;
  final String artist;
  final String url;
  final int popularityRank; // 1 = mais conhecida
  String content;

  Song({
    required this.title,
    required this.artist,
    required this.url,
    this.popularityRank = 0,
    required this.content,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'artist': artist,
        'url': url,
        'popularityRank': popularityRank,
        'content': content,
      };

  factory Song.fromMap(Map<String, dynamic> map) => Song(
        title: map['title'] ?? '',
        artist: map['artist'] ?? '',
        url: map['url'] ?? '',
        popularityRank: map['popularityRank'] ?? 0,
        content: map['content'] ?? '',
      );
}

// Dicionário de Acordes de Cavaquinho (Ré - Sol - Si - Ré)
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
  bool _isArtistSearch = false;
  bool _sortSearchAlpha = false;
  bool _sortFavsAlpha = false;
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

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = themeNotifier.value == ThemeMode.dark;
    themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
    await prefs.setBool('is_dark_mode', !isDark);
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

  String _generateSlug(String text) {
    var str = text.toLowerCase().trim();
    const withDia = 'àáâãäåèéêëìíîïòóôõöùúûüýÿñç·/_,:;';
    const withoutDia = 'aaaaaaeeeeiiiiooooouuuuyync------';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str
        .replaceAll(RegExp(r'[^a-z0-9 -]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

  // Busca Inteligente: Identifica se é Artista ou Música
  Future<void> _searchOnline(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = "Pesquisando catálogo oficial de cifras...";
      _searchResults.clear();
      _isArtistSearch = false;
    });

    final slug = _generateSlug(query);
    final headers = {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'pt-BR,pt;q=0.9',
    };

    try {
      // 1. TENTA PRIMEIRO COMO PÁGINA DIRETA DO ARTISTA (Listagem das mais conhecidas)
      final artistUrl = Uri.parse("https://www.cifraclub.com.br/$slug/");
      final artistRes = await http.get(artistUrl, headers: headers).timeout(const Duration(seconds: 7));

      if (artistRes.statusCode == 200 && !artistRes.body.contains("Página não encontrada")) {
        final regex = RegExp(r'<a\s+[^>]*href="/' + RegExp.escape(slug) + r'/([a-z0-9\-]+)/"[^>]*>([\s\S]*?)</a>');
        final matches = regex.allMatches(artistRes.body);

        final List<Song> artistSongs = [];
        int rank = 1;

        for (final m in matches) {
          final songSlug = m.group(1)!;
          String songTitle = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();

          // Ignora links de navegação do site
          if (songSlug == 'discografia' || songSlug == 'fotos' || songSlug == 'albuns' || songTitle.isEmpty) {
            continue;
          }

          if (!artistSongs.any((s) => s.url.endsWith("/$songSlug/"))) {
            artistSongs.add(Song(
              title: songTitle,
              artist: query.toUpperCase(),
              url: "https://www.cifraclub.com.br/$slug/$songSlug/",
              popularityRank: rank++,
              content: '',
            ));
          }
        }

        if (artistSongs.isNotEmpty) {
          setState(() {
            _searchResults = artistSongs;
            _isArtistSearch = true;
            _isLoading = false;
          });
          return;
        }
      }

      // 2. SE NÃO FOR UM ARTISTA, BUSCA ESPECÍFICA DE MÚSICA / TRECHO
      final searchUri = Uri.parse(
        "https://html.duckduckgo.com/html/?q=site:cifraclub.com.br+\"cifra\"+${Uri.encodeComponent(query)}",
      );

      final res = await http.get(searchUri, headers: headers).timeout(const Duration(seconds: 10));

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

          // FILTRO ESTRITO: Apenas páginas com artista e música (sem blogs, listas ou vídeos)
          final isSongPage = RegExp(r'^https?://(?:www\.)?cifraclub\.com\.br/([a-z0-9\-]+)/([a-z0-9\-]+)/?$').hasMatch(url);
          final isNotJunk = !url.contains('/blog/') && !url.contains('/videoaulas/') && !url.contains('/albuns/');

          if (isSongPage && isNotJunk) {
            String cleanTitle = rawTitle.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('- Cifra Club', '').trim();
            final parts = cleanTitle.split('-');
            final songName = parts[0].trim();
            final artistName = parts.length > 1 ? parts[1].trim() : 'Cifra';

            found.add(Song(
              title: songName,
              artist: artistName,
              url: url,
              content: '',
            ));
          }
        }

        setState(() {
          _searchResults = found;
          _statusMessage = _searchResults.isEmpty ? "Nenhuma cifra encontrada. Tente o nome exato da música." : "";
        });
      }
    } catch (e) {
      setState(() => _statusMessage = "Verifique sua conexão com a internet.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Abre a cifra e extrai letra com acordes
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
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      }).timeout(const Duration(seconds: 12));

      if (mounted && Navigator.canPop(context)) Navigator.pop(context);

      if (res.statusCode == 200) {
        // Extrai a tag <pre> da cifra
        final preMatch = RegExp(r'<pre[^>]*>([\s\S]*?)</pre>').firstMatch(res.body);
        if (preMatch != null) {
          String raw = preMatch.group(1)!;

          // Transforma acordes <b> em [Acorde]
          raw = raw.replaceAllMapped(RegExp(r'<b>(.*?)</b>'), (m) => '[${m.group(1)}]');
          raw = raw.replaceAll(RegExp(r'<[^>]+>'), '');
          raw = raw
              .replaceAll('&nbsp;', ' ')
              .replaceAll('&amp;', '&')
              .replaceAll('&#39;', "'")
              .replaceAll('&quot;', '"')
              .trim();

          song.content = raw;
          _addToRecents(song);
          _navigateToViewer(song);
          return;
        }
      }
      throw Exception("Cifra não encontrada");
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Não foi possível extrair a cifra desta música.")),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Organização dos resultados
    final displayedResults = List<Song>.from(_searchResults);
    if (_sortSearchAlpha) {
      displayedResults.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_isArtistSearch) {
      displayedResults.sort((a, b) => a.popularityRank.compareTo(b.popularityRank));
    }

    // Organização dos favoritos
    final displayedFavs = List<Song>.from(_favoriteSongs);
    if (_sortFavsAlpha) {
      displayedFavs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cavaco Cifras', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDark ? 'Modo Claro' : 'Modo Escuro',
            onPressed: _toggleTheme,
          )
        ],
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
                      hintText: 'Digite artista, música ou trecho...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
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

          // LISTAGEM DE RESULTADOS DA BUSCA
          if (_searchResults.isNotEmpty)
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isArtistSearch ? "Músicas do Artista:" : "Resultados:",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              icon: Icon(_sortSearchAlpha ? Icons.sort_by_alpha : Icons.local_fire_department, size: 18),
                              label: Text(_sortSearchAlpha ? "A - Z" : (_isArtistSearch ? "Mais Conhecidas" : "Relevância")),
                              onPressed: () => setState(() => _sortSearchAlpha = !_sortSearchAlpha),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              tooltip: 'Limpar busca',
                              onPressed: () => setState(() => _searchResults.clear()),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: displayedResults.length,
                      itemBuilder: (context, index) {
                        final song = displayedResults[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            leading: _isArtistSearch && !_sortSearchAlpha
                                ? CircleAvatar(
                                    backgroundColor: index < 3 ? Colors.deepOrange : Colors.grey.shade300,
                                    foregroundColor: index < 3 ? Colors.white : Colors.black87,
                                    child: Text("#${song.popularityRank}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  )
                                : const Icon(Icons.music_note, color: Colors.deepOrange),
                            title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(song.artist),
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
            // ABAS DE RECENTES E FAVORITOS
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ABA 1: RECENTES
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
                                subtitle: Text(song.artist),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openSong(song),
                              ),
                            );
                          },
                        ),

                  // ABA 2: FAVORITOS COM OPÇÃO A-Z
                  _favoriteSongs.isEmpty
                      ? const Center(child: Text('Nenhuma cifra salva em favoritos.'))
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Total: ${_favoriteSongs.length} cifras", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  TextButton.icon(
                                    icon: Icon(_sortFavsAlpha ? Icons.sort_by_alpha : Icons.schedule, size: 18),
                                    label: Text(_sortFavsAlpha ? "A - Z" : "Recentes"),
                                    onPressed: () => setState(() => _sortFavsAlpha = !_sortFavsAlpha),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: displayedFavs.length,
                                itemBuilder: (context, index) {
                                  final song = displayedFavs[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    child: ListTile(
                                      leading: const Icon(Icons.star, color: Colors.amber),
                                      title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text(song.artist),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                        onPressed: () => _toggleFavorite(song),
                                      ),
                                      onTap: () => _openSong(song),
                                    ),
                                  );
                                },
                              ),
                            ),
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

// TELA DO VISUALIZADOR DE CIFRA
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
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
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontFamily: 'monospace',
                ),
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
                      color: isDark ? Colors.deepOrange.shade900 : Colors.deepOrange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      chord.replaceAll('[', '').replaceAll(']', ''),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.orangeAccent : Colors.deepOrange,
                        fontSize: 16,
                      ),
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
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black87,
                fontFamily: 'monospace',
              ),
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

// Pintor do Braço do Cavaquinho
class CavacoChordPainter extends CustomPainter {
  final List<int> frets;
  CavacoChordPainter(this.frets);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..color = Colors.grey.shade800..strokeWidth = 2;
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
        final openPaint = Paint()..color = Colors.grey.shade800..style = PaintingStyle.stroke..strokeWidth = 2;
        canvas.drawCircle(Offset(x, -8), 4, openPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
