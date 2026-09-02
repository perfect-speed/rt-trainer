import 'package:flutter_test/flutter_test.dart';
import 'package:rt_trainer/models/scenario_models.dart';
import 'package:rt_trainer/services/asr_quality_assessor.dart';
import 'package:rt_trainer/services/spoken_rt_normalizer.dart';

void main() {
  const expected = ExpectedReadback(
    callsign: 'SE-GLA',
    qnh: '1018',
    squawk: '4261',
  );
  final normalizer = SpokenRtNormalizer();
  final assessor = AsrQualityAssessor();

  test('normalises ASR Tune Helge as QNH label without changing value', () {
    final normalized = normalizer.normalize(
      'Tune Helge 1018, transponder 4261, Sigurd Erik Gustav Ludvig Adam.',
      expected,
    );
    expect(normalized, contains('qnh 1018'));
    expect(normalized, contains('transponder 4261'));
    expect(normalized, contains('SE-GLA'));
  });

  test('does not repair a wrong pressure value when Tune Helge is normalised', () {
    final normalized = normalizer.normalize(
      'Tune Helge 1017, transponder 4261, Sigurd Erik Gustav Ludvig Adam.',
      expected,
    );
    expect(normalized, contains('qnh 1017'));
    expect(normalized, isNot(contains('qnh 1018')));
  });

  test('normalises correct Swedish spelling alphabet for SE-GLA', () {
    final normalized = normalizer.normalize(
      'QNH 1018, transponder 4261, Sigurd Erik Gustav Ludvig Adam.',
      expected,
    );
    expect(normalized, contains('SE-GLA'));
  });

  test('flags NATO-like ASR substitution as uncertain rather than learner error', () {
    const raw = 'QNH 1018, transponder 4261, Sierra Victor Gustav Ludvig Adam.';
    final normalized = normalizer.normalize(raw, expected);
    final result = assessor.assess(
      rawTranscript: raw,
      normalizedTranscript: normalized,
      expected: expected,
    );
    expect(result.callsignUncertain, isTrue);
  });

  test('does not hide explicit wrong compact registration as ASR uncertainty', () {
    const raw = 'QNH 1018, transponder 4261, SE-GLB.';
    final result = assessor.assess(
      rawTranscript: raw,
      normalizedTranscript: raw.toLowerCase(),
      expected: expected,
    );
    expect(result.callsignUncertain, isFalse);
  });

  test('preserves separators and normalises mixed Swedish digit output', () {
    const ryd = ExpectedReadback(
      callsign: 'SE-RYD',
      runway: '01',
      qnh: '1013',
      squawk: '4272',
    );
    final normalized = normalizer.normalize(
      'Bana noll ett QNH 1013, transponder fyra två sju två, Sigurd Erik Rudolf Yngve David.',
      ryd,
    );
    expect(normalized, contains('bana 01 qnh 1013'));
    expect(normalized, contains('transponder 4272'));
    expect(normalized, endsWith('SE-RYD.'));
  });

  test('normalises mixed numeric and word transponder without gluing tokens', () {
    const ryd = ExpectedReadback(
      callsign: 'SE-RYD',
      runway: '01',
      qnh: '1013',
      squawk: '4272',
    );
    final normalized = normalizer.normalize(
      'Bana 01 QNH 1013, transponder 427 två, Sigurd Erik Rudolf Yngve David.',
      ryd,
    );
    expect(normalized, contains('bana 01 qnh 1013'));
    expect(normalized, contains('transponder 4272'));
  });

  test('accepts clarified Swedish radiotelephony digit forms', () {
    const ryd = ExpectedReadback(
      callsign: 'SE-RYD',
      runway: '01',
      qnh: '1013',
      squawk: '4272',
    );
    final normalized = normalizer.normalize(
      'Bana nolla ett QNH ett nolla ett trea, transponder fyra tvåa sju tvåa, Sigurd Erik Rudolf Yngve David.',
      ryd,
    );
    expect(normalized, contains('bana 01 qnh 1013'));
    expect(normalized, contains('transponder 4272'));
    expect(normalized, endsWith('SE-RYD.'));
  });

  test('normalises spoken frequency without decimal separator', () {
    const mbn = ExpectedReadback(
      callsign: 'SE-MBN',
      frequency: '124.725',
    );
    final normalized = normalizer.normalize(
      'Ett två fyra sju två fem Sigurd Erik Martin Bertil Niklas.',
      mbn,
    );
    expect(normalized, contains('124.725'));
    expect(normalized, contains('SE-MBN'));
  });

  test('exact Swedish spelling of expected callsign is not marked ASR uncertain', () {
    const mbn = ExpectedReadback(
      callsign: 'SE-MBN',
      frequency: '124.725',
    );
    const raw = 'Ett två fyra komma sju två fem Sigurd Erik Martin Bertil Niklas.';
    final normalized = normalizer.normalize(raw, mbn);
    final result = assessor.assess(
      rawTranscript: raw,
      normalizedTranscript: normalized,
      expected: mbn,
    );
    expect(result.callsignUncertain, isFalse);
  });

  test('normalises spoken frequency with explicit komma', () {
    const mbn = ExpectedReadback(
      callsign: 'SE-MBN',
      frequency: '124.725',
    );
    final normalized = normalizer.normalize(
      'Ett två fyra komma sju två fem Sigurd Erik Martin Bertil Niklas.',
      mbn,
    );
    expect(normalized, contains('124.725'));
    expect(normalized, contains('SE-MBN'));
  });

  test('normalises clarified digit forms around explicit komma', () {
    const mbn = ExpectedReadback(
      callsign: 'SE-MBN',
      frequency: '124.725',
    );
    final normalized = normalizer.normalize(
      'Ett tvåa fyra komma sju tvåa femma Sigurd Erik Martin Bertil Niklas.',
      mbn,
    );
    expect(normalized, contains('124.725'));
  });

}
