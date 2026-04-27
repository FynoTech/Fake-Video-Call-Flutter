import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:get/get.dart';

class ChatbotService {
  ChatbotService({required this.apiKey});

  final String apiKey;
  static const String _endpointHost = 'api.openai.com';
  static const String _endpointPath = '/v1/responses';
  static const String _model = 'gpt-4.1';

  Future<String> getReply({
    required String userMessage,
    required String personaName,
    required List<Map<String, String>> history,
  }) async {
    if (apiKey.trim().isEmpty) return _serviceUnavailableReply('missing_key');

    final userOnlyHistory = history
        .where((m) => m['role'] == 'user')
        .map((m) => m['text'] ?? '')
        .where((t) => t.trim().isNotEmpty)
        .join('\nUser: ');

    final prompt = StringBuffer()
      ..writeln(
        'You are $personaName. Talk in this person tone and style. Keep answers short 4 to 5 words.',
      )
      ..writeln('User: ${userOnlyHistory.trim()}')
      ..writeln('User: ${userMessage.trim()}');

    final payload = <String, dynamic>{
      'model': _model,
      'input': prompt.toString(),
    };

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 60)
      ..idleTimeout = const Duration(seconds: 60);

    try {
      for (var attempt = 1; attempt <= 3; attempt++) {
        final req = await client.postUrl(
          Uri.https(_endpointHost, _endpointPath),
        );
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
        req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        req.add(utf8.encode(jsonEncode(payload)));

        final resp = await req.close();
        final body = await utf8.decoder.bind(resp).join();

        if (resp.statusCode == 429 && attempt < 3) {
          await Future<void>.delayed(Duration(seconds: attempt));
          continue;
        }
        if (resp.statusCode >= 400) {
          debugPrint(
            'ChatbotService error status=${resp.statusCode} body=$body',
          );
          return _serviceUnavailableReply('http_${resp.statusCode}');
        }

        final decoded = jsonDecode(body);
        final out = _extractText(decoded);
        if (out != null && out.trim().isNotEmpty) return out.trim();
        return _serviceUnavailableReply('empty_output');
      }
      return _serviceUnavailableReply('retry_exhausted');
    } catch (e) {
      debugPrint('ChatbotService exception: $e');
      return _serviceUnavailableReply('exception');
    } finally {
      client.close(force: true);
    }
  }

  String? _extractText(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) return null;
    final output = decoded['output'];
    if (output is! List || output.isEmpty) return null;
    final first = output.first;
    if (first is! Map<String, dynamic>) return null;
    final content = first['content'];
    if (content is! List || content.isEmpty) return null;
    final contentFirst = content.first;
    if (contentFirst is! Map<String, dynamic>) return null;
    final text = contentFirst['text'];
    return text is String ? text : null;
  }

  String _serviceUnavailableReply(String reason) {
    final lang = (Get.locale?.languageCode ?? 'en').toLowerCase();
    if (reason.contains('429')) {
      if (lang == 'hi') {
        return 'AI फिलहाल उपलब्ध नहीं है। कृपया थोड़ी देर बाद दोबारा कोशिश करें।';
      }
      return 'AI is temporarily unavailable. Please try again shortly.';
    }
    if (lang == 'hi') {
      return 'AI जवाब अभी उपलब्ध नहीं है। कृपया बाद में फिर कोशिश करें।';
    }
    return 'AI reply unavailable right now. Please try again later.';
  }
}
