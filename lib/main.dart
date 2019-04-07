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
  List<Isolate> _isols = new List(17);
  SpeechRecognition _sr;
  bool _isRec = false, _doneRec = false;
  String _trans = '';

  void initSR() {
    _sr = new SpeechRecognition();
    _sr.setRecognitionResultHandler((String t) => setState(() => _trans = t));
    _sr.setAvailabilityHandler((bool a) => setState(() => _isRec = a));
    _sr.setRecognitionCompleteHandler(() => setState(() {
      _isRec = false;
      if (_trans != '' && !_doneRec) {
        _doneRec = true;
        _playTune(s2t(_trans), 16);
      }
    }));
    _sr.activate();
  }

  static void _isolCb(Mes m) {
    Mes iMes = m;
    iMes.m.forEach((t) {
      iMes.s.send((t > 34) ? t~/10 : t);
      sleep(Duration(milliseconds: (t > 100) ? 450 : 225));
    });
  }

  void _playTune(List<int> tune, int i) async {
    ReceivePort rp = ReceivePort();
    _isols[i] = await Isolate.spawn(_isolCb, Mes<List<int>>(s: rp.sendPort, m: tune));
    rp.listen((t) {
      FlutterMidi.playMidiNote(midi: t + 50);
    });
  }

  void _saveTune(int k) {
    _keys[k] = s2t(_trans);
    clrSR();
  }

  void clrSR() {
    _isols[16]?.kill(priority: Isolate.immediate);
    setState(() {
      _doneRec = false;
      _trans = '';
    });
  }

  @override
  void initState() {
    rootBundle.load("assets/b.sf2").then((sf2) {
      FlutterMidi.prepare(sf2: sf2, name: "b.sf2");
    });
    initSR();
    _keys[0] = [0, 10, 20];
    _keys[15] = [2, 2, 2, 70, 140, 12, 11, 9, 190, 140, 12, 11, 9, 190, 140, 12, 11, 12, 90];
    _keys[1] = [10];
    _keys[2] = [0];
    _keys[3] = [34];
    super.initState();
  }

  @override
  Widget build(BuildContext cxt) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.t),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: GridView.count(
              primary: false,
              crossAxisCount: 4,
              crossAxisSpacing: 10.0,
              mainAxisSpacing: 10.0,
              padding: EdgeInsets.all(10.0),
              children: _keys.asMap().entries.map((e) => IgnorePointer(
                ignoring: _isRec,
                child: GestureDetector(
                  excludeFromSemantics: true,
                  child: Button3d(
                    style: Button3dStyle(
                      topColor: Colors.tealAccent,
                      backColor: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(20),
                      z: 20.0,
                      tappedZ: 8.0
                    ),
                    onPressed: () => _isols[e.key]?.kill(priority: Isolate.immediate),
                    child: LayoutBuilder(builder: (cx, ct) => (e.value != null) ? Icon(
                      Icons.music_note,
                      size: ct.biggest.height / 1.7,
                      color: Colors.blueAccent
                    ) : _doneRec ? Shimmer.fromColors(
                      baseColor: Colors.blueAccent,
                      highlightColor: Colors.tealAccent,
                      child: Icon(Icons.file_download, size: ct.biggest.height / 1.7),
                    ) : Text(''))
                  ),
                  onTapDown: (t) => _doneRec ? _saveTune(e.key) : _playTune(e.value, e.key),
                )
              )).toList(),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(_trans.split(' ').last)
          )
        ],
      ),
      floatingActionButton: _doneRec ? FloatingActionButton(
        onPressed: clrSR,
        backgroundColor: Colors.red,
        child: Icon(Icons.clear),
      ) : FloatingActionButton(
        onPressed: () => !_isRec ? _sr.listen(locale: 'en_US') : null,
        child: Icon(Icons.mic),
      ),
    );
  }
}

class Mes<T> {
  final SendPort s;
  final T m;
  Mes({
      this.s,
      this.m,
  });
}

List<int> s2t(String s) => s
  .toLowerCase()
  .replaceAll(new RegExp(r"'"), '')
  .split(' ')
  .map((w) => w.split('').fold(0, (t, s) => t + s.codeUnitAt(0) - 96))
  .map((n) => (n > 34) ? n % 34 * ((n ~/ 34) % 2 * 9 + 1) : n)
  .toList().cast<int>();
