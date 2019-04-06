import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi/flutter_midi.dart';
import 'package:speech_recognition/speech_recognition.dart';
import 'package:button3d/button3d.dart';
import 'package:shimmer/shimmer.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext cxt) {
    return MaterialApp(
      title: 'talkPAD',
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: App(t: 'talkPAD'),
    );
  }
}

class App extends StatefulWidget {
  App({Key key, this.t}) : super(key: key);

  final String t;

  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  List<List<int>> _keys = new List(16);
  List<Isolate> _isols = new List(16);
  SpeechRecognition _sp;
  bool _rec = false;

  void _incrementCounter() async {
    FlutterMidi.playMidiNote(midi: 60);
    print(_isols);
    setState(() {
    });
  }

  static void _iCb(m) {
    Mes iMes = m as Mes;
    iMes.message.forEach((t) {
      iMes.sender.send((t > 100) ? t~/10 : t);
      sleep(Duration(milliseconds: (t > 100) ? 450 : 225));
    });
  }

  void _spawnIsol(List<int> tune, int i) async {
    ReceivePort rp = ReceivePort();
    _isols[i] = await Isolate.spawn(_iCb, Mes<List<int>>(sender: rp.sendPort, message: tune));
    rp.listen((t) => {
      FlutterMidi.playMidiNote(midi: t)
    });
  }

  @override
  void initState() {
    rootBundle.load("assets/b.sf2").then((sf2) {
      FlutterMidi.prepare(sf2: sf2, name: "b.sf2");
    });
    _keys[0] = [60, 70, 80];
    _keys[15] = [62, 62, 62, 670, 740, 72, 71, 69, 790, 740, 72, 71, 69, 790, 740, 72, 71, 72, 690];
    _keys[1] = [60];
    super.initState();
  }

  @override
  Widget build(BuildContext cxt) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.t),
      ),
      body: Container(
        child: GridView.count(
          crossAxisCount: 4,
          crossAxisSpacing: 10.0,
          mainAxisSpacing: 10.0,
          padding: EdgeInsets.all(10.0),
          children: _keys.asMap().entries.map((e) => GestureDetector(
            child: Button3d(
              style: Button3dStyle(
                topColor: Colors.tealAccent,
                backColor: Colors.blueAccent,
                borderRadius: BorderRadius.circular(20),
                z: 20.0,
                tappedZ: 8.0
              ),
              onPressed: () => _isols[e.key]?.kill(priority: Isolate.immediate),
              child: LayoutBuilder(builder: (cx, ct) => (e.value != null)
                ? Icon(Icons.music_note, size: ct.biggest.height / 1.7, color: Colors.blueAccent)
                : _rec
                  ? Shimmer.fromColors(
                    baseColor: Colors.blueAccent,
                    highlightColor: Colors.tealAccent,
                    child: Icon(Icons.file_download, size: ct.biggest.height / 1.7),
                  )
                  : Text('')
              )
            ),
            onTapDown: (t) => _spawnIsol(e.value, e.key),
          )).toList(),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton(
            onPressed: _incrementCounter,
            tooltip: 'Increment',
            child: Icon(Icons.add),
          ),
          FloatingActionButton(
            onPressed: _incrementCounter,
            tooltip: 'Increment',
            child: Icon(Icons.mic),
          ),
        ],
      ),
    );
  }
}

class Mes<T> {
  final SendPort sender;
  final T message;
  Mes({
      this.sender,
      this.message,
  });
}
