import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';

void main() => runApp(SetTrackApp());

class SetTrackApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SETTRACK',
      theme: ThemeData.dark(),
      home: HomeScreen(),
    );
  }
}

List<AnalysisResult> historial = [];

class AnalysisResult {
  final String jugadora;
  final String zona;
  final double altura;
  final double distancia;
  final double tiempo;
  final double angulo;
  final DateTime fecha;

  AnalysisResult({
    required this.jugadora,
    required this.zona,
    required this.altura,
    required this.distancia,
    required this.tiempo,
    required this.angulo,
    required this.fecha,
  });
}

class HomeScreen extends StatelessWidget {
  final picker = ImagePicker();

  Future<void> _pickVideo(BuildContext context, ImageSource src) async {
    final picked = await picker.pickVideo(source: src);
    if (picked != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoAnalysisScreen(videoFile: File(picked.path)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('SETTRACK')),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton.icon(
            onPressed: () => _pickVideo(context, ImageSource.camera),
            icon: Icon(Icons.videocam),
            label: Text('Grabar nuevo video'),
          ),
          ElevatedButton.icon(
            onPressed: () => _pickVideo(context, ImageSource.gallery),
            icon: Icon(Icons.video_collection),
            label: Text('Cargar video existente'),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HistoryScreen()),
              );
            },
            icon: Icon(Icons.history),
            label: Text('Historial'),
          ),
        ]),
      ),
    );
  }
}

class VideoAnalysisScreen extends StatefulWidget {
  final File videoFile;
  VideoAnalysisScreen({required this.videoFile});

  @override
  _VideoAnalysisScreenState createState() => _VideoAnalysisScreenState();
}

class _VideoAnalysisScreenState extends State<VideoAnalysisScreen> {
  late VideoPlayerController _ctrl;
  bool loaded = false;
  List<Offset> pts = [];
  final double redAltura = 2.24;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) => setState(() => loaded = true));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add(TapUpDetails d) {
    if (pts.length < 3) setState(() => pts.add(d.localPosition));
  }

  Future<void> _goCalc() async {
    if (pts.length == 3) {
      final res = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultsScreen(points: pts)),
      );
      if (res is AnalysisResult) historial.add(res);
    }
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: Text('Analizar Armado')),
      body: Column(children: [
        loaded
            ? GestureDetector(
                onTapUp: _add,
                child: Stack(fit: StackFit.passthrough, children: [
                  AspectRatio(
                      aspectRatio: _ctrl.value.aspectRatio,
                      child: VideoPlayer(_ctrl)),
                  CustomPaint(
                    painter: pts.length == 3
                        ? ParabolaPainter(pts)
                        : DotPainter(pts),
                  ),
                ]),
              )
            : Center(child: CircularProgressIndicator()),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          ElevatedButton(
              onPressed: () =>
                  _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play(),
              child: Text(_ctrl.value.isPlaying ? 'Pausar' : 'Reproducir')),
          ElevatedButton(onPressed: _goCalc, child: Text('Calcular')),
        ]),
      ]),
    );
  }
}

class ResultsScreen extends StatelessWidget {
  final List<Offset> points;
  ResultsScreen({required this.points});

  final jugCtrl = TextEditingController();
  final zonaCtrl = TextEditingController();

  Future<void> _export(GlobalKey key) async {
    final conn = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    final img = await conn?.toImage(pixelRatio: 2.0);
    final bytes = await img?.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    final fn = '${dir.path}/settrack_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(fn).writeAsBytes(bytes!.buffer.asUint8List());
    await GallerySaver.saveImage(fn);
  }

  @override
  Widget build(BuildContext c) {
    final h = (points[0].dy - points[1].dy).abs() * 0.01;
    final d = (points[2].dx - points[0].dx).abs() * 0.01;
    final t = 1.0, a = 45.0;
    final keyR = GlobalKey();

    return Scaffold(
      appBar: AppBar(title: Text('Resultados')),
      body: RepaintBoundary(
        key: keyR,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: jugCtrl, decoration: InputDecoration(labelText: 'Jugadora')),
            TextField(controller: zonaCtrl, decoration: InputDecoration(labelText: 'Zona')),
            SizedBox(height:20),
            Text('Altura: ${h.toStringAsFixed(2)} m'),
            Text('Distancia: ${d.toStringAsFixed(2)} m'),
            Text('Tiempo: ${t.toStringAsFixed(2)} s'),
            Text('Ángulo: ${a.toStringAsFixed(2)}°'),
            SizedBox(height: 20),
            ElevatedButton(onPressed: () async {
              final res = AnalysisResult(
                jugadora: jugCtrl.text,
                zona: zonaCtrl.text,
                altura: h, distancia: d, tiempo: t, angulo: a,
                fecha: DateTime.now(),
              );
              Navigator.pop(c, res);
            }, child: Text('Guardar')),
            ElevatedButton(onPressed: () => _export(keyR), child: Text('Exportar imagen')),
          ]),
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: Text('Historial')),
      body: ListView.builder(
        itemCount: historial.length,
        itemBuilder: (c,i){
          final h=historial[i];
          return ListTile(
            title: Text('${h.jugadora} – Zona ${h.zona}'),
            subtitle: Text('${h.altura.toStringAsFixed(2)} m, ${h.distancia.toStringAsFixed(2)} m'),
            trailing: Text('${h.fecha.day}/${h.fecha.month}/${h.fecha.year}'),
          );
        },
      ),
    );
  }
}

class DotPainter extends CustomPainter {
  final List<Offset> pts;
  DotPainter(this.pts);
  @override void paint(Canvas c, Size s){
    final p=Paint()..color=Colors.red..strokeWidth=8;
    for(final pt in pts) c.drawCircle(pt,4,p);
  }
  @override bool shouldRepaint(covariant CustomPainter) => true;
}

class ParabolaPainter extends CustomPainter {
  final List<Offset> pts;
  ParabolaPainter(this.pts);
  @override void paint(Canvas c, Size s){
    if (pts.length < 3) return;
    final p = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (double t = 0; t <= 1; t += 0.02) {
      final x = _lerp(pts[0].dx, pts[2].dx, t);
      final y = _quad(pts[0].dy, pts[1].dy, pts[2].dy, t);
      path.lineTo(x, y);
    }
    c.drawPath(path, p);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;
  double _quad(double a, double b, double c, double t) =>
      (1 - t) * (1 - t) * a + 2 * (1 - t) * t * b + t * t * c;

  @override bool shouldRepaint(CustomPainter o) => true;
}
