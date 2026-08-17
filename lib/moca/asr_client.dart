import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../scoring/asr_segment.dart';

/// Same host clock.dart already uploads to. Only the path differs.
const String kDefaultAsrEndpoint =
    'https://moca-flask-container.azurewebsites.net/transcribe';

class AsrException implements Exception {
  final String message;
  const AsrException(this.message);
  @override
  String toString() => 'AsrException: $message';
}

class AsrResult {
  final String text;
  final List<AsrSegment> segments;
  const AsrResult({required this.text, this.segments = const []});
}

abstract class AsrClient {
  Future<AsrResult> transcribe(List<int> audioBytes, {String language});
}

class HttpAsrClient implements AsrClient {
  final Uri endpoint;
  final http.Client _client;

  HttpAsrClient({required this.endpoint, http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<AsrResult> transcribe(List<int> audioBytes,
      {String language = 'th'}) async {
    final request = http.MultipartRequest('POST', endpoint)
      ..fields['language'] = language
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: 'response.wav',
        contentType: MediaType('audio', 'wav'),
      ));

    http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request));
    } catch (e) {
      // Anything the transport throws becomes one type the caller can catch.
      // The screen turns this into Retry / Skip.
      throw AsrException('transcription request failed: $e');
    }

    if (response.statusCode != 200) {
      // 503 means the model is still loading. Surfacing it as an error rather
      // than an empty transcript matters: an empty transcript would be scored
      // as the patient having said nothing.
      throw AsrException(
          'transcription failed with ${response.statusCode}: ${utf8.decode(response.bodyBytes)}');
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw AsrException('could not parse transcription response: $e');
    }

    final rawSegments = body['segments'];
    final segments = <AsrSegment>[];
    if (rawSegments is List) {
      for (final s in rawSegments) {
        if (s is! Map) continue;
        segments.add(AsrSegment(
          start: (s['start'] as num?)?.toDouble() ?? 0.0,
          end: (s['end'] as num?)?.toDouble() ?? 0.0,
          text: (s['text'] as String?) ?? '',
        ));
      }
    }

    final rawText = body['text'];
    if (rawText is! String) {
      throw AsrException(
          'transcription response had no usable "text" field: ${utf8.decode(response.bodyBytes)}');
    }

    return AsrResult(
      text: rawText,
      segments: segments,
    );
  }
}

/// Used by every test that would otherwise need a network.
class FakeAsrClient implements AsrClient {
  final String text;
  final List<AsrSegment> segments;
  final Object? throws;
  int callCount = 0;

  FakeAsrClient({this.text = '', this.segments = const [], this.throws});

  @override
  Future<AsrResult> transcribe(List<int> audioBytes,
      {String language = 'th'}) async {
    callCount += 1;
    if (throws != null) throw throws!;
    return AsrResult(text: text, segments: segments);
  }
}
