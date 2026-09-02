import 'package:flutter_test/flutter_test.dart';
import 'package:rt_trainer/models/scenario_models.dart';
import 'package:rt_trainer/services/readback_validator.dart';

void main() {
  final validator = ReadbackValidator();
  const expected = ExpectedReadback(
    callsign: 'SE-KQX',
    runway: '01',
    qnh: '1016',
    squawk: '4255',
  );

  test('accepts a correct complete readback', () {
    final result = validator.validate(
      transmission: 'runway 01, QNH 1016, squawk 4255, SE-KQX',
      expected: expected,
    );
    expect(result.isComplete, isTrue);
  });

  test('rejects wrong runway even when QNH contains 01', () {
    final result = validator.validate(
      transmission: 'runway 11, QNH 1016, squawk 4255, SE-KQX',
      expected: expected,
    );
    expect(result.isComplete, isFalse);
    final runway = result.items.firstWhere((item) => item.label == 'Runway');
    expect(runway.status, ValidationStatus.incorrect);
    expect(runway.observed, '11');
  });

  test('does not infer runway 01 from QNH 1016', () {
    final result = validator.validate(
      transmission: 'QNH 1016, squawk 4255, SE-KQX',
      expected: expected,
    );
    final runway = result.items.firstWhere((item) => item.label == 'Runway');
    expect(runway.status, ValidationStatus.missing);
  });

  test('detects wrong QNH as incorrect', () {
    final result = validator.validate(
      transmission: 'runway 01, QNH 1015, squawk 4255, SE-KQX',
      expected: expected,
    );
    final qnh = result.items.firstWhere((item) => item.label == 'QNH');
    expect(qnh.status, ValidationStatus.incorrect);
    expect(qnh.observed, '1015');
  });

  test('detects wrong squawk as incorrect', () {
    final result = validator.validate(
      transmission: 'runway 01, QNH 1016, squawk 4256, SE-KQX',
      expected: expected,
    );
    final squawk = result.items.firstWhere((item) => item.label == 'Squawk');
    expect(squawk.status, ValidationStatus.incorrect);
    expect(squawk.observed, '4256');
  });

  test('flags callsign when it is present but not at the end', () {
    final result = validator.validate(
      transmission: 'SE-KQX, runway 01, QNH 1016, squawk 4255',
      expected: expected,
    );
    final callsign = result.items.firstWhere((item) => item.label == 'Callsign');
    expect(result.isComplete, isFalse);
    expect(callsign.status, ValidationStatus.incorrect);
  });

  test('recognises 124.75 as an incorrect frequency, not missing', () {
    const frequencyExpected = ExpectedReadback(
      callsign: 'SE-KQX',
      frequency: '124.725',
    );
    final result = validator.validate(
      transmission: '124.75 for Sweden Control, SE-KQX',
      expected: frequencyExpected,
    );
    final frequency = result.items.firstWhere((item) => item.label == 'Frequency');
    expect(result.isComplete, isFalse);
    expect(frequency.status, ValidationStatus.incorrect);
    expect(frequency.observed, '124.750');
  });

  test('recognises decimal comma and reports wrong frequency as incorrect', () {
    const frequencyExpected = ExpectedReadback(
      callsign: 'SE-KQX',
      frequency: '124.725',
    );
    final result = validator.validate(
      transmission: '124,72 for SWEDEN, SE-KQX',
      expected: frequencyExpected,
    );
    final frequency = result.items.firstWhere((item) => item.label == 'Frequency');
    expect(frequency.status, ValidationStatus.incorrect);
    expect(frequency.observed, '124.720');
  });

  test('recognises decimal comma for a correct frequency', () {
    const frequencyExpected = ExpectedReadback(
      callsign: 'SE-KQX',
      frequency: '124.725',
    );
    final result = validator.validate(
      transmission: '124,725 for SWEDEN, SE-KQX',
      expected: frequencyExpected,
    );
    final frequency = result.items.firstWhere((item) => item.label == 'Frequency');
    expect(frequency.status, ValidationStatus.correct);
  });

  test('reports a wrong but recognisable callsign as incorrect, not missing', () {
    const frequencyExpected = ExpectedReadback(
      callsign: 'SE-KQX',
      frequency: '124.725',
    );
    final result = validator.validate(
      transmission: '124,72 for SWEDEN, SE-KQZ',
      expected: frequencyExpected,
    );
    final callsign = result.items.firstWhere((item) => item.label == 'Callsign');
    expect(callsign.status, ValidationStatus.incorrect);
    expect(callsign.observed, 'SE-KQZ');
  });

  test('flags an unassigned squawk as unexpected extra information', () {
    const runwayQnhOnly = ExpectedReadback(
      callsign: 'SE-KQX',
      runway: '19',
      qnh: '1009',
    );
    final result = validator.validate(
      transmission: 'RWY 19, QNH 1009, squawk 4261, SE-KQX',
      expected: runwayQnhOnly,
    );
    final squawk = result.items.firstWhere((item) => item.label == 'Squawk');
    expect(result.isComplete, isFalse);
    expect(squawk.status, ValidationStatus.unexpected);
    expect(squawk.observed, '4261');
  });

  test('recognises shortened callsign as incorrect rather than missing when not authorised', () {
    const runwayQnhOnly = ExpectedReadback(
      callsign: 'SE-KQX',
      runway: '19',
      qnh: '1009',
    );
    final result = validator.validate(
      transmission: 'RWY 19, QNH 1009, SQX',
      expected: runwayQnhOnly,
    );
    final callsign = result.items.firstWhere((item) => item.label == 'Callsign');
    expect(callsign.status, ValidationStatus.incorrect);
    expect(callsign.observed, contains('S-QX'));
  });

  test('accepts shortened callsign when scenario context authorises it', () {
    const authorised = ExpectedReadback(
      callsign: 'SE-KQX',
      squawk: '4261',
      allowAbbreviatedCallsign: true,
    );
    final result = validator.validate(
      transmission: 'squawk 4261, S-QX',
      expected: authorised,
    );
    expect(result.isComplete, isTrue);
  });

  test('recognises SEQX as an attempted non-standard abbreviation, not missing', () {
    final result = validator.validate(
      transmission: 'RWY 01, QNH 1016, squawk 4255, SEQX',
      expected: expected,
    );
    final callsign = result.items.firstWhere((item) => item.label == 'Callsign');
    expect(callsign.status, ValidationStatus.incorrect);
    expect(callsign.observed, contains('avvikande förkortning'));
  });

  test('recognises squawk value even when the word squawk is misspelled', () {
    const second = ExpectedReadback(
      callsign: 'SE-KQX',
      runway: '01',
      qnh: '1013',
      squawk: '4272',
    );
    final result = validator.validate(
      transmission: 'RWY 01, QNH 1013, SOUWAK 4272, SE-KQX',
      expected: second,
    );
    final squawk = result.items.firstWhere((item) => item.label == 'Squawk');
    expect(squawk.status, ValidationStatus.correct);
    expect(squawk.observed, '4272');
  });

  test('does not confuse QNH with a missing squawk', () {
    const second = ExpectedReadback(
      callsign: 'SE-KQX',
      runway: '01',
      qnh: '1013',
      squawk: '4272',
    );
    final result = validator.validate(
      transmission: 'RWY 01, QNH 1013, SE-KQX',
      expected: second,
    );
    final squawk = result.items.firstWhere((item) => item.label == 'Squawk');
    expect(squawk.status, ValidationStatus.missing);
  });


  test('accepts full callsign last when ASR adds terminal punctuation', () {
    final result = validator.validate(
      transmission: 'runway 01, qnh 1016, squawk 4255, SE-KQX.',
      expected: expected,
    );
    final callsign = result.items.firstWhere((item) => item.label == 'Callsign');
    expect(callsign.status, ValidationStatus.correct);
    expect(result.isComplete, isTrue);
  });

  test('accepts authorised abbreviated callsign last with terminal punctuation', () {
    const authorised = ExpectedReadback(
      callsign: 'SE-KQX',
      squawk: '4261',
      allowAbbreviatedCallsign: true,
    );
    final result = validator.validate(
      transmission: 'squawk 4261, S-QX.',
      expected: authorised,
    );
    final callsign = result.items.firstWhere((item) => item.label == 'Callsign');
    expect(callsign.status, ValidationStatus.correct);
    expect(result.isComplete, isTrue);
  });


  test('bana nitton is semantically correct but gives phraseology warning', () {
    const expected19 = ExpectedReadback(callsign: 'SE-KQX', runway: '19');
    final result = validator.validate(
      transmission: 'bana nitton, SE-KQX', expected: expected19,
    );
    final runway = result.items.firstWhere((item) => item.label == 'Runway');
    expect(runway.status, ValidationStatus.warning);
    expect(runway.observed, 'bana nitton');
    expect(runway.expected, 'bana 1 9');
    expect(result.isComplete, isTrue);
  });

  test('bana arton remains a factual error when runway 19 is expected', () {
    const expected19 = ExpectedReadback(callsign: 'SE-KQX', runway: '19');
    final result = validator.validate(
      transmission: 'bana arton, SE-KQX', expected: expected19,
    );
    final runway = result.items.firstWhere((item) => item.label == 'Runway');
    expect(runway.status, ValidationStatus.incorrect);
    expect(runway.observed, '18');
    expect(result.isComplete, isFalse);
  });

}
