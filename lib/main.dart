import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Gerenciador global de Tema
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
          title: 'Cavaco Cifras Global',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
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
  final String source;
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
        'title': title,
        'artist': artist,
        'url': url,
        'source': source,
        'popularityRank': popularityRank,
        'content': content,
      };

  factory Song.fromMap(Map<String, dynamic> map) => Song(
        title: map['title'] ?? '',
        artist: map['artist'] ?? '',
        url: map['url'] ?? '',
        source: map['source'] ?? 'Cifra',
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
