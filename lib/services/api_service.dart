import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'auth_service.dart';

class ApiService {
  static const String baseUrl =
      'https://apils-ewarehouse.jagota.com';

  final http.Client _client;
  final AuthService _authService;

  ApiService({http.Client? client, AuthService? authService})
      : _client = client ?? http.Client(),
        _authService = authService ?? AuthService();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// TOKEN_ID จาก GetUserLogin (เก็บหลัง login สำเร็จ)
  String? _userToken;
  String _username = '';
  String _company  = 'JB';

  void setAuthToken(String token) {
    _userToken = token;
  }

  /// เก็บข้อมูล user หลัง login สำเร็จ
  void setUserInfo({required String username, String company = 'JB'}) {
    _username = username;
    _company  = company;
  }

  String get username => _username;
  String get company  => _company;

  /// สร้าง headers สำหรับ API ที่ต้องการ JWT + x-user-token
  Future<Map<String, String>> _buildProtectedHeaders() async {
    final jwt = await _authService.getJwtToken();
    return {
      'Authorization': 'Bearer $jwt',
      if (_userToken != null) 'x-user-token': _userToken!,
    };
  }

  Map<String, String> get _authHeaders => {
        ..._headers,
        if (_userToken != null) 'Authorization': 'Bearer $_userToken',
      };

