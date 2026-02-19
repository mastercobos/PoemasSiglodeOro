import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/poema.dart';
import 'screens/root_screen.dart';

void main() => runApp(const PoemasApp());

class PoemasApp extends StatelessWidget {
  const PoemasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antología Poética',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B2F2F)),
        splashColor: const Color(0x228B6914),
        highlightColor: const Color(0x118B6914),
      ),
      home: const _Loader(),
    );
  }
}

class _Loader extends StatefulWidget {
  const _Loader();
  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  List<Poema>? _poemas;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/poemas.json');
      final decoded = jsonDecode(raw);
      final list = decoded is List ? decoded : (decoded as Map)['poemas'] as List;
      setState(() => _poemas =
          list.map((e) => Poema.fromJson(Map<String, dynamic>.from(e as Map))).toList());
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFDF6EC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error al cargar los poemas:\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
          ),
        ),
      );
    }
    if (_poemas == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF3B2F2F),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_stories, size: 72, color: Color(0xFFD4AF6A)),
              SizedBox(height: 28),
              CircularProgressIndicator(color: Color(0xFFD4AF6A)),
            ],
          ),
        ),
      );
    }
    return RootScreen(poemas: _poemas!);
  }
}
