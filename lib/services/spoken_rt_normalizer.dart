import '../models/scenario_models.dart';

/// Normaliserar svensk flygradiotelefoni till den kompakta notation som den
/// deterministiska validatorn använder. Rå ASR-text visas alltid separat.
class SpokenRtNormalizer {
  static const _digits = <String, String>{
    'zero': '0', 'oh': '0', 'one': '1', 'two': '2', 'three': '3',
    'four': '4', 'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
    'noll': '0', 'nolla': '0', 'ett': '1', 'en': '1', 'två': '2', 'tva': '2', 'tvåa': '2', 'tvaa': '2', 'tre': '3', 'trea': '3',
    'fyra': '4', 'fem': '5', 'femma': '5', 'sex': '6', 'sexa': '6', 'sju': '7', 'åtta': '8', 'atta': '8', 'nio': '9', 'nia': '9',
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

    // ASR often hears the Swedish RT expression "Q N Helge" as forms
    // such as "Tune Helge". Normalize only the QNH label here; the
    // pressure digits are still taken strictly from what the learner said.
    text = _normalizeQnhLabel(text);

    text = _normalizeFrequency(text);
    text = _normalizeFrequencyWithoutSeparator(text, expected.frequency);
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


  String _normalizeQnhLabel(String input) {
    return input
        .replaceAll(
          RegExp(r'\b(?:q\s*n|ku\s+en+n?|tune|tun)\s+helge\b', caseSensitive: false),
          'qnh',
        )
        .replaceAll(
          RegExp(r'\bqnh\s+helge\b', caseSensitive: false),
          'qnh',
        );
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
    // Spoken frequencies occur both with and without an explicit decimal
    // marker.  Keep this parser deliberately value-driven: it converts the
    // digits the learner actually said and never substitutes the expected
    // frequency from scenario context.
    //
    // Examples accepted here:
    //   "ett två fyra komma sju två fem"
    //   "ett tvåa fyra punkt sju tvåa femma"
    //   "124 komma 725"
    const digitWords =
        'three|seven|eight|zero|four|five|nine|one|two|six|oh|'
        'nolla|tvåa|tvaa|trea|femma|sexa|nia|noll|ett|en|två|tva|'
        'tre|fyra|fem|sex|sju|åtta|atta|nio';
    final atom = '(?:[0-9]|$digitWords)';

    // Fully spoken, digit-by-digit form with an explicit separator.
    final spoken = RegExp(
      r'\b(' + atom + r'(?:[\s-]+' + atom + r'){2})'
      r'[\s,.-]*(?:decimal|point|dot|komma|punkt)[\s,.-]*'
      r'(' + atom + r'(?:[\s-]+' + atom + r'){1,2})\b',
      caseSensitive: false,
    );

    var output = input.replaceAllMapped(spoken, (m) {
      final left = _tokensToDigits(m.group(1)!);
      final right = _tokensToDigits(m.group(2)!);
      if (left.length != 3 || right.length < 2 || right.length > 3) {
        return m.group(0)!;
      }
      final mhz = int.tryParse(left);
      if (mhz == null || mhz < 118 || mhz > 136) return m.group(0)!;
      return '$left.$right';
    });

    // ASR can collapse one side into digits while preserving the spoken word
    // "komma", e.g. "124 komma 725".  Normalise that form as well.
    output = output.replaceAllMapped(
      RegExp(
        r'\b(1[1-3][0-9])\s*(?:decimal|point|dot|komma|punkt)\s*([0-9]{2,3})\b',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}.${m.group(2)}',
    );

    return output;
  }

  String _normalizeFrequencyWithoutSeparator(String input, String? expectedFrequency) {
    if (expectedFrequency == null) return input;

    // In real Swedish RT the decimal separator is often omitted in speech,
    // e.g. "ett två fyra sju två fem" for 124.725. Recognise a six-digit
    // spoken group in the aviation VHF range and insert the decimal point.
    const digitWords = 'three|seven|eight|zero|four|five|nine|one|two|six|oh|nolla|tvåa|tvaa|trea|femma|sexa|nia|noll|ett|en|två|tva|tre|fyra|fem|sex|sju|åtta|atta|nio';
    final atom = '(?:[0-9]|$digitWords)';
    final pattern = RegExp(
      r'\b(' + atom + r'(?:[\s-]+' + atom + r'){5})\b',
      caseSensitive: false,
    );

    return input.replaceAllMapped(pattern, (m) {
      final digits = _tokensToDigits(m.group(1)!);
      if (digits.length != 6) return m.group(0)!;
      final mhz = int.tryParse(digits.substring(0, 3));
      if (mhz == null || mhz < 118 || mhz > 136) return m.group(0)!;
      return '${digits.substring(0, 3)}.${digits.substring(3)}';
    });
  }

  String _normalizeDigitSequenceAfter(String input, RegExp prefix, {required int maxDigits}) {
    const digitWords = 'three|seven|eight|zero|four|five|nine|one|two|six|oh|nolla|tvåa|tvaa|trea|femma|sexa|nia|noll|ett|en|två|tva|tre|fyra|fem|sex|sju|åtta|atta|nio';

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
