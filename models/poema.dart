class Poema {
  final int id;       // índice en el array JSON, siempre único
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
}
