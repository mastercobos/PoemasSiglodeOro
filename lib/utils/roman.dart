const _vals = {
  'M': 1000, 'CM': 900, 'D': 500, 'CD': 400,
  'C': 100,  'XC': 90,  'L': 50,  'XL': 40,
  'X': 10,   'IX': 9,   'V': 5,   'IV': 4,  'I': 1,
};

/// Convierte una cadena romana pura a entero. Null si no es válida.
int? romanToInt(String s) {
  final str = s.trim().toUpperCase();
  if (str.isEmpty) return null;
  if (!RegExp(r'^M{0,4}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})$').hasMatch(str)) {
    return null;
  }
  int result = 0, i = 0;
  while (i < str.length) {
    if (i + 1 < str.length && _vals.containsKey(str.substring(i, i + 2))) {
      result += _vals[str.substring(i, i + 2)]!;
      i += 2;
    } else {
      result += _vals[str[i]] ?? 0;
      i++;
    }
  }
  return result > 0 ? result : null;
}

/// Extrae el valor romano del patrón "- N -" al inicio del título.
/// "- C -"             → 100
/// "- XIV - El amor"   → 14
/// "Amor eterno"       → null
int? _extraerRomanoFormato(String titulo) {
  final match = RegExp(r'^\s*-\s*([MDCLXVI]+)\s*-', caseSensitive: false)
      .firstMatch(titulo);
  if (match == null) return null;
  return romanToInt(match.group(1)!);
}

/// Compara dos títulos:
/// - Ambos con formato "- N -" → orden numérico.
/// - Solo uno con formato "- N -" → ese va primero.
/// - Ninguno → alfabético.
int compareTitulos(String a, String b) {
  final rA = _extraerRomanoFormato(a);
  final rB = _extraerRomanoFormato(b);

  if (rA != null && rB != null) return rA.compareTo(rB);
  if (rA != null) return -1; // los romanos primero
  if (rB != null) return 1;

  return a.toLowerCase().compareTo(b.toLowerCase());
}
