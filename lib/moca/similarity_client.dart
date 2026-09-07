import 'dart:convert';

import 'package:http/http.dart' as http;

import 'backend_config.dart';

/// Talks to POST /similarity, which backs abstraction scoring.
///
/// Shaped like `asr_client.dart` deliberately: same exception-wrapping, same
/// Fake for tests, same "a non-200 is an error, never an empty result" rule. An
/// empty similarity map would be scored as the patient having answered wrongly,
/// which is the same trap an empty transcript is.
class SimilarityException implements Exception {
  final String message;
  const SimilarityException(this.message);
  @override
  String toString() => 'SimilarityException: $message';
}

class SimilarityResult {
  /// Every term's cosine similarity, not just the best one — the scorer stores
  /// the whole map so an unexpected score can be audited later.
  final Map<String, double> similarities;

  /// Which embedding model produced these numbers. Stored with the session:
  /// changing the model changes every similarity, and without this the old
  /// scores are indistinguishable from the new ones on review.
  final String model;

  const SimilarityResult({required this.similarities, this.model = ''});
}

abstract class SimilarityClient {
  Future<SimilarityResult> compare(String answer, List<String> terms);
}

class HttpSimilarityClient implements SimilarityClient {
  final Uri endpoint;
  final http.Client _client;
  final Duration timeout;

  HttpSimilarityClient({
    Uri? endpoint,
    http.Client? client,
    // Far shorter than the ASR client's 180 s. This is one forward pass over a
    // handful of short strings on an already-loaded model — tens of
    // milliseconds warm. The only slow case is a cold backend, and that belongs
    // on the Retry/Skip screen rather than behind a long spinner.
    this.timeout = const Duration(seconds: 30),
  })  : endpoint = endpoint ?? Uri.parse(kSimilarityEndpoint),
        _client = client ?? http.Client();

  @override
  Future<SimilarityResult> compare(String answer, List<String> terms) async {
    http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'answer': answer, 'terms': terms}),
          )
          .timeout(timeout);
    } catch (e) {
      throw SimilarityException('similarity request failed: $e');
    }

    if (response.statusCode != 200) {
      // 503 means the embedding model is still loading. Surfaced as an error so
      // the subtest lands on Retry/Skip — scoring 0 here would assert the
      // patient gave a wrong answer when the backend simply was not up.
      throw SimilarityException(
          'similarity failed with ${response.statusCode}: ${utf8.decode(response.bodyBytes)}');
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw SimilarityException('could not parse similarity response: $e');
    }

    final raw = body['similarities'];
    if (raw is! Map) {
      throw SimilarityException(
          'similarity response had no usable "similarities" field: ${utf8.decode(response.bodyBytes)}');
    }

    final scores = <String, double>{};
    raw.forEach((key, value) {
      // A term whose score is not a number is dropped rather than defaulted to
      // 0.0: a silent 0.0 would look like the patient missing that term.
      if (key is String && value is num) scores[key] = value.toDouble();
    });

    if (scores.isEmpty) {
      throw SimilarityException(
          'similarity response contained no usable scores: ${utf8.decode(response.bodyBytes)}');
    }

    return SimilarityResult(
      similarities: scores,
      model: (body['model'] as String?) ?? '',
    );
  }
}

/// Used by every test that would otherwise need a network or a 470 MB model.
class FakeSimilarityClient implements SimilarityClient {
  /// Returned for any request. Tests that care about a specific term set can
  /// inspect [lastTerms] afterwards.
  final Map<String, double> similarities;
  final Object? throws;
  final String model;

  int callCount = 0;
  String? lastAnswer;
  List<String>? lastTerms;

  FakeSimilarityClient({
    this.similarities = const {},
    this.throws,
    this.model = 'fake',
  });

  @override
  Future<SimilarityResult> compare(String answer, List<String> terms) async {
    callCount += 1;
    lastAnswer = answer;
    lastTerms = terms;
    if (throws != null) throw throws!;
    return SimilarityResult(similarities: similarities, model: model);
  }
}
