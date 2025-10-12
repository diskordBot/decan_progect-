// lib/utils/server_utils.dart
import 'package:http/http.dart' as http;

Future<bool> pingServer(String baseUrl) async {
  try {
    final r = await http
        .get(Uri.parse('$baseUrl/api/health'))
        .timeout(const Duration(seconds: 5));
    return r.statusCode == 200;
  } catch (_) {
    return false;
  }
}
