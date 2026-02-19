class Poema {
  final String titulo;
  final String autor;
  final String texto;

  const Poema({
    required this.titulo,
    required this.autor,
    required this.texto,
  });

  factory Poema.fromJson(Map<String, dynamic> json) {
    return Poema(
      titulo: (json['titulo'] as String?) ?? '',
      autor:  (json['autor']  as String?) ?? 'Autor desconocido',
      texto:  (json['texto']  as String?) ?? '',
    );
  }
}
