import '../models/scenario_models.dart';

/// Bedömer när taligenkänningen sannolikt är osäker på en bokstaverad
/// anropssignal. Detta är medvetet separerat från den deterministiska
/// radiovalideringen: ett möjligt ASR-fel ska inte registreras som elevfel.
class AsrAssessment {
  const AsrAssessment({
    required this.callsignUncertain,
    this.message,
  });

  final bool callsignUncertain;
  final String? message;
}

class AsrQualityAssessor {
  static const _swedishCodeWords = <String>{
    'adam', 'bertil', 'cesar', 'caesar', 'david', 'erik', 'eric', 'filip',
    'philip', 'gustav', 'helge', 'ivar', 'johan', 'kalle', 'ludvig',
    'martin', 'niklas', 'niclas', 'olof', 'petter', 'qvintus', 'kvintus',
    'quintus', 'rudolf', 'sigurd', 'tore', 'urban', 'viktor', 'victor',
    'wilhelm', 'xerxes', 'yngve', 'zäta', 'zeta', 'åke', 'ake', 'ärlig',
    'arlig', 'östen', 'osten',
  };

  // NATO-ord tas bara med för att upptäcka att ASR kan ha ersatt svenska
  // kodord. De normaliseras aldrig automatiskt till den förväntade
  // registreringen.
  static const _natoCodeWords = <String>{
    'alpha', 'bravo', 'charlie', 'delta', 'echo', 'foxtrot', 'golf', 'hotel',
    'india', 'juliett', 'juliet', 'kilo', 'lima', 'mike', 'november', 'oscar',
    'papa', 'quebec', 'romeo', 'sierra', 'tango', 'uniform', 'victor',
    'whiskey', 'x-ray', 'xray', 'yankee', 'zulu',
  };

  AsrAssessment assess({
    required String rawTranscript,
    required String normalizedTranscript,
    required ExpectedReadback expected,
  }) {
    if (_containsRecognisedCallsign(normalizedTranscript, expected)) {
      return const AsrAssessment(callsignUncertain: false);
    }

    // Om ASR redan gav en kompakt svensk registrering (även fel sådan) får
    // validatorn bedöma den som elevsvar. Då har vi ett tydligt observerat
    // värde och ska inte gömma det bakom "ASR osäker".
    if (RegExp(r'\bse\s*[- ]?\s*[a-z]{3}\b', caseSensitive: false)
        .hasMatch(normalizedTranscript)) {
      return const AsrAssessment(callsignUncertain: false);
    }

    final words = rawTranscript
        .toLowerCase()
        .replaceAll('x ray', 'x-ray')
        .split(RegExp(r'[^a-zåäö-]+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final phoneticCount = words
        .where((w) => _swedishCodeWords.contains(w) || _natoCodeWords.contains(w))
        .length;
    final natoCount = words.where(_natoCodeWords.contains).length;

    // Tre eller fler kodord är stark signal om att piloten försökte
    // bokstavera en registrering, men ASR/normalisering kunde inte säkert
    // rekonstruera den. Särskilt NATO-ord i svensk RT är en varningssignal.
    if (phoneticCount >= 3 || natoCount >= 2) {
      return const AsrAssessment(
        callsignUncertain: true,
        message:
            'Taligenkänningen är osäker på anropssignalen. Repetera anropssignalen med svensk bokstavering.',
      );
    }

    return const AsrAssessment(callsignUncertain: false);
  }

  bool _containsRecognisedCallsign(
      String normalized, ExpectedReadback expected) {
    final compact = expected.callsign.toUpperCase().replaceAll('-', '');
    if (compact.length != 5) return false;

    final full = RegExp(
      r'\b' + RegExp.escape(expected.callsign.toLowerCase()) + r'\b',
      caseSensitive: false,
    );
    if (full.hasMatch(normalized)) return true;

    if (!expected.allowAbbreviatedCallsign) return false;
    final short = '${compact[0]}-${compact.substring(compact.length - 2)}';
    return RegExp(
      r'\b' + RegExp.escape(short.toLowerCase()) + r'\b',
      caseSensitive: false,
    ).hasMatch(normalized);
  }
}
