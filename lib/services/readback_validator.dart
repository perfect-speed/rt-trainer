import '../models/scenario_models.dart';

class ReadbackValidator {
  ValidationResult validate({
    required String transmission,
    required ExpectedReadback expected,
  }) {
    final normalized = _normalize(transmission);
    final items = <ValidationItem>[
      _checkCallsign(expected.callsign, normalized, allowAbbreviated: expected.allowAbbreviatedCallsign),
      if (expected.runway != null)
        _checkRunway(expected.runway!, normalized)
      else
        ..._unexpectedRunway(normalized),
      if (expected.qnh != null)
        _checkQnh(expected.qnh!, normalized)
      else
        ..._unexpectedQnh(normalized),
      if (expected.squawk != null)
        _checkSquawk(expected.squawk!, normalized)
      else
        ..._unexpectedSquawk(normalized),
      if (expected.frequency != null)
        _checkFrequency(expected.frequency!, normalized)
      else
        ..._unexpectedFrequency(normalized),
    ];

    final problems = items
        .where((e) => e.status != ValidationStatus.correct && e.status != ValidationStatus.warning)
        .toList();

    final warnings = items.where((e) => e.status == ValidationStatus.warning).toList();

    if (problems.isEmpty) {
      return ValidationResult(
        items: items,
        isComplete: true,
        feedback: warnings.isEmpty
            ? 'Korrekt. Alla obligatoriska delar i denna transmission stämmer.'
            : 'Innehållet är korrekt. Fraseologi: ${warnings.map((w) => w.expected).join(' · ')}.',
        atcResponse: '${expected.callsign}, återläsning korrekt.',
      );
    }

    final first = problems.first;
    final response = _atcCorrection(first, expected);

    final descriptions = problems.map((item) {
      final label = _swedishLabel(item.label);
      switch (item.status) {
        case ValidationStatus.warning:
          return '$label: rätt uppgift, använd ${item.expected}';
        case ValidationStatus.incorrect:
          return '$label: du angav ${item.observed}, väntat ${item.expected}';
        case ValidationStatus.missing:
          return '$label: saknas';
        case ValidationStatus.unexpected:
          return '$label: extra uppgift ${item.observed ?? ''}'.trim();
        case ValidationStatus.correct:
          return '';
      }
    }).where((text) => text.isNotEmpty).join(' · ');

    return ValidationResult(
      items: items,
      isComplete: false,
      feedback: 'Återläsningen behöver korrigeras. $descriptions.',
      atcResponse: response,
    );
  }

  String _swedishLabel(String label) => switch (label) {
        'Callsign' => 'Anropssignal',
        'Runway' => 'Bana',
        'Squawk' => 'Transponderkod',
        'Frequency' => 'Frekvens',
        _ => label,
      };

  String _atcCorrection(ValidationItem first, ExpectedReadback expected) {
    if (first.status == ValidationStatus.unexpected) {
      return '${expected.callsign}, repetera återläsning.';
    }

    return switch (first.label) {
      'Runway' => first.status == ValidationStatus.incorrect
          ? '${expected.callsign}, negativ, bana ${expected.runway}, bekräfta.'
          : '${expected.callsign}, bana ${expected.runway}, bekräfta.',
      'QNH' => first.status == ValidationStatus.incorrect
          ? '${expected.callsign}, negativ, QNH ${expected.qnh}, bekräfta.'
          : '${expected.callsign}, QNH ${expected.qnh}, bekräfta.',
      'Squawk' => first.status == ValidationStatus.incorrect
          ? '${expected.callsign}, negativ, transponder ${expected.squawk}, bekräfta.'
          : '${expected.callsign}, transponder ${expected.squawk}, bekräfta.',
      'Frequency' => first.status == ValidationStatus.incorrect
          ? '${expected.callsign}, negativ, frekvens ${expected.frequency}, repetera.'
          : '${expected.callsign}, frekvens ${expected.frequency}, repetera.',
      'Callsign' => first.status == ValidationStatus.incorrect
          ? '${expected.callsign}, anropssignal ${expected.callsign}, repetera.'
          : 'Anropande station, repetera anropssignal.',
      _ => '${expected.callsign}, repetera återläsning.',
    };
  }