  /// Login with username and password
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['token'] != null) {
          setAuthToken(data['token'] as String);
        }
        return data;
      } else {
        throw ApiException('Login failed: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      // For demo, return mock data
      return _mockLogin(username, password);
    }
  }

  /// Fetch purchase orders list
  Future<List<PurchaseOrder>> getPurchaseOrders({String? search}) async {
    try {
      final queryParams = search != null ? '?search=$search' : '';
      final response = await _client.get(
        Uri.parse('$baseUrl/purchase-orders$queryParams'),
        headers: _authHeaders,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((e) => PurchaseOrder.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException('Failed to fetch POs: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      return _mockPurchaseOrders();
    }
  }

  /// Fetch PO detail
  Future<PODetail> getPODetail(String poNumber) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/purchase-orders/$poNumber'),
        headers: _authHeaders,
      );

      if (response.statusCode == 200) {
        return PODetail.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      } else {
        throw ApiException('Failed to fetch detail: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      return _mockPODetail(poNumber);
    }
  }

  /// Scan barcode and get product info for QR code generation
  Future<QRCodeData> scanBarcode(String barcode) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/scan/barcode'),
        headers: _authHeaders,
        body: jsonEncode({'barcode': barcode}),
      );

      if (response.statusCode == 200) {
        return QRCodeData.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      } else {
        throw ApiException('Scan failed: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      return _mockScanResult(barcode);
    }
  }

  /// Generate QR code from manual entry data
  Future<QRCodeData> generateQRCode({
    required String packDate,
    required String expDate,
    required double weight,
    required String boxNumber,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/qrcode/generate'),
        headers: _authHeaders,
        body: jsonEncode({
          'packDate': packDate,
          'expDate': expDate,
          'weight': weight,
          'boxNumber': boxNumber,
        }),
      );

      if (response.statusCode == 200) {
        return QRCodeData.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      } else {
        throw ApiException('QR generate failed: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      return _mockGenerateQR(packDate, expDate, weight, boxNumber);
    }
  }

  // ── Mock Data (for development/demo) ──

  Map<String, dynamic> _mockLogin(String username, String password) {
    return {
      'token': 'mock_token_12345',
      'user': {'username': username, 'name': 'Demo User'},
    };
  }

  List<PurchaseOrder> _mockPurchaseOrders() {
    return [
      PurchaseOrder(
        poNumber: 'PE68/1407',
        supplier: 'EUROPASTRY',
        storageType: 'FROZEN',
        temperature: '-18°C',
        status: 'pending',
      ),
      PurchaseOrder(
        poNumber: 'PE68/1408',
        supplier: 'NESTLE LOGISTICS',
        storageType: 'CHILLED',
        temperature: '2-5°C',
        status: 'pending',
      ),
      PurchaseOrder(
        poNumber: 'PE68/1392',
        supplier: 'GLOBAL GRAINS',
        storageType: 'DRY',
        temperature: 'Room',
        status: 'completed',
      ),
    ];
  }

  PODetail _mockPODetail(String poNumber) {
    return PODetail(
      poNumber: poNumber,
      vendor: 'Global Foods Inc.',
      orderDate: 'Oct 24, 2023',
      totalItems: 12,
      totalWeight: '2,450.50 KG',
      status: 'Completed',
      items: [
        POItem(
          name: 'Frozen Pork Ribs',
          sku: 'PO-PR-001',
          unit: 'KG',
          ordered: 502.82,
          received: 502.82,
          pending: 0,
        ),
        POItem(
          name: 'Wheat Flour Premium',
          sku: 'PO-WF-012',
          unit: 'BAG',
          ordered: 100.00,
          received: 100.00,
          pending: 0,
        ),
        POItem(
          name: 'Cooking Oil 5L',
          sku: 'PO-CO-088',
          unit: 'BOTTLE',
          ordered: 24.00,
          received: 24.00,
          pending: 0,
        ),
      ],
    );
  }

  QRCodeData _mockScanResult(String barcode) {
    return QRCodeData(
      qrContent: 'JAGOTA|$barcode|BOX-4921-A|24.5|2023-10-24|2024-10-24',
      boxNumber: 'BOX-4921-A',
      packDate: '2023-10-24',
      expDate: '2024-10-24',
      weight: 24.5,
    );
  }

  QRCodeData _mockGenerateQR(
    String packDate,
    String expDate,
    double weight,
    String boxNumber,
  ) {
    return QRCodeData(
      qrContent: 'JAGOTA|$boxNumber|$weight|$packDate|$expDate',
      boxNumber: boxNumber,
      packDate: packDate,
      expDate: expDate,
      weight: weight,
    );
  }

  // ── GetRcvPlanDtl ──────────────────────────────────────────────────────────

  /// GET /Apip/WsEwarehouse/GetRcvPlanDtl
  ///
  /// ดึงรายละเอียด Receive Plan
  ///
  /// Parameters:
  /// - [company]  : รหัสบริษัท เช่น "JB"
  /// - [user]     : username ผู้ใช้
  /// - [key]      : keyword ค้นหา (optional)
  /// - [type]     : ประเภท เช่น "PO"
  /// - [date]     : วันที่ format YYYYMMDD เช่น "20210203"
  /// - [page]     : หน้าที่ต้องการ (เริ่มจาก 1)
  Future<RcvPlanDtlResult> getRcvPlanDtl({
    required String company,
    required String user,
    String key = '',
    String type = 'PO',
    required String date,
    int page = 1,
  }) async {
    final headers = await _buildProtectedHeaders();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/Apip/WsEwarehouse/GetRcvPlanDtl'),
    );
    request.headers.addAll(headers);
    request.fields['P_COM']  = company;
    request.fields['P_USER'] = user;
    request.fields['P_KEY']  = key;
    request.fields['P_TYPE'] = type;
    request.fields['P_DATE'] = date;
    request.fields['P_PAGE'] = page.toString();

    // ── 🔍 Debug: แสดง request ที่ส่งออกไป ──────────────────────────────
    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ 📤 API REQUEST: GetRcvPlanDtl');
    debugPrint('│ URL    : ${request.url}');
    debugPrint('│ Method : ${request.method}');
    debugPrint('├── Headers ──────────────────────────────────');
    headers.forEach((k, v) {
      // ซ่อนบางส่วนของ token เพื่อความปลอดภัย
      final display = v.length > 20 ? '${v.substring(0, 20)}...[truncated]' : v;
      debugPrint('│ $k: $display');
    });
    debugPrint('├── Form Fields ────────────────────────────────');
    request.fields.forEach((k, v) => debugPrint('│ $k = "$v"'));
    debugPrint('└─────────────────────────────────────────────');
    // ─────────────────────────────────────────────────────────────────────

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    // ── 🔍 Debug: แสดง response ที่ได้รับ ──────────────────────────────
    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ 📥 API RESPONSE: GetRcvPlanDtl');
    debugPrint('│ Status : ${response.statusCode}');
    debugPrint('│ Body   : ${response.body.length > 500 ? '${response.body.substring(0, 500)}...[truncated]' : response.body}');
    debugPrint('└─────────────────────────────────────────────');
    // ─────────────────────────────────────────────────────────────────────

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // jwt == 0 หรือ flag != 1 → ถือว่า error
      if (data['jwt'] == 0) {
        throw ApiException(
            data['message'] as String? ?? 'Unauthorized (jwt=0)');
      }
      if (data['flag'] != null && data['flag'].toString() != '1') {
        final results = data['result'] as List<dynamic>?;
        final msg = results != null && results.isNotEmpty
            ? (results.first as Map<String, dynamic>)['MSG'] as String? ?? ''
            : data['message'] as String? ?? '';
        throw ApiException(
            msg.isNotEmpty ? msg : 'GetRcvPlanDtl failed (flag≠1)');
      }

      return RcvPlanDtlResult.fromJson(data, page);
    } else {
      throw ApiException(
          'GetRcvPlanDtl HTTP error: ${response.statusCode}');
    }
  }

  // ── GetPurProduct ──────────────────────────────────────────────────────────

  /// POST /Apip/WsEwarehouse/GetPurProduct
  ///
  /// ดึงรายการสินค้าของ PO ที่เลือก
  ///
  /// Parameters:
  /// - [company]   : รหัสบริษัท เช่น "JB"
  /// - [user]      : username
  /// - [type]      : TRANSACTION_TYPE เช่น "PE"
  /// - [poBookNo]  : PO_BOOK_NO เช่น "PE68"
  /// - [poNo]      : PO_NO เช่น "1407"
  /// - [page]      : หน้าที่ต้องการ (เริ่มจาก 1)
  Future<PurProductResult> getPurProduct({
    required String company,
    required String user,
    required String type,
    required String poBookNo,
    required String poNo,
    int page = 1,
  }) async {
    final headers = await _buildProtectedHeaders();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/Apip/WsEwarehouse/GetPurProduct'),
    );
    request.headers.addAll(headers);
    request.fields['P_COM']      = company;
    request.fields['P_USER']     = user;
    request.fields['P_KEY']     = "";
    request.fields['P_TYPE']     = type;
    request.fields['P_BOOK']  = poBookNo;
    request.fields['P_NO']    = poNo;
    request.fields['P_PAGE']     = page.toString();

    // ── 🔍 Debug ──────────────────────────────────────────────────────────
    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ 📤 API REQUEST: GetPurProduct');
    debugPrint('│ URL    : ${request.url}');
    debugPrint('│ Method : ${request.method}');
    debugPrint('├── Headers ──────────────────────────────────');
    headers.forEach((k, v) {
      final display = v.length > 20 ? '${v.substring(0, 20)}...[truncated]' : v;
      debugPrint('│ $k: $display');
    });
    debugPrint('├── Form Fields ────────────────────────────────');
    request.fields.forEach((k, v) => debugPrint('│ $k = "$v"'));
    debugPrint('└─────────────────────────────────────────────');
    // ─────────────────────────────────────────────────────────────────────

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ 📥 API RESPONSE: GetPurProduct');
    debugPrint('│ Status : ${response.statusCode}');
    debugPrint('│ Body   : ${response.body.length > 500 ? '${response.body.substring(0, 500)}...[truncated]' : response.body}');
    debugPrint('└─────────────────────────────────────────────');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['jwt'] == 0) {
        throw ApiException(data['message'] as String? ?? 'Unauthorized (jwt=0)');
      }
      if (data['flag'] != null && data['flag'].toString() != '1') {
        final results = data['result'] as List<dynamic>?;
        final msg = results != null && results.isNotEmpty
            ? (results.first as Map<String, dynamic>)['MSG'] as String? ?? ''
            : data['message'] as String? ?? '';
        throw ApiException(msg.isNotEmpty ? msg : 'GetPurProduct failed (flag≠1)');
      }

      return PurProductResult.fromJson(data, page);
    } else {
      throw ApiException('GetPurProduct HTTP error: ${response.statusCode}');
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
