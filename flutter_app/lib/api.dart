import 'dart:convert';

import 'package:http/http.dart' as http;

class Api {
  final String base = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  String? token;
  Future<dynamic> call(String path, {Map<String, dynamic>? data}) async {
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final uri = Uri.parse('$base$path');
    final response = data == null
        ? await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 20))
        : await http
              .post(uri, headers: headers, body: jsonEncode(data))
              .timeout(const Duration(seconds: 20));
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'].toString());
    }
    if (path.endsWith('.csv')) return response.body;
    return jsonDecode(response.body);
  }
}