  ValidationItem _checkCallsign(
    String expected,
    String normalized, {
    required bool allowAbbreviated,
  }) {
    final expectedCanonical = expected.toUpperCase();

    // Full Swedish registration callsign, e.g. SE-KQX / SE KQX.
    final fullMatches = RegExp(r'\bse\s*[- ]?\s*([a-z]{3})\b')
        .allMatches(normalized)
        .toList();

    if (fullMatches.isNotEmpty) {
      final lastMatch = fullMatches.last;
      final observedCanonical = 'SE-${lastMatch.group(1)!.toUpperCase()}';

      if (observedCanonical != expectedCanonical) {
        return ValidationItem(
          label: 'Callsign',
          expected: '$expected sist',
          observed: observedCanonical,
          status: ValidationStatus.incorrect,
        );
      }

      final trailingText = normalized.substring(lastMatch.end).trim();
      final isLast = _isOnlyTrailingPunctuation(trailingText);

      return ValidationItem(
        label: 'Callsign',
        expected: '$expected sist',
        observed: isLast ? expected : '$expected ej sist',
        status: isLast ? ValidationStatus.correct : ValidationStatus.incorrect,
      );
    }

    // Recognise an abbreviated registration callsign instead of calling it
    // "missing". For SE-KQX the standard shortened textual form is S-QX.
    final suffix = expectedCanonical.replaceAll('-', '');
    final shortExpected = '${suffix[0]}-${suffix.substring(suffix.length - 2)}';
    final shortCompact = shortExpected.replaceAll('-', '').toLowerCase();
    final shortPattern = RegExp(r'\b' + shortCompact[0] + r'\s*[- ]?\s*' + shortCompact.substring(1) + r'\b');
    final shortMatches = shortPattern.allMatches(normalized).toList();

    if (shortMatches.isNotEmpty) {
      final lastMatch = shortMatches.last;
      final trailingText = normalized.substring(lastMatch.end).trim();
      final isLast = _isOnlyTrailingPunctuation(trailingText);

      if (allowAbbreviated && isLast) {
        return ValidationItem(
          label: 'Callsign',
          expected: '$shortExpected eller $expected sist',
          observed: shortExpected,
          status: ValidationStatus.correct,
        );
      }

      return ValidationItem(
        label: 'Callsign',
        expected: allowAbbreviated ? '$shortExpected eller $expected sist' : '$expected sist',
        observed: '$shortExpected (förkortad)',
        status: ValidationStatus.incorrect,
      );
    }

    // Also recognise a callsign-like but non-standard shortening such as
    // SEQX / SE-QX / SE QX. It is not an accepted standard abbreviation for
    // SE-KQX, but it is clearly an attempted callsign and must therefore be
    // reported as incorrect rather than missing.
    final lastTwo = suffix.substring(suffix.length - 2).toLowerCase();
    final nonStandardShortPattern = RegExp(
      r'\bse\s*[- ]?\s*' + lastTwo + r'\b',
    );
    final nonStandardMatches = nonStandardShortPattern.allMatches(normalized).toList();
    if (nonStandardMatches.isNotEmpty) {
      final lastMatch = nonStandardMatches.last;
      final observedRaw = normalized.substring(lastMatch.start, lastMatch.end)
          .replaceAll(' ', '')
          .toUpperCase();
      final observed = observedRaw.contains('-')
          ? observedRaw
          : 'SE-${observedRaw.substring(2)}';
      return ValidationItem(
        label: 'Callsign',
        expected: allowAbbreviated ? '$shortExpected eller $expected sist' : '$expected sist',
        observed: '$observed (avvikande förkortning)',
        status: ValidationStatus.incorrect,
      );
    }

    return ValidationItem(
      label: 'Callsign',
      expected: allowAbbreviated ? '$shortExpected eller $expected sist' : '$expected sist',
      observed: null,
      status: ValidationStatus.missing,
    );
  }

