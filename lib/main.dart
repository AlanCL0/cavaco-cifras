import 'dart:async';
import 'package:flutter/material.dart';

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
  final String lyricsSnippet;
  final String content; // Letra com cifras entre colchetes, ex: [C]

  Song({
    required this.title,
    required this.artist,
    required this.lyricsSnippet,
    required this.content,
  });
}

// Base de Dados Inicial com Sambas Famosos
final List<Song> sampleSongs = [
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
    artist: "Fundo de Quintal / Beth Carvalho",
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
];

// Dicionário de Acordes de Cavaquinho (Afinação Ré - Sol - Si - Ré)
// Formato: [Corda 4 (Ré), Corda 3 (Sol), Corda 2 (Si), Corda 1 (Ré)]
final Map<String, List<int>> cavacoChords = {
  "C": [2, 0, 1, 2],
  "G7": [0, 0, 0, 3],
  "A7": [2, 2, 2, 2],
  "Am": [2, 2, 1, 2],
  "Dm": [3, 2, 3, 0],
  "E7": [2, 1, 0, 2],
  "Em": [2, 0, 0, 2],
  "F": [3, 2, 1, 3],
};

// Tela Principal com Busca
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final filteredSongs = sampleSongs.where((song) {
      final query = _searchQuery.toLowerCase();
      return song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query) ||
          song.lyricsSnippet.toLowerCase().contains(query) ||
          song.content.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cifras de Cavaquinho', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Pesquise por música, cantor ou trecho...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: filteredSongs.isEmpty
                ? const Center(child: Text("Nenhuma cifra encontrada."))
                : ListView.builder(
                    itemCount: filteredSongs.length,
                    itemBuilder: (context, index) {
                      final song = filteredSongs[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(song.artist, style: const TextStyle(color: Colors.deepOrange)),
                              Text('"${song.lyricsSnippet}"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                            ],
                          ),
                          trailing: const Icon(Icons.music_note, color: Colors.deepOrange),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SongViewerPage(song: song)),
                            );
                          },
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

// Tela de Exibição da Cifra com Rolagem Automática e Acordes Clicáveis
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
        _startAutoScroll();
      } else {
        _scrollTimer?.cancel();
      }
    });
  }

  void _startAutoScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.offset;
        if (currentScroll >= maxScroll) {
          _toggleAutoScroll();
        } else {
          _scrollController.jumpTo(currentScroll + _scrollSpeed);
        }
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final frets = cavacoChords[chord];
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Acorde: $chord (Cavaquinho)', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('Afinação: Ré - Sol - Si - Ré', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              frets != null
                  ? CustomPaint(size: const Size(160, 200), painter: CavacoChordPainter(frets))
                  : const Text('Posição em breve!'),
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
              label: Text(_isAutoScrolling ? 'Pausar Rolagem' : 'Rolagem Auto'),
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
                  onPressed: () {
                    setState(() => _scrollSpeed += 0.5);
                  },
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
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: _buildParsedLine(line),
          );
        },
      ),
    );
  }

  // Identifica os acordes [C] e torna-os clicáveis
  Widget _buildParsedLine(String line) {
    final regex = RegExp(r'\[(.*?)\]');
    final matches = regex.allMatches(line);

    if (matches.isEmpty) {
      return Text(line, style: const TextStyle(fontSize: 16));
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

    return Text.rich(TextSpan(children: spans));
  }
}

// Desenha o braço do cavaquinho (4 cordas e trastes)
class CavacoChordPainter extends CustomPainter {
  final List<int> frets; // 4 valores (casas)
  CavacoChordPainter(this.frets);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;

    final nutPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 6;

    final dotPaint = Paint()
      ..color = Colors.deepOrange
      ..style = PaintingStyle.fill;

    const numStrings = 4;
    const numFrets = 4;

    final stringSpacing = size.width / (numStrings - 1);
    final fretSpacing = size.height / numFrets;

    // Desenha a Pestana (Nut) no topo
    canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), nutPaint);

    // Desenha as 4 cordas (verticais)
    for (int i = 0; i < numStrings; i++) {
      final x = i * stringSpacing;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }

    // Desenha os trastes (horizontais)
    for (int i = 1; i <= numFrets; i++) {
      final y = i * fretSpacing;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Desenha as bolinhas dos dedos
    for (int i = 0; i < frets.length; i++) {
      final fret = frets[i];
      final x = i * stringSpacing;

      if (fret > 0) {
        final y = (fret * fretSpacing) - (fretSpacing / 2);
        canvas.drawCircle(Offset(x, y), 8, dotPaint);
      } else {
        // Corda solta (círculo vazio no topo)
        final openPaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(Offset(x, -8), 4, openPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
