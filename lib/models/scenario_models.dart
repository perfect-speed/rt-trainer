class ExpectedReadback {
  const ExpectedReadback({
    required this.callsign,
    this.runway,
    this.qnh,
    this.squawk,
    this.frequency,
    this.allowAbbreviatedCallsign = false,
  });

  final String callsign;
  final String? runway;
  final String? qnh;
  final String? squawk;
  final String? frequency;
  final bool allowAbbreviatedCallsign;
}

class TrainingStep {
  const TrainingStep({
    required this.id,
    required this.title,
    required this.instruction,
    required this.atcTransmission,
    required this.expected,
    this.frequency = '124.500',
    this.coachNote,
  });

  final String id;
  final String title;
  final String instruction;
  final String atcTransmission;
  final ExpectedReadback expected;
  final String frequency;
  final String? coachNote;
}

class ValidationItem {
  const ValidationItem({
    required this.label,
    required this.expected,
    required this.observed,
    required this.status,
  });

  final String label;
  final String expected;
  final String? observed;
  final ValidationStatus status;
}

enum ValidationStatus { correct, warning, missing, incorrect, unexpected }

class ValidationResult {
  const ValidationResult({
    required this.items,
    required this.feedback,
    required this.atcResponse,
    required this.isComplete,
  });

  final List<ValidationItem> items;
  final String feedback;
  final String atcResponse;
  final bool isComplete;
}

class RadioEvent {
  const RadioEvent({
    required this.time,
    required this.speaker,
    required this.text,
    this.isError = false,
    this.isPrompt = false,
  });

  final DateTime time;
  final String speaker;
  final String text;
  final bool isError;
  final bool isPrompt;
}
