// lib/global_variable/token_handles.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_url.dart';

class TokenHandles {
  static String? accessToken;
  static String? refreshToken;

  /// Save tokens after login
  static void setTokens(String access, String refresh) {
    accessToken = access;
    refreshToken = refresh;
  }

  /// Clear tokens (logout)
  static void clearTokens() {
    accessToken = null;
    refreshToken = null;
  }

  /// Decode JWT payload
  static Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      return jsonDecode(payload);
    } catch (_) {
      return null;
    }
  }

  /// Check if access token is expired
  static bool _isAccessTokenExpired() {
    if (accessToken == null) return true;
    final payload = _decodeJwtPayload(accessToken!);
    if (payload == null || !payload.containsKey('exp')) return true;

    final expiry = DateTime.fromMillisecondsSinceEpoch(payload['exp'] * 1000);
    final now = DateTime.now();
    // Add 30s buffer so it refreshes slightly before expiry
    return now.isAfter(expiry.subtract(const Duration(seconds: 30)));
  }

  /// Refresh access token using refresh token
  static Future<bool> refreshAccessToken() async {
    if (refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse("${BaseUrl.value}/user/login/refresh/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"refresh": refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        accessToken = data["access"];
        return true;
      } else {
        clearTokens();
        return false;
      }
    } catch (_) {
      clearTokens();
      return false;
    }
  }

  /// Always returns a valid Authorization header (refreshes if needed)
  static Future<Map<String, String>> getAuthHeaders() async {
    if (_isAccessTokenExpired()) {
      final refreshed = await refreshAccessToken();
      if (!refreshed) {
        return {}; // no valid token
      }
    }
    return {"Authorization": "Bearer $accessToken"};
  }
}
