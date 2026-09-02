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
    final response = await http.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'text': text, 'spokenText': spokenText, 'engine': engine}),
    );
    if (response.statusCode != 200) {
      throw StateError('Taluppläsning misslyckades (${response.statusCode}).');
    }
    if (response.bodyBytes.isEmpty) {
      throw StateError('Ingen ljuddata returnerades.');
    }
    return response.bodyBytes;
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
