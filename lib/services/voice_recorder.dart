import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

class RecordedTransmission {
  const RecordedTransmission({
    required this.wavBytes,
    required this.duration,
  });

  final Uint8List wavBytes;
  final Duration duration;
}

class VoiceRecorder {
  VoiceRecorder({this.sampleRate = 16000});

  final int sampleRate;
  final AudioRecorder _recorder = AudioRecorder();
  final BytesBuilder _pcm = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _subscription;
  DateTime? _startedAt;

  bool get isRecording => _startedAt != null;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    if (isRecording) return;
    if (!await _recorder.hasPermission()) {
      throw StateError('Mikrofonbehörighet saknas.');
    }

    _pcm.clear();
    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        echoCancel: false,
        noiseSuppress: false,
        autoGain: false,
      ),
    );
    _startedAt = DateTime.now();
    _subscription = stream.listen(_pcm.add);
  }

  Future<RecordedTransmission?> stop() async {
    final started = _startedAt;
    if (started == null) return null;

    await _recorder.stop();
    await _subscription?.cancel();
    _subscription = null;
    _startedAt = null;

    final pcm = _pcm.takeBytes();
    if (pcm.isEmpty) return null;

    return RecordedTransmission(
      wavBytes: _pcm16ToWav(pcm, sampleRate: sampleRate, channels: 1),
      duration: DateTime.now().difference(started),
    );
  }

  Future<void> cancel() async {
    if (isRecording) await _recorder.cancel();
    await _subscription?.cancel();
    _subscription = null;
    _startedAt = null;
    _pcm.clear();
  }

  void dispose() {
    _subscription?.cancel();
    _recorder.dispose();
  }

  Uint8List _pcm16ToWav(
    Uint8List pcm, {
    required int sampleRate,
    required int channels,
  }) {
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataLength = pcm.length;
    final out = Uint8List(44 + dataLength);
    final data = ByteData.sublistView(out);

    void ascii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        out[offset + i] = value.codeUnitAt(i);
      }
    }

    ascii(0, 'RIFF');
    data.setUint32(4, 36 + dataLength, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, channels, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, byteRate, Endian.little);
    data.setUint16(32, blockAlign, Endian.little);
    data.setUint16(34, bitsPerSample, Endian.little);
    ascii(36, 'data');
    data.setUint32(40, dataLength, Endian.little);
    out.setRange(44, out.length, pcm);
    return out;
  }
}
