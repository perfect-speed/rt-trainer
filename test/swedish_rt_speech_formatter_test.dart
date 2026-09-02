import 'package:flutter_test/flutter_test.dart';
import 'package:rt_trainer/services/swedish_rt_speech_formatter.dart';

void main() {
  final formatter = SwedishRtSpeechFormatter();

  test('formats full callsign runway QNH and transponder deterministically', () {
    expect(
      formatter.format('SE-KQX, bana 01, QNH 1016, transponder 4255.'),
      'Sigurd Erik Kalle Qvintus Xerxes, bana nolla ett, ku en hå ett nolla ett sexa, transponder fyra tvåa femma femma.',
    );
  });

  test('formats runway 19 and QNH 1009 using clarified Swedish digit words', () {
    expect(
      formatter.format('SE-VPT, bana 19, QNH 1009.'),
      'Sigurd Erik Viktor Petter Tore, bana ett nia, ku en hå ett nolla nolla nia.',
    );
  });

  test('formats frequency digit by digit', () {
    expect(
      formatter.format('SE-MBN, kontakta Sweden Control 124.725.'),
      'Sigurd Erik Martin Bertil Niklas, kontakta Sweden Control ett tvåa fyra komma sju tvåa femma.',
    );
  });

  test('formats standard abbreviated callsign', () {
    expect(
      formatter.format('S-QX, transponder 4261.'),
      'Sigurd Qvintus Xerxes, transponder fyra tvåa sexa ett.',
    );
  });

  test('never leaves literal QNH for generic TTS pronunciation', () {
    expect(formatter.format('QNH'), 'ku en hå');
  });
}
