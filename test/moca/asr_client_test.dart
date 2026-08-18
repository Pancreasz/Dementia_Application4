import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moca_main/moca/asr_client.dart';

void main() {
  test('posts the audio and parses text and segments', () async {
    late http.BaseRequest captured;

    final mock = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'text': 'สองสี่เจ็ด',
          'segments': [
            {'start': 0.0, 'end': 0.5, 'text': 'สอง'},
            {'start': 0.6, 'end': 1.0, 'text': 'สี่เจ็ด'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final client = HttpAsrClient(
      endpoint: Uri.parse('https://example.test/transcribe'),
      client: mock,
    );

    final result = await client.transcribe([1, 2, 3]);

    expect(result.text, 'สองสี่เจ็ด');
    expect(result.segments.length, 2);
    expect(result.segments.first.text, 'สอง');
    expect(captured.method, 'POST');
    expect(captured.url.toString(), 'https://example.test/transcribe');
  });

  test('tolerates a response with no segments field', () async {
    final mock = MockClient((request) async => http.Response(
          jsonEncode({'text': 'ยานพาหนะ'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));

    final client = HttpAsrClient(
      endpoint: Uri.parse('https://example.test/transcribe'),
      client: mock,
    );

    final result = await client.transcribe([1]);
    expect(result.text, 'ยานพาหนะ');
    expect(result.segments, isEmpty);
  });

  // 503 is what the endpoint returns while the model is still loading. It has
  // to surface as a retryable error, not as an empty transcript that would be
  // scored as the patient saying nothing.
  test('throws on 503 rather than returning an empty transcript', () async {
    final mock = MockClient((request) async => http.Response(
          jsonEncode({'detail': 'model not loaded'}),
          503,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));

    final client = HttpAsrClient(
      endpoint: Uri.parse('https://example.test/transcribe'),
      client: mock,
    );

    expect(() => client.transcribe([1]), throwsA(isA<AsrException>()));
  });

  // A cold-starting backend must not hang the app forever behind the
  // scoring screen's PopScope(canPop: false). An injected short timeout
  // stands in for the real 45s default so the test itself stays fast.
  test('throws an AsrException when the request exceeds the timeout',
      () async {
    final mock = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return http.Response(
        jsonEncode({'text': 'too late'}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final client = HttpAsrClient(
      endpoint: Uri.parse('https://example.test/transcribe'),
      client: mock,
      timeout: const Duration(milliseconds: 50),
    );

    expect(() => client.transcribe([1]), throwsA(isA<AsrException>()));
  });

  test('throws when the network fails', () async {
    final mock = MockClient((request) async => throw const SocketishError());

    final client = HttpAsrClient(
      endpoint: Uri.parse('https://example.test/transcribe'),
      client: mock,
    );

    expect(() => client.transcribe([1]), throwsA(isA<AsrException>()));
  });

  // A 200 response missing "text" is indistinguishable from a legitimately
  // empty transcript unless it throws — same reasoning as the 503 case above.
  test('throws on a 200 response with no text field', () async {
    final mock = MockClient((request) async => http.Response(
          jsonEncode({'segments': []}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));

    final client = HttpAsrClient(
      endpoint: Uri.parse('https://example.test/transcribe'),
      client: mock,
    );

    expect(() => client.transcribe([1]), throwsA(isA<AsrException>()));
  });

  test('the fake returns what it was given', () async {
    final fake = FakeAsrClient(text: 'ยานพาหนะ');
    expect((await fake.transcribe([])).text, 'ยานพาหนะ');
  });

  test('the fake can be told to fail', () async {
    final fake = FakeAsrClient(throws: const AsrException('offline'));
    expect(() => fake.transcribe([]), throwsA(isA<AsrException>()));
  });
}

class SocketishError implements Exception {
  const SocketishError();
}
