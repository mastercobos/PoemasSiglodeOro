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
  final minusculas = s.toLowerCase();
  // This runs over the full text of every poem at startup, so it scans code
  // units and copies the untouched stretches between replacements in bulk
  // rather than building a String per character. Every mapped character is in
  // the BMP, so surrogate halves pass through unchanged.
  StringBuffer? b;
  var desde = 0;
  for (var i = 0; i < minusculas.length; i++) {
    final String? reemplazo = switch (minusculas.codeUnitAt(i)) {
      0xE1 || 0xE0 || 0xE4 || 0xE2 || 0xE3 || 0xE5 => 'a', // á à ä â ã å
      0xE9 || 0xE8 || 0xEB || 0xEA => 'e', // é è ë ê
      0xED || 0xEC || 0xEF || 0xEE => 'i', // í ì ï î
      0xF3 || 0xF2 || 0xF6 || 0xF4 || 0xF5 => 'o', // ó ò ö ô õ
      0xFA || 0xF9 || 0xFC || 0xFB => 'u', // ú ù ü û
      0xE7 => 'c', // ç
      0xF1 => 'n~', // ñ
      _ => null,
    };
    if (reemplazo == null) continue;
    (b ??= StringBuffer())
      ..write(minusculas.substring(desde, i))
      ..write(reemplazo);
    desde = i + 1;
  }
  if (b == null) return minusculas;
  return (b..write(minusculas.substring(desde))).toString();
}

/// How an app orders poem titles within an author.
enum EstrategiaOrden {
  /// `"- I -"`, `"- II -"` … first in numeric order, then everything else
  /// alphabetically. The Spanish anthology's rule.
  romanosPrimero,

  /// Plain alphabetical. Sensible default for anthologies that don't number
  /// their poems.
  alfabetico,

  /// A numeral anywhere in the title sorts by value, not as text — `"Sonnet
  /// IX"` before `"Sonnet V"`, not after, and a two-part title like `"Canto
  /// IV III"` compares each part in turn. The English anthology's rule: it
  /// numbers sequences inline (`"Sonnet I"`, `"Sonnets from the Portuguese,
  /// I"`) rather than with the Spanish corpus's leading `"- N -"`, and often
  /// nests a second numeral for a sequence's own sub-parts.
  numeralesNaturales,
}

/// True for an ASCII or accented Latin letter — enough to tell a numeral
/// token from being glued to a word on either side, e.g. the "I" in "Vivian"
/// or the "X" in "Máximo" must never be read as a numeral.
bool _esLetra(int unidad) {
  if (unidad >= 0x41 && unidad <= 0x5A) return true; // A-Z
  if (unidad >= 0x61 && unidad <= 0x7A) return true; // a-z
  return unidad >= 0xC0 && unidad <= 0x24F; // accented Latin blocks
}

final _tokenNumeral = RegExp(r'[MDCLXVImdclxvi]+');

/// Splits a title into a sequence of text and numeral tokens, so a natural
/// (not lexical) comparison can walk them pairwise. `"Sonnet IX"` becomes
/// `["Sonnet ", 9]`; `"Canto IV III"` becomes `["Canto ", 4, " ", 3]`. A run
/// of roman-numeral letters only becomes a numeral token when it is a whole
/// word (not part of a longer one) *and* parses as well-formed — otherwise
/// it stays text, so "Maud", "Vivian" and "Mix" are never misread.
List<Object> _tokenizarTitulo(String titulo) {
  final tokens = <Object>[];
  final texto = StringBuffer();
  var i = 0;
  while (i < titulo.length) {
    final match = _tokenNumeral.matchAsPrefix(titulo, i);
    final limiteAntes = i == 0 || !_esLetra(titulo.codeUnitAt(i - 1));
    int? valor;
    if (match != null && limiteAntes) {
      final fin = match.end;
      final limiteDespues = fin >= titulo.length || !_esLetra(titulo.codeUnitAt(fin));
      if (limiteDespues) valor = romanoAEntero(match.group(0)!);
    }
    if (valor != null) {
      if (texto.isNotEmpty) {
        tokens.add(texto.toString());
        texto.clear();
      }
      tokens.add(valor);
      i = match!.end;
    } else {
      texto.writeCharCode(titulo.codeUnitAt(i));
      i++;
    }
  }
  if (texto.isNotEmpty) tokens.add(texto.toString());
  return tokens;
}

/// Compares two titles token by token: text against text folds and compares
/// as text, numeral against numeral compares by value. A numeral token
/// always sorts before a text token at the same position (so `"Sonnet I"`
/// comes before `"Sonnet Interlude"`), and once every token up to the
/// shorter title matches, the shorter one comes first (`"Part I"` before
/// `"Part I, Section I"`).
int _compararNatural(String a, String b) {
  final ta = _tokenizarTitulo(a);
  final tb = _tokenizarTitulo(b);
  final n = ta.length < tb.length ? ta.length : tb.length;
  for (var i = 0; i < n; i++) {
    final xa = ta[i], xb = tb[i];
    if (xa is int && xb is int) {
      if (xa != xb) return xa.compareTo(xb);
    } else if (xa is String && xb is String) {
      final fa = plegarParaOrden(xa), fb = plegarParaOrden(xb);
      if (fa != fb) return fa.compareTo(fb);
    } else {
      return xa is int ? -1 : 1;
    }
  }
  return ta.length.compareTo(tb.length);
}

/// Comparator for two display labels. Always returns a *total* order: ties on
/// the numeral fall through to the text, so a sort is stable across runs
/// (the old version returned 0 for two identical numerals and let the order
/// drift between launches).
int Function(String, String) comparadorDeTitulos(EstrategiaOrden estrategia) {
  return (a, b) {
    switch (estrategia) {
      case EstrategiaOrden.romanosPrimero:
        final nA = numeroDeTitulo(a);
        final nB = numeroDeTitulo(b);
        if (nA != null && nB != null && nA != nB) return nA.compareTo(nB);
        if (nA != null && nB == null) return -1;
        if (nA == null && nB != null) return 1;
        return plegarParaOrden(a).compareTo(plegarParaOrden(b));
      case EstrategiaOrden.numeralesNaturales:
        return _compararNatural(a, b);
      case EstrategiaOrden.alfabetico:
        return plegarParaOrden(a).compareTo(plegarParaOrden(b));
    }
  };
}
