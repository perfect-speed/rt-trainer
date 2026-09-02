import 'package:flutter_test/flutter_test.dart';
import 'package:rt_trainer/models/scenario_models.dart';
import 'package:rt_trainer/services/readback_validator.dart';
import 'package:rt_trainer/services/spoken_rt_normalizer.dart';

void main() {
  const expected = ExpectedReadback(
    callsign: 'SE-MBN',
    frequency: '124.725',
  );
  final normalizer = SpokenRtNormalizer();
  final validator = ReadbackValidator();

  void expectCorrect(String transmission) {
    final normalized = normalizer.normalize(transmission, expected);
    final result = validator.validate(
      transmission: normalized,
      expected: expected,
    );
    final frequency = result.items.firstWhere((item) => item.label == 'Frequency');
    expect(frequency.status, ValidationStatus.correct,
        reason: 'Normalized transmission: $normalized');
  }

  test('frequency is correct when comma is spoken', () {
    expectCorrect(
      'Ett två fyra komma sju två fem Sigurd Erik Martin Bertil Niklas.',
    );
  });

  test('frequency is correct when comma is omitted', () {
    expectCorrect(
      'Ett två fyra sju två fem Sigurd Erik Martin Bertil Niklas.',
    );
  });

  test('frequency is correct with clarified Swedish digit forms', () {
    expectCorrect(
      'Ett tvåa fyra komma sju tvåa femma Sigurd Erik Martin Bertil Niklas.',
    );
  });
}
