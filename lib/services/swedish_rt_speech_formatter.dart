/// Deterministic presentation layer for Swedish radiotelephony speech.
///
/// The scenario text remains the normative source of truth (for example
/// `SE-VPT, bana 19, QNH 1009.`). This formatter converts that text into a
/// pronunciation-oriented script for TTS without changing the underlying
/// operational values.
class SwedishRtSpeechFormatter {
  static const _letters = <String, String>{
    'A': 'Adam',
    'B': 'Bertil',
    'C': 'Cesar',
    'D': 'David',
    'E': 'Erik',
    'F': 'Filip',
    'G': 'Gustav',
    'H': 'Helge',
    'I': 'Ivar',
    'J': 'Johan',
    'K': 'Kalle',
    'L': 'Ludvig',
    'M': 'Martin',
    'N': 'Niklas',
    'O': 'Olof',
    'P': 'Petter',
    'Q': 'Qvintus',
    'R': 'Rudolf',
    'S': 'Sigurd',
    'T': 'Tore',
    'U': 'Urban',
    'V': 'Viktor',
    'W': 'Wilhelm',
    'X': 'Xerxes',
    'Y': 'Yngve',
    'Z': 'Zäta',
    'Å': 'Åke',
    'Ä': 'Ärlig',
    'Ö': 'Östen',
  };

  static const _digits = <String, String>{
    '0': 'nolla',
    '1': 'ett',
    '2': 'tvåa',
    '3': 'trea',
    '4': 'fyra',
    '5': 'femma',
    '6': 'sexa',
    '7': 'sju',
    '8': 'åtta',
    '9': 'nia',
  };

  String format(String source) {
    var text = source.trim();

    // Full Swedish registration, e.g. SE-VPT.
    text = text.replaceAllMapped(
      RegExp(r'\bSE-([A-ZÅÄÖ]{3})\b', caseSensitive: false),
      (match) => _spellLetters('SE${match.group(1)!.toUpperCase()}'),
    );

    // Standard abbreviated callsign, e.g. S-QX.
    text = text.replaceAllMapped(
      RegExp(r'\bS-([A-ZÅÄÖ]{2})\b', caseSensitive: false),
      (match) => _spellLetters('S${match.group(1)!.toUpperCase()}'),
    );

    // Frequencies are intentionally handled before other generic number
    // groups. Swedish RT uses digit-by-digit pronunciation.
    text = text.replaceAllMapped(
      RegExp(r'\b(\d{3})[\.,](\d{3})\b'),
      (match) => '${_spellDigits(match.group(1)!)} komma ${_spellDigits(match.group(2)!)}',
    );

    text = text.replaceAllMapped(
      RegExp(r'\bQNH\s+(\d{3,4})\b', caseSensitive: false),
      (match) => 'ku enn Helge ${_spellDigits(match.group(1)!)}',
    );

    text = text.replaceAllMapped(
      RegExp(r'\bbana\s+(\d{2})\b', caseSensitive: false),
      (match) => 'bana ${_spellDigits(match.group(1)!)}',
    );

    text = text.replaceAllMapped(
      RegExp(r'\btransponder\s+(\d{4})\b', caseSensitive: false),
      (match) => 'transponder ${_spellDigits(match.group(1)!)}',
    );

    // If QNH appears without a value, still force the Swedish aviation
    // pronunciation rather than leaving the acronym to a generic TTS model.
    // The lower-case pronunciation cue is deliberate: generic TTS otherwise
    // tends to separate Q and N too much. In Swedish RT this is intended to
    // sound as the compact Swedish RT expression 'Q N Helge'. The internal
    // acoustic cue 'ku enn Helge' is intentionally pronunciation-oriented;
    // the normative scenario text remains QNH and is never changed.
    text = text.replaceAll(RegExp(r'\bQNH\b', caseSensitive: false), 'ku enn Helge');

    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _spellLetters(String value) {
    return value
        .split('')
        .map((letter) => _letters[letter] ?? letter)
        .join(' ');
  }

  String _spellDigits(String value) {
    return value
        .split('')
        .map((digit) => _digits[digit] ?? digit)
        .join(' ');
  }
}
