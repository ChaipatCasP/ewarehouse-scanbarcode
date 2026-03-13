import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  // TODO: Replace with your actual API base URL
  static const String baseUrl = 'https://api.example.com';

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  String? _authToken;

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> get _authHeaders => {
        ..._headers,
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
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
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
