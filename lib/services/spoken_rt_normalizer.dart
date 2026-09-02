import '../models/scenario_models.dart';

/// Normaliserar svensk flygradiotelefoni till den kompakta notation som den
/// deterministiska validatorn använder. Rå ASR-text visas alltid separat.
class SpokenRtNormalizer {
  static const _digits = <String, String>{
    'zero': '0', 'oh': '0', 'one': '1', 'two': '2', 'three': '3',
    'four': '4', 'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
    'noll': '0', 'ett': '1', 'en': '1', 'två': '2', 'tva': '2', 'tre': '3',
    'fyra': '4', 'fem': '5', 'sex': '6', 'sju': '7', 'åtta': '8', 'atta': '8', 'nio': '9',
  };

  /// Svenskt bokstaveringsalfabet. Alternativa ASR-stavningar hanteras där
  /// de är vanliga (t.ex. Qvintus/Kvintus och Zäta/Zeta).
  static const _phonetic = <String, List<String>>{
    'A': ['adam'], 'B': ['bertil'], 'C': ['cesar', 'caesar'], 'D': ['david'],
    'E': ['erik', 'eric'], 'F': ['filip', 'philip'], 'G': ['gustav'], 'H': ['helge'],
    'I': ['ivar'], 'J': ['johan'], 'K': ['kalle'], 'L': ['ludvig'], 'M': ['martin'],
    'N': ['niklas', 'niclas'], 'O': ['olof'], 'P': ['petter'],
    'Q': ['qvintus', 'kvintus', 'quintus'], 'R': ['rudolf'], 'S': ['sigurd'],
    'T': ['tore'], 'U': ['urban'], 'V': ['viktor', 'victor'], 'W': ['wilhelm'],
    'X': ['xerxes'], 'Y': ['yngve'], 'Z': ['zäta', 'zeta'],
    'Å': ['åke', 'ake'], 'Ä': ['ärlig', 'arlig'], 'Ö': ['östen', 'osten'],
  };

  String normalize(String raw, ExpectedReadback expected) {
    var text = raw.toLowerCase();

    // Gör bokstaveringen generell: aktuell registrering styr vad som kan
    // normaliseras. Ingen specifik SE-registrering är hårdkodad.
    text = _normalizeExpectedCallsign(text, expected.callsign,
        allowAbbreviated: expected.allowAbbreviatedCallsign);

    text = _normalizeFrequency(text);
    text = _normalizeDigitSequenceAfter(text, RegExp(r'\b(?:runway|rwy|bana)\s+'), maxDigits: 2);
    text = _normalizeDigitSequenceAfter(text, RegExp(r'\bqnh\s+'), maxDigits: 4);
    text = _normalizeDigitSequenceAfter(text, RegExp(r'\b(?:squawk|transponder|transponderkod)\s+'), maxDigits: 4);

    final compact = expected.callsign.toLowerCase().replaceAll('-', '');
    final suffix = compact.substring(compact.length - 3);
    text = text.replaceAll(
      RegExp(r'\bse\s*[- ]?\s*' + suffix + r'\b', caseSensitive: false),
      expected.callsign,
    );

    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _normalizeExpectedCallsign(String input, String callsign,
      {required bool allowAbbreviated}) {
    final compact = callsign.toUpperCase().replaceAll('-', '');
    if (compact.length != 5 || !compact.startsWith('SE')) return input;

    final fullWords = compact.split('').map(_wordPattern).join(r'[\s,.-]+');
    var output = input.replaceAll(RegExp(r'\b' + fullWords + r'\b', caseSensitive: false), callsign);

    // Standardförkortning för registrering: första tecknet + de två sista.
    final shortLetters = '${compact[0]}${compact.substring(compact.length - 2)}';
    final shortText = '${shortLetters[0]}-${shortLetters.substring(1)}';
    final shortWords = shortLetters.split('').map(_wordPattern).join(r'[\s,.-]+');
    output = output.replaceAll(RegExp(r'\b' + shortWords + r'\b', caseSensitive: false), shortText);
    return output;
  }

  String _wordPattern(String letter) {
    final words = _phonetic[letter] ?? [letter.toLowerCase()];
    return '(?:${words.map(RegExp.escape).join('|')})';
  }

  String _normalizeFrequency(String input) {
    final pattern = RegExp(
      r'\b((?:one|two|three|four|five|six|seven|eight|nine|zero|oh|noll|ett|en|två|tva|tre|fyra|fem|sex|sju|åtta|atta|nio)[\s-]+){2,3}(?:decimal|point|dot|komma|punkt)[\s-]+((?:one|two|three|four|five|six|seven|eight|nine|zero|oh|noll|ett|en|två|tva|tre|fyra|fem|sex|sju|åtta|atta|nio)(?:[\s-]+|\b)){2,3}',
      caseSensitive: false,
    );
    return input.replaceAllMapped(pattern, (m) {
      final whole = m.group(0)!;
      final parts = whole.split(RegExp(r'\b(?:decimal|point|dot|komma|punkt)\b', caseSensitive: false));
      if (parts.length != 2) return whole;
      final left = _wordsToDigits(parts[0]);
      final right = _wordsToDigits(parts[1]);
      if (left.length < 3 || right.length < 2) return whole;
      return '$left.$right';
    });
  }

  String _normalizeDigitSequenceAfter(String input, RegExp prefix, {required int maxDigits}) {
    const digitWords = 'zero|oh|one|two|three|four|five|six|seven|eight|nine|noll|ett|en|två|tva|tre|fyra|fem|sex|sju|åtta|atta|nio';

    // Match only the actual number tokens after the keyword. In v0.4.3 the
    // regex also consumed the whitespace after the last spoken digit. That
    // could turn "bana noll ett QNH" into "bana 01qnh", which then made both
    // runway and QNH invisible to the validator. This pattern deliberately
    // leaves the following separator untouched and also accepts mixed ASR
    // output such as "427 två".
    final atom = '(?:[0-9]+|$digitWords)';
    final p = RegExp(
      '(${prefix.pattern})($atom(?:[\\s-]+$atom){0,${maxDigits - 1}})',
      caseSensitive: false,
    );

    return input.replaceAllMapped(p, (m) {
      final head = m.group(1)!;
      final tail = m.group(2)!;
      final digits = _tokensToDigits(tail);
      if (digits.isEmpty || digits.length > maxDigits) return m.group(0)!;
      return '$head$digits';
    });
  }

  String _tokensToDigits(String value) {
    final tokens = value
        .toLowerCase()
        .split(RegExp(r'[\s-]+'))
        .where((e) => e.isNotEmpty);
    final buffer = StringBuffer();
    for (final token in tokens) {
      if (RegExp(r'^\d+$').hasMatch(token)) {
        buffer.write(token);
      } else {
        buffer.write(_digits[token] ?? '');
      }
    }
    return buffer.toString();
  }

  String _wordsToDigits(String value) {
    final words = value.toLowerCase().split(RegExp(r'[^a-zåäö]+')).where((e) => e.isNotEmpty);
    return words.map((word) => _digits[word] ?? '').join();
  }
}
