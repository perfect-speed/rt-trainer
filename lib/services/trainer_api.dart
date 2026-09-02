import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class TrainerApi {
  TrainerApi({this.baseUrl = const String.fromEnvironment('RT_API_URL')});

  final String baseUrl;

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  Future<String> transcribe({
    required Uint8List wavBytes,
    required String scenarioContext,
  }) async {
    if (!isConfigured) {
      throw StateError('RT_API_URL är inte konfigurerad.');
    }

    final uri = Uri.parse('$baseUrl/api/transcribe');
    final request = http.MultipartRequest('POST', uri)
      ..fields['context'] = scenarioContext
      ..files.add(http.MultipartFile.fromBytes(
        'audio',
        wavBytes,
        filename: 'transmission.wav',
      ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw StateError('Transkribering misslyckades (${response.statusCode}).');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = (data['text'] as String?)?.trim();
    if (text == null || text.isEmpty) {
      throw StateError('Ingen taltranskribering returnerades.');
    }
    return text;
  }

  Future<Uint8List> synthesizeSpeech({
    required String text,
    String? spokenText,
    String engine = 'realtime',
  }) async {
    if (!isConfigured) {
      throw StateError('RT_API_URL är inte konfigurerad.');
    }
    final uri = Uri.parse('$baseUrl/api/speech');
    final payload = jsonEncode({'text': text, 'spokenText': spokenText, 'engine': engine});
    Object? lastError;

    // A Render deployment/cold start can briefly make the endpoint unreachable.
    // Retry transient transport errors and gateway/service errors once before
    // surfacing a user-visible audio error. This does not retry validation errors.
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final response = await http.post(
          uri,
          headers: {'content-type': 'application/json'},
          body: payload,
        );
        if (response.statusCode == 200) {
          if (response.bodyBytes.isEmpty) {
            throw StateError('Ingen ljuddata returnerades.');
          }
          return response.bodyBytes;
        }
        lastError = StateError('Taluppläsning misslyckades (${response.statusCode}).');
        final transient = response.statusCode == 502 ||
            response.statusCode == 503 ||
            response.statusCode == 504;
        if (!transient || attempt == 2) throw lastError;
      } catch (error) {
        lastError = error;
        if (attempt == 2) rethrow;
      }
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
    throw StateError('Taluppläsning misslyckades: $lastError');
  }

  Future<String?> enrichDebrief({
    required String transmission,
    required Map<String, dynamic> validatedFacts,
  }) async {
    if (!isConfigured) return null;
    final uri = Uri.parse('$baseUrl/api/debrief');
    final response = await http.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'transmission': transmission,
        'validatedFacts': validatedFacts,
      }),
    );
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['debrief'] as String?;
  }
}
