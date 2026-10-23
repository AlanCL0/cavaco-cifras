import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  final String lyricsSnippet;
  final String content;

  Song({
    required this.title,
    required this.artist,
    required this.lyricsSnippet,
    required this.content,
  });
}

// Acordes de Cavaquinho (Ré, Sol, Si, Ré)
final Map<String, List<int>> cavacoChords = {
  "C": [2, 0, 1, 2],
  "C7": [2, 3, 1, 2],
  "C7M": [2, 0, 0, 2],
  "D": [0, 2, 3, 4],
  "D7": [0, 2, 1, 0],
  "Dm": [3, 2, 3, 0],
  "E": [2, 1, 0, 2],
  "E7": [2, 1, 0, 0],
  "Em": [2, 0, 0, 2],
  "F": [3, 2, 1, 3],
  "F#m": [4, 2, 2, 4],
  "G": [0, 0, 0, 0],
  "G7": [0, 0, 0, 3],
  "A": [2, 2, 2, 2],
  "A7": [2, 0, 2, 2],
  "Am": [2, 2, 1, 2],
  "B7": [1, 2, 0, 1],
  "Bm": [4, 4, 3, 4],
};

// Base offline inicial
final List<Song> localSongs = [
  Song(
    title: "Deixa a Vida Me Levar",
    artist: "Zeca Pagodinho",
    lyricsSnippet: "Deixa a vida me levar, vida leva eu...",
    content: """
[C] Deixa a vida me [G7]levar
Vida leva [C]eu
Deixa a vida me [G7]levar
Vida leva [C]eu
Sou feliz e agra[G7]deço
Por tudo que Deus me [C]deu

[C] Posso me confor[G7]mar com a pouca mobí[C]lia
[A7] Uma casa na [Dm]roça e uma fa[G7]mília
Mas se eu tiver que lu[C]tar, vou com fé pra ven[G7]cer
Deus me deu essa [C]vida pra eu poder vi[G7]ver
""",
  ),
  Song(
    title: "O Show Tem Que Continuar",
    artist: "Fundo de Quintal",
    lyricsSnippet: "O teu choro já não toca meu coração...",
    content: """
[C] [Em] [F] [G7]
[C] O teu choro já não [Em]toca meu coração
[F] Foi você quem quis assim, [G7]desfez da união
[C] Agora vem pedir per[Em]dão
[F] Nosso amor foi pro es[G7]paço
[Am] Não tem mais jeito, [Em]meu coração
[F] Encontrou outro [G7]abraço
""",
  ),
  Song(
    title: "Trem das Onze",
    artist: "Adoniran Barbosa",
    lyricsSnippet: "Não posso ficar nem mais um minuto com você...",
    content: """
[Am] Não posso ficar nem mais um mi[E7]nuto com você
Sinto muito [Am]amor, mas não pode [A7]ser
[Dm] Moro em Jaça[Am]nã
Se eu perder esse [E7]trem, que sai agora às onze [Am]horas
Só amanhã de ma[E7]nhã...
""",
  ),
  Song(
    title: "Não Deixe o Samba Morrer",
    artist: "Alcione",
    lyricsSnippet: "Não deixe o samba morrer, não deixe o samba acabar...",
    content: """
[Em] Não deixe o samba [B7]morrer
Não deixe o samba aca[Em]bar
O morro foi feito de [E7]samba
De samba pra gente sam[Am]bar
Quando eu não puder mais pi[Em]sar na avenida
Quando as minhas pernas não mais [B7]aguentar
Levar meu corpo [Em]junto com meu samba...
""",
  ),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  List<Song> _searchResults = [];
  bool _isLoading = false;
  String _message = "";

  @override
  void initState() {
    super.initState();
    _searchResults = localSongs;
  }

  // Busca na web caso não ache na lista interna
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = localSongs;
        _message = "";
      });
      return;
    }

    // Primeiro filtra localmente
    final localMatches = localSongs.where((song) {
      final q = query.toLowerCase();
      return song.title.toLowerCase().contains(q) ||
          song.artist.toLowerCase().contains(q) ||
          song.lyricsSnippet.toLowerCase().contains(q);
    }).toList();

    setState(() {
      _searchResults = localMatches;
      _isLoading = true;
      _message = "Buscando online...";
    });

    try {
      // Consulta API pública de busca de letras
      final response = await http.get(
        Uri.parse("https://api.lyrics.ovh/suggest/${Uri.encodeComponent(query)}"),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data['data'] ?? [];

        final List<Song> onlineSongs = items.take(10).map((item) {
          final title = item['title'] ?? 'Sem título';
          final artist = item['artist']?['name'] ?? 'Artista desconhecido';
          return Song(
            title: title,
            artist: artist,
            lyricsSnippet: "Clique para carregar a letra e acordes",
            content: "[Carregando letra online...]",
          );
        }).toList();

        setState(() {
          // Junta locais com os da internet
          _searchResults = [...localMatches, ...onlineSongs];
          _message = _searchResults.isEmpty ? "Nenhuma música encontrada." : "";
        });
      }
    } catch (e) {
      // Se estiver sem internet, foca no que já tem
      setState(() {
        if (_searchResults.isEmpty) {
          _message = "Sem conexão ou música não encontrada.";
        }
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Se o usuário clicar em uma música que veio da internet, busca o texto da letra
  Future<void> _openSong(Song song) async {
    if (!song.content.contains("[Carregando letra online...]")) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => SongViewerPage(song: song)));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
    );

    try {
      final res = await http.get(
        Uri.parse("https://api.lyrics.ovh/v1/${Uri.encodeComponent(song.artist)}/${Uri.encodeComponent(song.title)}"),
      ).timeout(const Duration(seconds: 8));

      Navigator.pop(context); // fecha dialog

      String lyrics = "Letra não disponível para esta música.";
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        lyrics = data['lyrics'] ?? lyrics;
        
        // Sugere acordes padrão de samba na música (C, G7, Am, F)
        lyrics = "[C] " + lyrics.replaceAll("\n\n", "\n[G7] ").replaceAll("\n", "\n[C] ");
      }

      final completeSong = Song(
        title: song.title,
        artist: song.artist,
        lyricsSnippet: song.lyricsSnippet,
        content: lyrics,
      );

      Navigator.push(context, MaterialPageRoute(builder: (_) => SongViewerPage(song: completeSong)));
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Não foi possível baixar a letra dessa música.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cavaco Cifras & Letras', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
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
                      hintText: 'Pesquise música, cantor ou trecho...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    onSubmitted: _performSearch,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Colors.deepOrange),
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () => _performSearch(_searchController.text),
                ),
              ],
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(color: Colors.deepOrange),
          if (_message.isNotEmpty && !_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_message, style: const TextStyle(color: Colors.grey)),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final song = _searchResults[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(song.artist, style: const TextStyle(color: Colors.deepOrange)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openSong(song),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SongViewerPage extends StatefulWidget {
  final Song song;
  const SongViewerPage({super.key, required this.song});

  @override
  State<SongViewerPage> createState() => _SongViewerPageState();
}

class _SongViewerPageState extends State<SongViewerPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isAutoScrolling = false;
  Timer? _scrollTimer;
  double _scrollSpeed = 1.0;

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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final frets = cavacoChords[chord];
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Acorde: $chord (Cavaquinho)', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Text('Afinação: Ré - Sol - Si - Ré', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              frets != null
                  ? CustomPaint(size: const Size(160, 200), painter: CavacoChordPainter(frets))
                  : const Text('Posição do acorde não cadastrada ainda.'),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
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
              label: Text(_isAutoScrolling ? 'Pausar' : 'Rolagem Auto'),
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
          final regex = RegExp(r'\[(.*?)\]');
          final matches = regex.allMatches(line);

          if (matches.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.0),
              child: Text(line, style: const TextStyle(fontSize: 16)),
            );
          }

          final spans = <InlineSpan>[];
          int lastMatchEnd = 0;

          for (final match in matches) {
            if (match.start > lastMatchEnd) {
              spans.add(TextSpan(text: line.substring(lastMatchEnd, match.start), style: const TextStyle(fontSize: 16, color: Colors.black)));
            }
            final chord = match.group(1)!;
            spans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: GestureDetector(
                  onTap: () => _showChordDialog(chord),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(chord, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 16)),
                  ),
                ),
              ),
            );
            lastMatchEnd = match.end;
          }

          if (lastMatchEnd < line.length) {
            spans.add(TextSpan(text: line.substring(lastMatchEnd), style: const TextStyle(fontSize: 16, color: Colors.black)));
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3.0),
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