  bool _isOnlyTrailingPunctuation(String text) {
    // Speech-to-text normally terminates an utterance with punctuation.
    // Punctuation after the callsign must not make it look as if words
    // followed the callsign.
    return RegExp(r'^[\s.,;:!?]*$').hasMatch(text);
  }

  static const _swedishRunwayNumbers = <String, int>{
    'tio': 10, 'elva': 11, 'tolv': 12, 'tretton': 13, 'fjorton': 14,
    'femton': 15, 'sexton': 16, 'sjutton': 17, 'arton': 18, 'nitton': 19,
    'tjugo': 20, 'tjugoett': 21, 'tjugo ett': 21, 'tjugotvå': 22, 'tjugo två': 22,
    'tjugotre': 23, 'tjugo tre': 23, 'tjugofyra': 24, 'tjugo fyra': 24,
    'tjugofem': 25, 'tjugo fem': 25, 'tjugosex': 26, 'tjugo sex': 26,
    'tjugosju': 27, 'tjugo sju': 27, 'tjugoåtta': 28, 'tjugo åtta': 28,
    'tjugonio': 29, 'tjugo nio': 29, 'trettio': 30, 'trettioett': 31,
    'trettio ett': 31, 'trettiotvå': 32, 'trettio två': 32, 'trettiotre': 33,
    'trettio tre': 33, 'trettiofyra': 34, 'trettio fyra': 34, 'trettiofem': 35,
    'trettio fem': 35, 'trettiosex': 36, 'trettio sex': 36,
  };

  ValidationItem _checkRunway(String expected, String normalized) {
    final digitMatch = RegExp(r'\b(?:runway|rwy|bana)\s*([0-3]?\d)\b')
        .firstMatch(normalized);
    if (digitMatch != null) {
      final observed = digitMatch.group(1)!.padLeft(2, '0');
      return ValidationItem(
        label: 'Runway', expected: expected, observed: observed,
        status: observed == expected.padLeft(2, '0')
            ? ValidationStatus.correct : ValidationStatus.incorrect,
      );
    }

    // Begripligt men icke-standardiserat uttal, t.ex. "bana nitton".
    // Rätt bana ger fraseologivarning; fel bana är fortfarande sakfel.
    final lower = normalized.toLowerCase();
    for (final entry in _swedishRunwayNumbers.entries) {
      final match = RegExp(r'\b(?:runway|rwy|bana)\s+' + RegExp.escape(entry.key) + r'\b')
          .firstMatch(lower);
      if (match == null) continue;
      final observed = entry.value.toString().padLeft(2, '0');
      if (observed == expected.padLeft(2, '0')) {
        final digits = observed.split('').join(' ');
        return ValidationItem(
          label: 'Runway', expected: 'bana $digits', observed: 'bana ${entry.key}',
          status: ValidationStatus.warning,
        );
      }
      return ValidationItem(
        label: 'Runway', expected: expected, observed: observed,
        status: ValidationStatus.incorrect,
      );
    }

    return ValidationItem(
      label: 'Runway', expected: expected, observed: null,
      status: ValidationStatus.missing,
    );
  }

  ValidationItem _checkQnh(String expected, String normalized) {
    final match = RegExp(r'\bqnh\s*([0-9]{4})\b').firstMatch(normalized);
    if (match == null) {
      return ValidationItem(
        label: 'QNH',
        expected: expected,
        observed: null,
        status: ValidationStatus.missing,
      );
    }
    final observed = match.group(1)!;
    return ValidationItem(
      label: 'QNH',
      expected: expected,
      observed: observed,
      status: observed == expected
          ? ValidationStatus.correct
          : ValidationStatus.incorrect,
    );
  }

  ValidationItem _checkSquawk(String expected, String normalized) {
    final observed = _extractSquawk(normalized);
    if (observed == null) {
      return ValidationItem(
        label: 'Squawk',
        expected: expected,
        observed: null,
        status: ValidationStatus.missing,
      );
    }
    return ValidationItem(
      label: 'Squawk',
      expected: expected,
      observed: observed,
      status: observed == expected
          ? ValidationStatus.correct
          : ValidationStatus.incorrect,
    );
  }

