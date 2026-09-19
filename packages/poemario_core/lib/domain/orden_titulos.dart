/// Title ordering.
///
/// Was `utils/roman.dart`. Two changes:
///
/// 1. The roman-numeral rule is now *optional*. Putting "- XIV -" before
///    everything else is right for a Spanish Golden Age anthology and is
///    meaningless noise for an English one, so each app picks a strategy in
///    its `AppConfig`.
/// 2. Comparison is diacritic-aware. `'Ángel'.toLowerCase().compareTo('Antonio')`
///    put Ángel *after* Zorrilla, because 'á' sits above 'z' in code-unit order.
///    Spanish readers noticed.
library;

const _valores = <String, int>{
  'M': 1000, 'CM': 900, 'D': 500, 'CD': 400, //
  'C': 100, 'XC': 90, 'L': 50, 'XL': 40, //
  'X': 10, 'IX': 9, 'V': 5, 'IV': 4, 'I': 1,
};

final _romanoValido =
    RegExp(r'^M{0,4}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})$');

final _formatoGuiones =
    RegExp(r'^\s*[-–—]\s*([MDCLXVI]+)\s*[-–—]', caseSensitive: false);

/// Parses a well-formed roman numeral. Returns null for anything else.
int? romanoAEntero(String s) {
  final str = s.trim().toUpperCase();
  if (str.isEmpty || !_romanoValido.hasMatch(str)) return null;
  var resultado = 0;
  var i = 0;
  while (i < str.length) {
    final par = i + 1 < str.length ? str.substring(i, i + 2) : null;
    if (par != null && _valores.containsKey(par)) {
      resultado += _valores[par]!;
      i += 2;
    } else {
      resultado += _valores[str[i]] ?? 0;
      i++;
    }
  }
  return resultado > 0 ? resultado : null;
}

/// Pulls the numeral out of the `"- XIV - El amor"` pattern used by the
/// Spanish source data. Also accepts en and em dashes, which crept into the
/// JSON at some point and previously sorted alphabetically by accident.
int? numeroDeTitulo(String titulo) {
  final match = _formatoGuiones.firstMatch(titulo);
  if (match == null) return null;
  return romanoAEntero(match.group(1)!);
}

/// Folds a string to a comparable form: lowercase, diacritics removed.
///
/// 'ñ' maps to 'n~' so that it sorts immediately after every 'n' word, which
/// is what Spanish alphabetisation expects, without needing a full collator.
String plegarParaOrden(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    b.write(switch (String.fromCharCode(r)) {
      'á' || 'à' || 'ä' || 'â' || 'ã' || 'å' => 'a',
      'é' || 'è' || 'ë' || 'ê' => 'e',
      'í' || 'ì' || 'ï' || 'î' => 'i',
      'ó' || 'ò' || 'ö' || 'ô' || 'õ' => 'o',
      'ú' || 'ù' || 'ü' || 'û' => 'u',
      'ç' => 'c',
      'ñ' => 'n~',
      final otro => otro,
    });
  }
  return b.toString();
}

/// How an app orders poem titles within an author.
enum EstrategiaOrden {
  /// `"- I -"`, `"- II -"` … first in numeric order, then everything else
  /// alphabetically. The Spanish anthology's rule.
  romanosPrimero,

  /// Plain alphabetical. Sensible default for anthologies that don't number
  /// their poems.
  alfabetico,
}

/// Comparator for two display labels. Always returns a *total* order: ties on
/// the numeral fall through to the text, so a sort is stable across runs
/// (the old version returned 0 for two identical numerals and let the order
/// drift between launches).
int Function(String, String) comparadorDeTitulos(EstrategiaOrden estrategia) {
  return (a, b) {
    if (estrategia == EstrategiaOrden.romanosPrimero) {
      final nA = numeroDeTitulo(a);
      final nB = numeroDeTitulo(b);
      if (nA != null && nB != null && nA != nB) return nA.compareTo(nB);
      if (nA != null && nB == null) return -1;
      if (nA == null && nB != null) return 1;
    }
    return plegarParaOrden(a).compareTo(plegarParaOrden(b));
  };
}
