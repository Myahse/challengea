import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiError implements Exception {
  ApiError(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;

  bool get isNetwork => status == 0;

  @override
  String toString() => message;
}

/// Small JSON client for the Challengea API.
class ApiClient {
  ApiClient(this.baseUrl, {this.token, http.Client? client})
    : _http = client ?? http.Client();

  final String baseUrl;
  String? token;
  final http.Client _http;

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body);
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body);
  Future<dynamic> patch(String path, [Object? body]) =>
      _send('PATCH', path, body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final req = http.Request(method, Uri.parse('$baseUrl/api$path'));
    req.headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);
    http.Response res;
    try {
      res = await http.Response.fromStream(
        await _http.send(req).timeout(const Duration(seconds: 15)),
      );
    } catch (_) {
      throw ApiError(
        0,
        'network',
        'Can’t reach the server. Check your connection.',
      );
    }
    final text = utf8.decode(res.bodyBytes);
    final data = text.isEmpty ? null : jsonDecode(text);
    if (res.statusCode >= 400) {
      if (data is Map) {
        throw ApiError(
          res.statusCode,
          '${data['error']}',
          '${data['message']}',
        );
      }
      throw ApiError(
        res.statusCode,
        res.statusCode == 401 ? 'unauthorized' : 'error',
        res.statusCode == 401
            ? 'Please sign in again'
            : 'Something went wrong ($res.statusCode)',
      );
    }
    return data;
  }
}
