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

  // ──────────────────────────────────────────────────────────────────────────
  // GET_LST_BOX — รายการกล่องทั้งหมดของ PO item
  // ──────────────────────────────────────────────────────────────────────────
  Future<List<LstBoxItem>> getLstBox({
    required String company,
    required String user,
    required String dType,
    required String dBook,
    required String dNo,
    required String dSeq,
    required String product,
    String key = '',
  }) async {
    final headers = await _buildProtectedHeaders();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/Apip/WsEwarehouse/GET_LST_BOX'),
    );
    request.headers.addAll(headers);
    request.fields['P_COM']     = company;
    request.fields['P_USER']    = user;
    request.fields['P_KEY']     = key;
    request.fields['P_DTYPE']   = dType;
    request.fields['P_DBOOK']   = dBook;
    request.fields['P_DNO']     = dNo;
    request.fields['P_DSEQ']    = dSeq;
    request.fields['P_PRODUCT'] = product;

    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ 📤 API REQUEST: GET_LST_BOX');
    debugPrint('│ URL    : ${request.url}');
    debugPrint('├── Form Fields ────────────────────────────────');
    request.fields.forEach((k, v) => debugPrint('│ $k = "$v"'));
    debugPrint('└─────────────────────────────────────────────');

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    final bodyPreview = response.body.length > 500
        ? '${response.body.substring(0, 500)}...[truncated]'
        : response.body;
    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ 📥 API RESPONSE: GET_LST_BOX');
    debugPrint('│ Status : ${response.statusCode}');
    debugPrint('│ Body   : $bodyPreview');
    debugPrint('└─────────────────────────────────────────────');

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> items = decoded is List
          ? decoded
          : (decoded as Map<String, dynamic>)['result'] as List<dynamic>? ?? [];
      return items
          .map((e) => LstBoxItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw ApiException('GET_LST_BOX HTTP error: ${response.statusCode}');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // GetTotBox — สรุปข้อมูล PO item (qty, hold, stock on hand ฯลฯ)
  // ──────────────────────────────────────────────────────────────────────────
  Future<List<TotBoxItem>> getTotBox({
    required String company,
    required String user,
    required String dType,
    required String dBook,
    required String dNo,
    required String dSeq,
    required String product,
    String key = '',
  }) async {
    final headers = await _buildProtectedHeaders();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/Apip/WsEwarehouse/GetTotBox'),
    );
    request.headers.addAll(headers);
    request.fields['P_COM']     = company;
    request.fields['P_USER']    = user;
    request.fields['P_KEY']     = key;
    request.fields['P_DTYPE']   = dType;
    request.fields['P_DBOOK']   = dBook;
    request.fields['P_DNO']     = dNo;
    request.fields['P_DSEQ']    = dSeq;
    request.fields['P_PRODUCT'] = product;

    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ 📤 API REQUEST: GetTotBox');
    debugPrint('│ URL    : ${request.url}');
    debugPrint('├── Form Fields ────────────────────────────────');
    request.fields.forEach((k, v) => debugPrint('│ $k = "$v"'));
    debugPrint('└─────────────────────────────────────────────');

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    final bodyPreview2 = response.body.length > 500
        ? '${response.body.substring(0, 500)}...[truncated]'
        : response.body;
    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ 📥 API RESPONSE: GetTotBox');
    debugPrint('│ Status : ${response.statusCode}');
    debugPrint('│ Body   : $bodyPreview2');
    debugPrint('└─────────────────────────────────────────────');

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> items = decoded is List
          ? decoded
          : (decoded as Map<String, dynamic>)['result'] as List<dynamic>? ?? [];
      return items
          .map((e) => TotBoxItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw ApiException('GetTotBox HTTP error: ${response.statusCode}');
    }
  }

  // ── SetStickerBoxV2 ────────────────────────────────────────────────────────

  /// POST /Apip/WsEwarehouse/SetStickerBoxV2
  ///
  /// สแกน/บันทึก Barcode ของ Supplier พร้อม Generate New Barcode
  ///
  /// Parameters:
  /// - [company]   : รหัสบริษัท เช่น "JB"
  /// - [user]      : username
  /// - [dType]     : TRANSACTION_TYPE เช่น "PE"
  /// - [dBook]     : PO_BOOK_NO เช่น "PE66"
  /// - [dNo]       : PO_NO เช่น "4"
  /// - [dSeq]      : PO_LINE เช่น "1"
  /// - [product]   : รหัสสินค้า เช่น "MTBFUN661111624"
  /// - [box]       : เลขกล่อง (ว่างได้) ถ้ากด Gen QR CODE จ่าก Manual Gen QR CODE and ถ้ามีการสแกน Barcode ของ Supplier 
  /// - [barSup]    : Barcode ของ Supplier ถ้ามีการสแกน (ว่างได้)
  /// - [mfgDate]   : วันผลิต YYYYMMDD (ว่างได้) ถ้ากด Gen QR CODE จ่าก Manual Gen QR CODE
  /// - [expDate]   : วันหมดอายุ YYYYMMDD (ว่างได้) ถ้ากด Gen QR CODE จ่าก Manual Gen QR CODE
  /// - [boxStatus] : สถานะกล่อง เช่น "N"
  /// - [mWeight]   : น้ำหนัก (ว่างได้) ถ้ากด Gen QR CODE จ่าก Manual Gen QR CODE
  Future<SetStickerBoxResult> setStickerBox({
    required String company,
    required String user,
    required String dType,
    required String dBook,
    required String dNo,
    required String dSeq,
    required String product,
    String box = '',
    String barSup = '',
    String mfgDate = '',
    String expDate = '',
    String boxStatus = '', // '' new Gen QR code, 'D' = Delete, 'O' = Reprint
    String mWeight = '',
    String key = '',
  }) async {
    final headers = await _buildProtectedHeaders();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/Apip/WsEwarehouse/SetStickerBoxV2'),
    );
    request.headers.addAll(headers);
    request.fields['P_COM']        = company;
    request.fields['P_USER']       = user;
    request.fields['P_KEY']        = key;
    request.fields['P_DTYPE']      = dType;
    request.fields['P_DBOOK']      = dBook;
    request.fields['P_DNO']        = dNo;
    request.fields['P_DSEQ']       = dSeq;
    request.fields['P_PRODUCT']    = product;
    request.fields['P_BOX']        = box;
    request.fields['P_BAR_SUP']    = barSup;
    request.fields['P_MFGDATE']    = mfgDate;
    request.fields['P_EXPDATE']    = expDate;
    request.fields['P_BOX_STATUS'] = boxStatus;
    request.fields['P_MWEIGHT']    = mWeight;

    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ 📤 API REQUEST: SetStickerBoxV2');
    debugPrint('│ URL    : ${request.url}');
    debugPrint('├── Form Fields ────────────────────────────────');
    request.fields.forEach((k, v) => debugPrint('│ $k = "$v"'));
    debugPrint('└─────────────────────────────────────────────');

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ 📥 API RESPONSE: SetStickerBoxV2');
    debugPrint('│ Status : ${response.statusCode}');
    debugPrint('│ Body   : ${response.body.length > 500 ? '${response.body.substring(0, 500)}...[truncated]' : response.body}');
    debugPrint('└─────────────────────────────────────────────');

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (decoded['jwt'] == 0) {
        throw ApiException(decoded['message'] as String? ?? 'Unauthorized (jwt=0)');
      }
      if (decoded['flag'] != null && decoded['flag'].toString() != '1') {
        final resultList = decoded['result'] as List<dynamic>?;
        final msg = resultList != null && resultList.isNotEmpty
            ? (resultList.first as Map<String, dynamic>)['MSG'] as String? ?? ''
            : decoded['message'] as String? ?? '';
        throw ApiException(msg.isNotEmpty ? msg : 'SetStickerBoxV2 failed (flag≠1)');
      }

      // ข้อมูลจริงอยู่ใน result[0] เหมือน API อื่นๆ
      final resultList = decoded['result'] as List<dynamic>?;
      final Map<String, dynamic> data = resultList != null && resultList.isNotEmpty
          ? resultList.first as Map<String, dynamic>
          : decoded;

      return SetStickerBoxResult.fromJson(data);
    } else {
      throw ApiException('SetStickerBoxV2 HTTP error: ${response.statusCode}');
    }
  }

  // ── GET_LST_DOC_INB_DTL (PSL Product Detail) ─────────────────────────────

  /// POST /Apip/WsEwarehouse/GET_LST_DOC_INB_DTL
  ///
  /// ดึงรายการสินค้า/Reprocess ของเอกสาร PSL Inbound
  ///
  /// Parameters:
  /// - [company] : รหัสบริษัท เช่น "JB"
  /// - [user]    : username
  /// - [key]     : keyword ค้นหา (optional)
  /// - [dType]   : TRANSACTION_TYPE เช่น "RO"
  /// - [dBook]   : RP_BOOK_NO เช่น "RO69"
  /// - [dNo]     : RP_NO เช่น "226"
  Future<List<LstDocInbDtlItem>> getLstDocInbDtl({
    required String company,
    required String user,
    String key = '',
    required String dType,
    required String dBook,
    required String dNo,
  }) async {
    final headers = await _buildProtectedHeaders();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/Apip/WsEwarehouse/GET_LST_DOC_INB_DTL'),
    );
    request.headers.addAll(headers);
    request.fields['P_COM']   = company;
    request.fields['P_USER']  = user;
    request.fields['P_KEY']   = key;
    request.fields['P_DTYPE'] = dType;
    request.fields['P_DBOOK'] = dBook;
    request.fields['P_DNO']   = dNo;

    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ 📤 API REQUEST: GET_LST_DOC_INB_DTL');
    debugPrint('│ URL    : ${request.url}');
    debugPrint('├── Headers ──────────────────────────────────');
    headers.forEach((k, v) {
      final display =
          v.length > 20 ? '${v.substring(0, 20)}...[truncated]' : v;
      debugPrint('│ $k: $display');
    });
    debugPrint('├── Form Fields ────────────────────────────────');
    request.fields.forEach((k, v) => debugPrint('│ $k = "$v"'));
    debugPrint('└─────────────────────────────────────────────');

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ 📥 API RESPONSE: GET_LST_DOC_INB_DTL');
    debugPrint('│ Status : ${response.statusCode}');
    debugPrint(
        '│ Body   : ${response.body.length > 500 ? '${response.body.substring(0, 500)}...[truncated]' : response.body}');
    debugPrint('└─────────────────────────────────────────────');

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is List) {
        return decoded
            .map((e) =>
                LstDocInbDtlItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      final data = decoded as Map<String, dynamic>;
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
            msg.isNotEmpty ? msg : 'GET_LST_DOC_INB_DTL failed (flag≠1)');
      }

      final rawItems = data['result'] as List<dynamic>? ?? [];
      return rawItems
          .map((e) =>
              LstDocInbDtlItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw ApiException(
          'GET_LST_DOC_INB_DTL HTTP error: ${response.statusCode}');
    }
  }

  // ── GET_LST_DOC_INBOUND (PSL) ─────────────────────────────────────────────

  /// POST /Apip/WsEwarehouse/GET_LST_DOC_INBOUND
  ///
  /// ดึงรายการเอกสาร Inbound ประเภท PSL
  ///
  /// Parameters:
  /// - [company] : รหัสบริษัท เช่น "JB"
  /// - [user]    : username
  /// - [key]     : keyword ค้นหา (optional)
  Future<List<LstDocInboundItem>> getLstDocInbound({
    required String company,
    required String user,
    String key = '',
  }) async {
    final headers = await _buildProtectedHeaders();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/Apip/WsEwarehouse/GET_LST_DOC_INBOUND'),
    );
    request.headers.addAll(headers);
    request.fields['P_COM']  = company;
    request.fields['P_USER'] = user;
    request.fields['P_KEY']  = key;

    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ 📤 API REQUEST: GET_LST_DOC_INBOUND');
    debugPrint('│ URL    : ${request.url}');
    debugPrint('│ Method : ${request.method}');
    debugPrint('├── Headers ──────────────────────────────────');
    headers.forEach((k, v) {
      final display =
          v.length > 20 ? '${v.substring(0, 20)}...[truncated]' : v;
      debugPrint('│ $k: $display');
    });
    debugPrint('├── Form Fields ────────────────────────────────');
    request.fields.forEach((k, v) => debugPrint('│ $k = "$v"'));
    debugPrint('└─────────────────────────────────────────────');

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ 📥 API RESPONSE: GET_LST_DOC_INBOUND');
    debugPrint('│ Status : ${response.statusCode}');
    debugPrint('│ Body   : ${response.body.length > 500 ? '${response.body.substring(0, 500)}...[truncated]' : response.body}');
    debugPrint('└─────────────────────────────────────────────');

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      // Response อาจเป็น List โดยตรง หรือ Map ที่มี result
      if (decoded is List) {
        return decoded
            .map((e) =>
                LstDocInboundItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      final data = decoded as Map<String, dynamic>;
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
            msg.isNotEmpty ? msg : 'GET_LST_DOC_INBOUND failed (flag≠1)');
      }

      final rawItems =
          data['result'] as List<dynamic>? ?? [];
      return rawItems
          .map((e) =>
              LstDocInboundItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw ApiException(
          'GET_LST_DOC_INBOUND HTTP error: ${response.statusCode}');
    }
  }

  // ── SEND_OTP_TO_LINE ──────────────────────────────────────────────────────

  /// POST /Apip/WsEwarehouse/SEND_OTP_TO_LINE
  ///
  /// ส่ง OTP ผ่าน LINE Notify ไปยัง Staff
  ///
  /// Parameters:
  /// - [user]       : username ผู้ login
  /// - [staffCode]  : รหัส Staff (ถ้า user คือ DEMO → ใช้ "PG0620" fixed)
  /// - [otp]        : รหัส OTP 6 หลัก
  /// - [refCode]    : Ref Code สำหรับอ้างอิง (6 ตัวอักษร)
  Future<void> sendOtpToLine({
    required String user,
    required String staffCode,
    required String otp,
    required String refCode,
  }) async {
    final headers = await _buildProtectedHeaders();

    // ── เงื่อนไข: ถ้า user คือ DEMO ใช้ staff code PG0620 fixed ──
    final effectiveStaffCode =
        user.toUpperCase() == 'DEMO' ? 'PG0620' : staffCode;

    final message =
        'OTP EWAREHOUSE : $otp\nRef: $refCode \nStaffCode:$user';

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/Apip/WsEwarehouse/SEND_OTP_TO_LINE'),
    );
    request.headers.addAll(headers);
    request.fields['P_USER']       = user;
    request.fields['P_STAFF_CODE'] = effectiveStaffCode;
    request.fields['P_MESSAGE']    = message;

    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ 📤 API REQUEST: SEND_OTP_TO_LINE');
    debugPrint('│ URL    : ${request.url}');
    debugPrint('├── Headers ──────────────────────────────────');
    headers.forEach((k, v) {
      final display = v.length > 20 ? '${v.substring(0, 20)}...[truncated]' : v;
      debugPrint('│ $k: $display');
    });
    debugPrint('├── Form Fields ────────────────────────────────');
    request.fields.forEach((k, v) => debugPrint('│ $k = "$v"'));
    debugPrint('└─────────────────────────────────────────────');

    final streamed = await _client.send(request);
    final response  = await http.Response.fromStream(streamed);

    debugPrint('┌─────────────────────────────────────────────');
    debugPrint('│ 📥 API RESPONSE: SEND_OTP_TO_LINE');
    debugPrint('│ Status : ${response.statusCode}');
    debugPrint('│ Body   : ${response.body.length > 500 ? '${response.body.substring(0, 500)}...[truncated]' : response.body}');
    debugPrint('└─────────────────────────────────────────────');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
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
            msg.isNotEmpty ? msg : 'SEND_OTP_TO_LINE failed (flag≠1)');
      }
      // Success — no return value needed
    } else {
      throw ApiException(
          'SEND_OTP_TO_LINE HTTP error: ${response.statusCode}');
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
