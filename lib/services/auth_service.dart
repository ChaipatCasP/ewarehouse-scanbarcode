import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _tokenBaseUrl = 'https://apils-ewarehouse-staging.jagota.com';
  static const String _apiBaseUrl =   'https://apils-ewarehouse-staging.jagota.com';

  // TODO: Replace with your actual private key
  static const String _tokenPrivateKey = 'JMblGuueFQmXEpkhswaXMKQyQPHevZgnRdhTvRkQfBKCXaQmyoVxXjkabjPBUbSW';

  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  /// Step 1: POST /Jwt/GetToken — รับ JWT ด้วย private key
  Future<String> getJwtToken() async {
    final response = await _client.post(
      Uri.parse('$_tokenBaseUrl/Jwt/GetToken'),
      headers: {
        'Authorization': 'Bearer $_tokenPrivateKey',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['jwt'] == 1 && data['token'] != null) {
        return data['token'] as String;
      }
      throw AuthException(
          data['message'] as String? ?? 'Failed to get token');
    }
    throw AuthException('GetToken failed: ${response.statusCode}');
  }

  /// Step 2: POST /Apip/WsEwarehouse/GetUserLogin — Login ด้วย username/password
  /// ใช้ token ที่ได้จาก GetToken ใส่ใน Authorization: Bearer อัตโนมัติ
  Future<UserLoginResult> getUserLogin({
    required String username,
    required String password,
  }) async {
    final jwtToken = await getJwtToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_apiBaseUrl/Apip/WsEwarehouse/GetUserLogin'),
    );
    request.headers['Authorization'] = 'Bearer $jwtToken';
    request.fields['P_USER'] = username;
    request.fields['P_PWD'] = password;

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['jwt'] == 1 && data['flag'] == 1) {
        final results = data['result'] as List<dynamic>;
        if (results.isNotEmpty) {
          return UserLoginResult.fromJson(
              results.first as Map<String, dynamic>);
        }
      }

      // flag != 1 → login error from server
      final results = data['result'] as List<dynamic>?;
      final msg = results != null && results.isNotEmpty
          ? (results.first as Map<String, dynamic>)['MSG'] as String? ?? ''
          : data['message'] as String? ?? '';
      throw AuthException(msg.isNotEmpty ? msg : 'Login failed');
    }
    throw AuthException('GetUserLogin failed: ${response.statusCode}');
  }

  /// Full login flow: ขอ JWT token ก่อน แล้ว login
  Future<UserLoginResult> login(String username, String password) async {
    return getUserLogin(username: username, password: password);
  }
}

class UserLoginResult {
  final String flag;
  final String message;
  final String company;
  final String positionCode;
  final String positionName;
  final String tokenId;

  UserLoginResult({
    required this.flag,
    required this.message,
    required this.company,
    required this.positionCode,
    required this.positionName,
    required this.tokenId,
  });

  bool get isSuccess => flag == '1';

  factory UserLoginResult.fromJson(Map<String, dynamic> json) {
    return UserLoginResult(
      flag: json['FLAG'] as String? ?? '',
      message: json['MSG'] as String? ?? '',
      company: json['COMPANY'] as String? ?? '',
      positionCode: json['POSITION_CODE'] as String? ?? '',
      positionName: json['POSITION_NAME'] as String? ?? '',
      tokenId: json['TOKEN_ID'] as String? ?? '',
    );
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
