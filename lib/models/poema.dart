class Poema {
  final int id;
  final String titulo;
  final String autor;
  final String texto;

  const Poema({
    required this.id,
    required this.titulo,
    required this.autor,
    required this.texto,
  });

  factory Poema.fromJson(Map<String, dynamic> json, {required int index}) {
    return Poema(
      id:     index,
      titulo: (json['titulo'] as String?) ?? '',
      autor:  (json['autor']  as String?) ?? 'Autor desconocido',
      texto:  (json['texto']  as String?) ?? '',
    );
  }

  /// Primer verso no vacío del poema.
  String get primerVerso {
    return texto
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  }

  /// Etiqueta para mostrar en listas: título si existe, o primer verso.
  String get etiqueta => titulo.trim().isNotEmpty ? titulo : primerVerso;

  /// true si el título parece ser un número romano puro.
  bool get tituloEsRomano {
    final t = titulo.trim();
    return t.isNotEmpty &&
        RegExp(r'^[MDCLXVI]+$').hasMatch(t.toUpperCase());
  }
}