  ValidationItem _checkFrequency(String expected, String normalized) {
    final observed = _extractFrequency(normalized);
    if (observed == null) {
      return ValidationItem(
        label: 'Frequency',
        expected: expected,
        observed: null,
        status: ValidationStatus.missing,
      );
    }

    return ValidationItem(
      label: 'Frequency',
      expected: expected,
      observed: observed,
      status: observed == expected
          ? ValidationStatus.correct
          : ValidationStatus.incorrect,
    );
  }

  List<ValidationItem> _unexpectedRunway(String normalized) {
    final match = RegExp(r'\b(?:runway|rwy|bana)\s*([0-3]?\d)\b')
        .firstMatch(normalized);
    if (match == null) return const [];
    return [
      ValidationItem(
        label: 'Runway',
        expected: 'inte angivet av ATC',
        observed: match.group(1)!.padLeft(2, '0'),
        status: ValidationStatus.unexpected,
      ),
    ];
  }

  List<ValidationItem> _unexpectedQnh(String normalized) {
    final match = RegExp(r'\bqnh\s*([0-9]{4})\b').firstMatch(normalized);
    if (match == null) return const [];
    return [
      ValidationItem(
        label: 'QNH',
        expected: 'inte angivet av ATC',
        observed: match.group(1)!,
        status: ValidationStatus.unexpected,
      ),
    ];
  }

  List<ValidationItem> _unexpectedSquawk(String normalized) {
    final observed = _extractSquawk(normalized);
    if (observed == null) return const [];
    return [
      ValidationItem(
        label: 'Squawk',
        expected: 'inte angivet av ATC',
        observed: observed,
        status: ValidationStatus.unexpected,
      ),
    ];
  }

  List<ValidationItem> _unexpectedFrequency(String normalized) {
    final observed = _extractFrequency(normalized);
    if (observed == null) return const [];
    return [
      ValidationItem(
        label: 'Frequency',
        expected: 'inte angivet av ATC',
        observed: observed,
        status: ValidationStatus.unexpected,
      ),
    ];
  }

  String? _extractSquawk(String normalized) {
    // Preferred parsing: explicit squawk/transponder keyword.
    final explicit = RegExp(r'\b(?:squawk|transponder)\s*([0-7]{4})\b')
        .firstMatch(normalized);
    if (explicit != null) return explicit.group(1)!;

    // Text-entry drills should distinguish a misspelled label from a missing
    // code. If a four-digit octal code is present, treat it as a recognisable
    // squawk value unless the same digits are explicitly part of QNH.
    // This also mirrors spoken readbacks where the code can be read back
    // without repeating the word "squawk".
    final qnhValues = RegExp(r'\bqnh\s*([0-9]{4})\b')
        .allMatches(normalized)
        .map((m) => m.group(1)!)
        .toSet();
    final candidates = RegExp(r'\b([0-7]{4})\b')
        .allMatches(normalized)
        .map((m) => m.group(1)!)
        .where((value) => !qnhValues.contains(value))
        .toList();

    return candidates.isEmpty ? null : candidates.last;
  }

  String? _extractFrequency(String normalized) {
    // Decimal comma is normalised to decimal point before this stage.
    // Two decimals are retained as a genuine entered value and padded to
    // three decimals for comparison: 124.72 -> 124.720.
    final match = RegExp(r'\b(1[1-3][0-9])\s*\.\s*([0-9]{2,3})\b')
        .firstMatch(normalized);
    if (match == null) return null;

    final decimals = match.group(2)!;
    final normalizedDecimals = decimals.length == 2 ? '${decimals}0' : decimals;
    return '${match.group(1)}.$normalizedDecimals';
  }

  String _normalize(String value) {
    var result = value.toLowerCase();

    // Swedish users naturally type decimal comma. Preserve its numerical
    // meaning before ordinary commas are treated as punctuation.
    result = result.replaceAllMapped(
      RegExp(r'(\d),(\d)'),
      (match) => '${match.group(1)}.${match.group(2)}',
    );

    return result
        .replaceAll(',', ' ')
        .replaceAll(RegExp(r'[^a-z0-9åäö.\- ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
