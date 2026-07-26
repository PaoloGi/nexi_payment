import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The response of an HTTP call made by the plugin, reduced to what the NPG
/// orders API needs.
class NpgHttpResponse {
  /// HTTP status code of the response.
  final int statusCode;

  /// Decoded response body.
  final String body;

  /// Creates a response with the given [statusCode] and [body].
  const NpgHttpResponse(this.statusCode, this.body);
}

/// Signature of the GET used to call the NPG orders API.
///
/// The plugin uses [npgDefaultHttpGet] unless you pass your own to
/// [NexiNpgPayment], which lets you route the call through your HTTP stack
/// (a proxy, certificate pinning, logging) or stub it in tests.
typedef NpgHttpGet = Future<NpgHttpResponse> Function(
  Uri url,
  Map<String, String> headers,
);

/// How long the plugin waits for the orders API before giving up and keeping
/// the original "outcome unknown" result.
const Duration npgHttpTimeout = Duration(seconds: 15);

/// Default [NpgHttpGet]: a plain `dart:io` GET, so the package stays
/// dependency-free.
///
/// Exported so you can wrap it — for instance to log the call — instead of
/// reimplementing it:
///
/// ```dart
/// NexiNpgPayment(
///   hostname: hostname,
///   apiKey: apiKey,
///   httpGet: (url, headers) async {
///     final response = await npgDefaultHttpGet(url, headers);
///     debugPrint('NPG order lookup: ${response.statusCode}');
///     return response;
///   },
/// );
/// ```
Future<NpgHttpResponse> npgDefaultHttpGet(
  Uri url,
  Map<String, String> headers,
) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    return await _get(client, url, headers).timeout(
      npgHttpTimeout,
      onTimeout: () {
        // Drop the socket instead of leaving the request in flight: the
        // caller has already given up on it.
        client.close(force: true);
        throw TimeoutException('NPG orders API did not answer', npgHttpTimeout);
      },
    );
  } finally {
    client.close(force: true);
  }
}

Future<NpgHttpResponse> _get(
  HttpClient client,
  Uri url,
  Map<String, String> headers,
) async {
  final request = await client.getUrl(url);
  headers.forEach(request.headers.set);
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  return NpgHttpResponse(response.statusCode, body);
}
