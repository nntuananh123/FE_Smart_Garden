import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/token_response.dart';
import '../models/api_error.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_info.dart';
import '../models/garden.dart';

class AuthService {
  final String baseUrl;

  AuthService({required this.baseUrl});

  Future<TokenResponse> login({
    required String username,
    required String password,
    required String platform,
    required String deviceToken,
    required String versionApp,
  }) async {
    final url = Uri.parse('$baseUrl/auth/access-token');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'platform': platform,
        'deviceToken': deviceToken,
        'versionApp': versionApp,
      }),
    );

    if (response.statusCode == 200) {
      return TokenResponse.fromJson(jsonDecode(response.body));
    } else {
      final error = ApiError.fromJson(jsonDecode(response.body));
      throw Exception('${error.status} ${error.error}: ${error.message}');
    }
  }

  Future<UserInfo> getMyInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    if (accessToken == null) throw Exception('No access token found');

    final url = Uri.parse('$baseUrl/user/myinfo');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)['data'];
      return UserInfo.fromJson(data);
    } else {
      final error = ApiError.fromJson(jsonDecode(response.body));
      throw Exception('${error.status} ${error.error}: ${error.message}');
    }
  }

  Future<GardenListResponse> getGardenList({required int page, int size = 10}) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('accessToken');
    if (accessToken == null) throw Exception('No access token found');

    final url = Uri.parse('$baseUrl/garden/list?page=$page&size=$size');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      return GardenListResponse.fromJson(jsonDecode(response.body));
    } else {
      final error = ApiError.fromJson(jsonDecode(response.body));
      throw Exception('${error.status} ${error.error}: ${error.message}');
    }
  }
}