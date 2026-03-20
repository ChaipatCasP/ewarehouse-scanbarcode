import 'package:flutter/material.dart';
import 'package:brother_printer/brother_printer.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/brother_ble_service.dart';

class ScanQRScreen extends StatefulWidget {
  final ApiService apiService;
  // ── Product-scan mode (from PurProductScreen) ─────────────────────────────
  final PurProductItem? item;
  final RcvPlanDtlItem? plan;

  const ScanQRScreen({
    super.key,
    required this.apiService,
    this.item,
    this.plan,
  });

  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  // ── Generic scan fields ────────────────────────────────────────────────────
  final _barcodeController = TextEditingController();
  final _weightController = TextEditingController();
  final _boxController = TextEditingController();
  DateTime? _packDate;
  DateTime? _expDate;
  bool _autoPrint = true;
  bool _isLoading = false;
  QRCodeData? _qrResult;
  bool _showScanner = false;

  // ── Product-scan mode state ────────────────────────────────────────────────
  bool get _isProductMode => widget.item != null;
  List<LstBoxItem> _boxList = [];
  TotBoxItem? _totBox;
  bool _loadingBoxData = false;
  String? _boxDataError;

  // ── Bluetooth printer (SPP / thermal) ─────────────────────────
  final _btPrinter = BtPrinterService();
  String _printerName = '';

  // ── Brother BLE printer (PT-P300BT) ───────────────────────
  final _brotherBLE = BrotherBLEService();
  String _brotherName = '';

  @override
  void initState() {
    super.initState();
    if (_isProductMode) _loadBoxData();
  }

  Future<void> _loadBoxData() async {
    final item = widget.item!;
    final plan = widget.plan!;
    setState(() {
      _loadingBoxData = true;
      _boxDataError = null;
    });
    try {
      final results = await Future.wait([
        widget.apiService.getLstBox(
          company: item.company.isNotEmpty ? item.company : widget.apiService.company,
          user: widget.apiService.username,
          dType: plan.transactionType,
          dBook: item.poBookNo.isNotEmpty ? item.poBookNo : plan.poBookNo,
          dNo: item.poNo.isNotEmpty ? item.poNo : plan.poNo,
          dSeq: item.poLine,
          product: item.matCode,
        ),
        widget.apiService.getTotBox(
          company: item.company.isNotEmpty ? item.company : widget.apiService.company,
          user: widget.apiService.username,
          dType: plan.transactionType,
          dBook: item.poBookNo.isNotEmpty ? item.poBookNo : plan.poBookNo,
          dNo: item.poNo.isNotEmpty ? item.poNo : plan.poNo,
          dSeq: item.poLine,
          product: item.matCode,
        ),
      ]);
      if (!mounted) return;
      final boxes = results[0] as List<LstBoxItem>;
      final tots  = results[1] as List<TotBoxItem>;
      final firstTot = tots.isNotEmpty ? tots.first : null;
      // ตั้งค่า BOX NUMBER = MAX_BOX + 1 ทุกครั้งที่ GetTotBox คืนค่า
      if (firstTot != null) {
        final maxBox = int.tryParse(firstTot.maxBox) ?? 0;
        _boxController.text = (maxBox + 1).toString();
      }
      setState(() {
        _boxList = boxes;
        _totBox  = firstTot;
        _loadingBoxData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _boxDataError = e.toString();
        _loadingBoxData = false;
      });
    }
  }

  Future<void> _handleBarcodeScan(String barcode) async {
    if (barcode.isEmpty) return;

    setState(() {
      _isLoading = true;
      _showScanner = false;
      _barcodeController.text = barcode;
    });

    try {
      if (_isProductMode) {
        final item = widget.item!;
        final plan = widget.plan!;
        final result = await widget.apiService.setStickerBox(
          company: item.company.isNotEmpty ? item.company : widget.apiService.company,
          user: widget.apiService.username,
          dType: plan.transactionType,
          dBook: item.poBookNo.isNotEmpty ? item.poBookNo : plan.poBookNo,
          dNo: item.poNo.isNotEmpty ? item.poNo : plan.poNo,
          dSeq: item.poLine,
          product: item.matCode,
          box: _boxController.text.trim(),
          barSup: barcode,
        );
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _barcodeController.clear();
        });
        _loadBoxData();
        _showStickerResultDialog(result);
      } else {
        final result = await widget.apiService.scanBarcode(barcode);
        if (!mounted) return;
        setState(() {
          _qrResult = result;
          _isLoading = false;
        });
        _showQRDialog(result);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleManualGenerate() async {
    if (_packDate == null || _expDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Pack Date and Exp Date')),
      );
      return;
    }

    final weight = double.tryParse(_weightController.text);
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid weight')),
      );
      return;
    }

    final boxNumber = _boxController.text.trim();
    if (boxNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter box number')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isProductMode) {
        final item = widget.item!;
        final plan = widget.plan!;
        final dateFmt = DateFormat('yyyyMMdd');
        final result = await widget.apiService.setStickerBox(
          company: item.company.isNotEmpty ? item.company : widget.apiService.company,
          user: widget.apiService.username,
          dType: plan.transactionType,
          dBook: item.poBookNo.isNotEmpty ? item.poBookNo : plan.poBookNo,
          dNo: item.poNo.isNotEmpty ? item.poNo : plan.poNo,
          dSeq:item.poLine,
          product: item.matCode,
          box: boxNumber,
          barSup: '',
          mfgDate: dateFmt.format(_packDate!),
          expDate: dateFmt.format(_expDate!),
          mWeight: _weightController.text.trim(),
        );
        if (!mounted) return;
        setState(() => _isLoading = false);
        _loadBoxData();
        _showStickerResultDialog(result, _weightController.text.trim());
      } else {
        final dateFormat = DateFormat('yyyy-MM-dd');
        final result = await widget.apiService.generateQRCode(
          packDate: dateFormat.format(_packDate!),
          expDate: dateFormat.format(_expDate!),
          weight: weight,
          boxNumber: boxNumber,
        );
        if (!mounted) return;
        setState(() {
          _qrResult = result;
          _isLoading = false;
        });
        _showQRDialog(result);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleReprint() async {
    final boxNumber = _boxController.text.trim();
    if (boxNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter box number')),
      );
      return;
    }

    final item = widget.item!;
    final plan = widget.plan!;
    setState(() => _isLoading = true);
    try {
      final result = await widget.apiService.setStickerBox(
        company: item.company.isNotEmpty ? item.company : widget.apiService.company,
        user: widget.apiService.username,
        dType: plan.transactionType,
        dBook: item.poBookNo.isNotEmpty ? item.poBookNo : plan.poBookNo,
        dNo: item.poNo.isNotEmpty ? item.poNo : plan.poNo,
        dSeq: item.poLine,
        product: item.matCode,
        box: boxNumber,
        barSup: '',
        boxStatus: 'O',
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showStickerResultDialog(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showStickerResultDialog(SetStickerBoxResult result, [String weight = '']) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StickerResultSheet(result: result, weight: weight),
    );
    _autoPrintLabel(result, weight);
    // Brother BLE auto-print (only if saved device is configured)
    if (_brotherBLE.savedDeviceId.isNotEmpty) {
      final boxNo = result.boxNo.isNotEmpty ? result.boxNo : _boxController.text.trim();
      final w     = weight.isNotEmpty ? weight : result.qty;
      _autoPrintBrother(boxNo, w);
    }
  }

  Future<void> _autoPrintBrother(String boxNo, String weight) async {
    final ok = await _brotherBLE.printLabel(boxNo: boxNo, weight: weight);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Brother: ปริ้นไม่สำเร็จ — ตรวจสอบการเชื่อมต่อ'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _showBrotherScanSheet() async {
    if (!mounted) return;

    // Show device selector / MAC input sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _BrotherConnectSheet(
        brotherBLE: _brotherBLE,
        onConnected: (name) {
          if (!mounted) return;
          setState(() => _brotherName = name);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Brother เชื่อมต่อแล้ว — $name'),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        },
      ),
    );
  }

  Future<void> _autoPrintLabel(
      SetStickerBoxResult result, String weight) async {
    final connected = await _btPrinter.isConnected;
    if (!connected) return;
    final expDateFmt = SetStickerBoxResult.fmtDate(result.expDate);
    final supBarcode =
        result.barcodeSup.isNotEmpty ? result.barcodeSup : result.productCode;
    final ok = await _btPrinter.printStickerLabel(
      newBarcode: result.newBarcode,
      poNo: result.poNo,
      supBarcode: supBarcode,
      expDate: expDateFmt,
      boxNo: result.boxNo,
      weight: weight.isNotEmpty ? weight : result.qty,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ ปริ้นไม่สำเร็จ — ตรวจสอบการเชื่อมต่อ Bluetooth'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _showPrinterSelectorSheet() async {
    // 1. Request runtime BT permissions (Android 12+)
    final granted = await _btPrinter.requestPermissions();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ ไม่ได้รับอนุญาต Bluetooth — กรุณาอนุญาตใน Settings'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // 2. Check BT is turned on
    final enabled = await _btPrinter.isBluetoothEnabled;
    if (!enabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเปิด Bluetooth ก่อน')),
      );
      return;
    }
    final devices = await _btPrinter.getPairedDevices();
    if (!mounted) return;
    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'ไม่พบเครื่องปริ้น — จัดคู่เครื่อง Bluetooth ก่อน')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.print, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('เลือกเครื่องปริ้น',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...devices.map(
            (d) => ListTile(
              leading: const Icon(Icons.bluetooth, color: AppTheme.primary),
              title: Text(d.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(d.macAdress,
                  style: const TextStyle(fontSize: 11)),
              trailing:
                  _btPrinter.selectedPrinter?.macAdress == d.macAdress
                      ? const Icon(Icons.check_circle,
                          color: Color(0xFF16A34A))
                      : null,
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await _btPrinter.connect(d);
                if (!mounted) return;
                setState(() {
                  _printerName = ok ? d.name : '';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? '✅ เชื่อมต่อ ${d.name} แล้ว'
                        : '❌ ไม่สามารถเชื่อมต่อ ${d.name}'),
                    backgroundColor:
                        ok ? const Color(0xFF16A34A) : Colors.red,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showQRDialog(QRCodeData data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _QRResultSheet(data: data),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isPackDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isPackDate) {
          _packDate = picked;
        } else {
          _expDate = picked;
        }
      });
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _weightController.dispose();
    _boxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showScanner) {
      return _buildScannerView();
    }

    // ── Product-scan mode ──────────────────────────────────────────────────
    if (_isProductMode) {
      return _buildProductScanMode();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan and Print',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: false,
        actions: [
          Text(
            'PrintAuto',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          Switch(
            value: _autoPrint,
            onChanged: (v) => setState(() => _autoPrint = v),
            activeColor: AppTheme.primary,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Scan Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.barcode_reader,
                                color: AppTheme.primary, size: 22),
                            const SizedBox(width: 8),
                            const Text(
                              'Scan Supplier Bar Code',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _barcodeController,
                                decoration: InputDecoration(
                                  hintText: 'Scan or enter barcode',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.qr_code_scanner,
                                        color: Colors.grey),
                                    onPressed: () =>
                                        setState(() => _showScanner = true),
                                  ),
                                ),
                                onSubmitted: _handleBarcodeScan,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () => setState(() => _showScanner = true),
                            icon: const Icon(Icons.camera_alt_outlined,
                                size: 18),
                            label: const Text('Open Camera Scanner'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 24),
                    child: Container(
                      height: 1,
                      color: const Color(0xFFF1F5F9),
                    ),
                  ),

                  // Manual Entry Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.edit_note,
                                color: AppTheme.primary, size: 22),
                            const SizedBox(width: 8),
                            const Text(
                              'Manual Gen QR Code',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Date Fields
                        Row(
                          children: [
                            Expanded(
                              child: _DateField(
                                label: 'Pack Date',
                                date: _packDate,
                                onTap: () => _selectDate(context, true),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _DateField(
                                label: 'Exp Date',
                                date: _expDate,
                                onTap: () => _selectDate(context, false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Weight & Box
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'WEIGHT (KG)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey.shade500,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _weightController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                      hintText: '0.00',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'BOX NUMBER',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey.shade500,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _boxController,
                                    decoration: const InputDecoration(
                                      hintText: 'BOX-001',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Action Buttons
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _handleManualGenerate,
                            icon: const Icon(Icons.qr_code_2),
                            label: const Text('Gen QR Code'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.print),
                            label: const Text('Reprint Label'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              side: BorderSide(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.2),
                                  width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Last Generated
                        if (_qrResult != null) ...[
                          Text(
                            'LAST GENERATED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade400,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => _showQRDialog(_qrResult!),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Icon(Icons.qr_code,
                                        color: Colors.grey),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _qrResult!.boxNumber,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          '${_qrResult!.weight} kg • ${_qrResult!.packDate}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right,
                                      color: Colors.grey.shade300),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
      // Bottom Navigation
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 8,
          top: 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.qr_code_scanner, 'Scan', true),
            _navItem(Icons.history, 'History', false),
            _navItem(Icons.inventory_2_outlined, 'Inventory', false),
            _navItem(Icons.settings_outlined, 'Settings', false),
          ],
        ),
      ),
    );
  }

  // ── Product-scan mode UI ───────────────────────────────────────────────────
  Widget _buildProductScanMode() {
    final item = widget.item!;
    final plan = widget.plan!;

    final scannedQty  = double.tryParse(_totBox?.totBarcodeQty ?? '') ?? 0.0;
    final totalQty    = item.poQty;
    final pct         = totalQty > 0 ? (scannedQty / totalQty).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.matCode.isNotEmpty ? item.matCode : item.fullPoNo,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
            Text(
              plan.fullPoNo,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        actions: [
          // Brother BLE printer button (PT-P300BT)
          IconButton(
            icon: Icon(
              Icons.label_outline,
              color: _brotherName.isNotEmpty
                  ? const Color(0xFF7C3AED)
                  : Colors.grey.shade400,
            ),
            tooltip: _brotherName.isNotEmpty
                ? _brotherName
                : 'เชื่อมต่อ PT-P300BT',
            onPressed: _showBrotherScanSheet,
          ),
          // SPP thermal printer button
          IconButton(
            icon: Icon(
              Icons.print_outlined,
              color: _printerName.isNotEmpty
                  ? AppTheme.primary
                  : Colors.grey.shade400,
            ),
            tooltip: _printerName.isNotEmpty ? _printerName : 'เลือกเครื่องปริ้น',
            onPressed: _showPrinterSelectorSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primary),
            onPressed: _loadBoxData,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Product Info Banner ──────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.matDesc.isNotEmpty ? item.matDesc : '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (item.matDesc2.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(item.matDesc2,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                ],
                const SizedBox(height: 10),
                // Qty summary row
                _loadingBoxData
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: CircularProgressIndicator(
                              color: AppTheme.primary, strokeWidth: 2),
                        ),
                      )
                    : _boxDataError != null
                        ? _InlineError(
                            message: _boxDataError!, onRetry: _loadBoxData)
                        : Column(
                            children: [

                              // Progress bar
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Scanned ${(pct * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500),
                                      ),
                                      Text(
                                        '${_fmtD(scannedQty)} / ${_fmtD(totalQty)}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      minHeight: 8,
                                      backgroundColor:
                                          const Color(0xFFE2E8F0),
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        pct >= 1.0
                                            ? const Color(0xFF16A34A)
                                            : AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Extra info from TotBox
                              if (_totBox != null) ...[
                                // const SizedBox(height: 10),
                                // const Divider(height: 1),
                                // const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (_totBox!.accepted.isNotEmpty &&
                                        _totBox!.accepted != '0')
                                      _SmallChip(
                                        icon: Icons.check_circle_outline,
                                        label:
                                            'Accepted: ${_totBox!.accepted}',
                                        color: const Color(0xFF16A34A),
                                      ),
                                    if (_totBox!.withIssue.isNotEmpty &&
                                        _totBox!.withIssue != '0')
                                      _SmallChip(
                                        icon: Icons.warning_amber_outlined,
                                        label:
                                            'Issue: ${_totBox!.withIssue}',
                                        color: const Color(0xFFD97706),
                                      ),
                                    if (_totBox!.rejected.isNotEmpty &&
                                        _totBox!.rejected != '0')
                                      _SmallChip(
                                        icon: Icons.cancel_outlined,
                                        label:
                                            'Rejected: ${_totBox!.rejected}',
                                        color: Colors.red.shade400,
                                      ),
                                    if (_totBox!.hold == 'Y')
                                      _SmallChip(
                                        icon: Icons.pause_circle_outline,
                                        label: 'Hold',
                                        color: Colors.red.shade400,
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Scan bar ─────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      hintText: 'Scan Or Enter Barcode',
                      hintStyle: TextStyle(
                          color: Colors.grey.shade400, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.qr_code_scanner,
                          color: Colors.grey.shade400, size: 20),
                      suffixIcon: _barcodeController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  size: 18, color: Colors.grey),
                              onPressed: () {
                                _barcodeController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: _handleBarcodeScan,
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _showScanner = true),
                    child: const Padding(
                      padding: EdgeInsets.all(11),
                      child: Icon(Icons.camera_alt_outlined,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Manual Gen QR ────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit_note,
                        color: AppTheme.primary, size: 18),
                    const SizedBox(width: 6),
                    const Text(
                      'Manual Gen QR Code',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Pack Date & Exp Date
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Pack Date',
                        date: _packDate,
                        onTap: () => _selectDate(context, true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateField(
                        label: 'Exp Date',
                        date: _expDate,
                        onTap: () => _selectDate(context, false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Weight & Box Number
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WEIGHT (KG)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _weightController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              hintStyle: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: AppTheme.primary, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BOX NUMBER',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _boxController,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'BOX-001',
                              hintStyle: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: AppTheme.primary, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _handleManualGenerate,
                          icon: const Icon(Icons.qr_code_2, size: 18),
                          label: const Text('Gen QR Code'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _handleReprint,
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text('Reprint'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: BorderSide(
                                color:
                                    AppTheme.primary.withValues(alpha: 0.4),
                                width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Box list section header (fixed) ──────────────────────
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                const Text(
                  'Scanned Box List',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                if (!_loadingBoxData)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_boxList.length} Box',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Box list (independently scrollable) ──────────────────
          Expanded(
            child: _loadingBoxData
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.primary),
                  )
                : RefreshIndicator(
                    onRefresh: _loadBoxData,
                    color: AppTheme.primary,
                    child: _boxDataError != null
                        ? ListView(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            children: [
                              _InlineError(
                                  message: _boxDataError!,
                                  onRetry: _loadBoxData),
                            ],
                          )
                        : _boxList.isEmpty
                            ? ListView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(32),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.inbox_outlined,
                                              size: 56,
                                              color: Color(0xFFCBD5E1)),
                                          SizedBox(height: 12),
                                          Text(
                                            'ยังไม่มี Box ที่สแกน',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: _boxList.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) => _BoxCard(
                                  box: _boxList[i],
                                  index: i + 1,
                                  onDelete: () =>
                                      _handleDeleteBox(_boxList[i]),
                                ),
                              ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteBox(LstBoxItem box) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบ Box ${box.boxNo.isNotEmpty ? box.boxNo : '-'} ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final item = widget.item!;
    final plan = widget.plan!;
    setState(() => _isLoading = true);
    try {
      await widget.apiService.setStickerBox(
        company: item.company.isNotEmpty ? item.company : widget.apiService.company,
        user: widget.apiService.username,
        dType: plan.transactionType,
        dBook: item.poBookNo.isNotEmpty ? item.poBookNo : plan.poBookNo,
        dNo: item.poNo.isNotEmpty ? item.poNo : plan.poNo,
        dSeq: item.poLine,
        product: item.matCode,
        box: box.boxNo,
        barSup: box.barcode,
        mfgDate: box.mfgDate,
        expDate: box.expDate,
        boxStatus: 'D',
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      _loadBoxData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ลบ Box ${box.boxNo} สำเร็จ'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _fmtD(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  Widget _buildScannerView() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => setState(() => _showScanner = false),
        ),
        title: const Text(
          'Scan Barcode',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                _handleBarcodeScan(barcodes.first.rawValue!);
              }
            },
          ),
          // Scan overlay
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'Point the camera at a barcode',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => setState(() => _showScanner = false),
                  child: const Text(
                    'Enter manually instead',
                    style: TextStyle(
                      color: Colors.white70,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            color: active ? AppTheme.primary : Colors.grey.shade400,
            size: 24),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppTheme.primary : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade500,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    date != null
                        ? DateFormat('yyyy-MM-dd').format(date!)
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 14,
                      color: date != null ? Colors.black : Colors.grey.shade400,
                    ),
                  ),
                ),
                Icon(Icons.calendar_today,
                    size: 18, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QRResultSheet extends StatelessWidget {
  final QRCodeData data;

  const _QRResultSheet({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'QR Code Generated',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.boxNumber,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          // QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: QrImageView(
              data: data.qrContent,
              version: QrVersions.auto,
              size: 200,
              gapless: false,
              errorStateBuilder: (cxt, err) {
                return const Center(
                  child: Text('Error generating QR code'),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          // Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                _infoRow('Box Number', data.boxNumber),
                _infoRow('Weight', '${data.weight} kg'),
                _infoRow('Pack Date', data.packDate),
                _infoRow('Exp Date', data.expDate),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.print, size: 20),
                      label: const Text('Print'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(
                            color: AppTheme.primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sticker Result Sheet ─────────────────────────────────────────────────────

class _StickerResultSheet extends StatelessWidget {
  final SetStickerBoxResult result;
  final String weight;
  const _StickerResultSheet({required this.result, this.weight = ''});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
              SizedBox(width: 6),
              Text(
                'Gen QR Code สำเร็จ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Label preview ──────────────────────────────────────────
          _LabelCard(result: result, weight: weight),
          const SizedBox(height: 20),
          // ── Buttons ────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('Print'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(
                          color: AppTheme.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('ปิด',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Label Card (matches PDF label format) ────────────────────────────────────
//
//  +──────────────+──────────────────────+
//  │              │  PO69/1180/01        │
//  │   QR Code   │  MTP%0844            │
//  │              │  Exp: 15/03/2027     │
//  +──────63──────+──────999.9 Kg.───────+

class _LabelCard extends StatelessWidget {
  final SetStickerBoxResult result;
  final String weight;
  const _LabelCard({required this.result, required this.weight});

  @override
  Widget build(BuildContext context) {
    final expDateFmt    = SetStickerBoxResult.fmtDate(result.expDate);
    final displayWeight = weight.isNotEmpty
        ? weight
        : (result.qty.isNotEmpty ? result.qty : '-');
    final displaySupBarcode = result.barcodeSup.isNotEmpty
        ? result.barcodeSup
        : result.productCode;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      // PDF ratio: 226.8 × 147.6 ≈ 1.537
      child: AspectRatio(
        aspectRatio: 226.8 / 147.6,
        child: Column(
          children: [
            // ── Main row: QR | text info ───────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left – QR code
                  Expanded(
                    flex: 44,
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: result.newBarcode.isNotEmpty
                          ? QrImageView(
                              data: result.newBarcode,
                              version: QrVersions.auto,
                              gapless: false,
                            )
                          : const Center(
                              child: Icon(Icons.qr_code,
                                  size: 48, color: Colors.grey)),
                    ),
                  ),
                  // Vertical divider
                  Container(width: 1.5, color: Colors.black),
                  // Right – PO / Barcode Sup / Exp date
                  Expanded(
                    flex: 56,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text(
                            result.poNo.isNotEmpty ? result.poNo : '-',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            displaySupBarcode.isNotEmpty
                                ? displaySupBarcode
                                : '-',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Exp: ${expDateFmt.isNotEmpty ? expDateFmt : '-'}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Horizontal divider
            Container(height: 1.5, color: Colors.black),
            // ── Bottom row: Box number | Weight ───────────────────
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  // Box number – large font
                  Expanded(
                    flex: 44,
                    child: Center(
                      child: Text(
                        result.boxNo.isNotEmpty ? result.boxNo : '-',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1.5, color: Colors.black),
                  // Weight
                  Expanded(
                    flex: 56,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            displayWeight,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            'Kg.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Box Card ──────────────────────────────────────────────────────────────────

class _BoxCard extends StatelessWidget {
  final LstBoxItem box;
  final int index;
  final VoidCallback? onDelete;
  const _BoxCard({required this.box, required this.index, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Index
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$index',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                         'Box No. ${box.boxNo.isNotEmpty ? box.boxNo : '-'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (box.qty.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Qty: ${box.qty}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      if (onDelete != null) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: onDelete,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.delete_outline,
                                size: 20, color: Colors.red),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (box.barcode.isNotEmpty)
                        _InfoRow(
                            icon: Icons.qr_code,
                            label: box.barcode),
                      // if (box.newBarcode.isNotEmpty)
                      //   _InfoRow(
                      //       icon: Icons.qr_code_2,
                      //       label: 'New: ${box.newBarcode}'),
                      if (box.mfgDate.isNotEmpty)
                        _InfoRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'MFG: ${_fmtDate(box.mfgDate)}'),
                      if (box.expDate.isNotEmpty)
                        _InfoRow(
                            icon: Icons.hourglass_bottom_outlined,
                            label: 'EXP: ${_fmtDate(box.expDate)}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(String raw) {
    if (raw.length == 8) {
      return '${raw.substring(6)}/${raw.substring(4, 6)}/${raw.substring(0, 4)}';
    }
    return raw;
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }
}

// ── _QtyTile ──────────────────────────────────────────────────────────────────

class _QtyTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _QtyTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── _SmallChip ────────────────────────────────────────────────────────────────

class _SmallChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SmallChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _InlineError ──────────────────────────────────────────────────────────────

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: Colors.red.shade300),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('ลองใหม่'),
              style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Brother Connect Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _BrotherConnectSheet extends StatefulWidget {
  final BrotherBLEService brotherBLE;
  final void Function(String name) onConnected;

  const _BrotherConnectSheet({required this.brotherBLE, required this.onConnected});

  @override
  State<_BrotherConnectSheet> createState() => _BrotherConnectSheetState();
}

class _BrotherConnectSheetState extends State<_BrotherConnectSheet> {
  late final TextEditingController _macCtrl;
  bool _connecting = false;
  bool _scanning = false;
  bool _loadingBonded = false;
  List<BrotherDevice> _scanned = [];
  List<BluetoothDevice> _bonded = [];
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _macCtrl = TextEditingController(text: widget.brotherBLE.savedDeviceId);
    _loadBonded();
  }

  Future<void> _loadBonded() async {
    setState(() { _loadingBonded = true; });
    try {
      final list = await widget.brotherBLE.getBondedDevices();
      if (mounted) setState(() { _bonded = list; _loadingBonded = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingBonded = false);
    }
  }

  @override
  void dispose() {
    _macCtrl.dispose();
    super.dispose();
  }

  Future<void> _connectByMac() async {
    final mac = _macCtrl.text.trim();
    if (mac.isEmpty) return;
    setState(() { _connecting = true; _errorMsg = null; });
    // Request permissions before connecting
    final perm = await widget.brotherBLE.requestPermissions();
    if (perm != 'granted') {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _errorMsg = perm == 'permanentlyDenied'
            ? 'ถูกปิดถาวร — เปิด Settings → อนุญาต Bluetooth แล้วลองใหม่'
            : '❌ ยังไม่ได้รับอนุญาต Bluetooth';
      });
      return;
    }
    widget.brotherBLE.saveByMac(mac);
    if (!mounted) return;
    Navigator.pop(context);
    widget.onConnected(widget.brotherBLE.savedDeviceName);
  }

  Future<void> _scan() async {
    setState(() { _scanning = true; _scanned = []; _errorMsg = null; });
    // Request permissions before scanning
    final perm = await widget.brotherBLE.requestPermissions();
    if (perm != 'granted') {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _errorMsg = perm == 'permanentlyDenied'
            ? 'ถูกปิดถาวร — เปิด Settings → อนุญาต Bluetooth แล้วลองใหม่'
            : '❌ ยังไม่ได้รับอนุญาต Bluetooth';
      });
      return;
    }
    final devices = await widget.brotherBLE.scanForPrinters();
    if (!mounted) return;
    setState(() { _scanning = false; _scanned = devices; });
    if (devices.isEmpty) {
      setState(() => _errorMsg = 'ไม่พบอุปกรณ์ Brother — ลองกด Power ค้างไว้ที่เครื่องปริ้นแล้วลองใหม่');
    }
  }

  Future<void> _connectDevice(BluetoothDevice d) async {
    setState(() { _connecting = true; _errorMsg = null; });
    widget.brotherBLE.saveBondedDevice(d);
    _macCtrl.text = d.remoteId.str;
    if (!mounted) return;
    setState(() => _connecting = false);
    Navigator.pop(context);
    widget.onConnected(
        d.platformName.isNotEmpty ? d.platformName : d.remoteId.str);
  }

  Future<void> _connectSdkDevice(BrotherDevice d) async {
    setState(() { _connecting = true; _errorMsg = null; });
    widget.brotherBLE.saveDevice(d);
    _macCtrl.text = widget.brotherBLE.savedDeviceId;
    if (!mounted) return;
    setState(() => _connecting = false);
    Navigator.pop(context);
    widget.onConnected(widget.brotherBLE.savedDeviceName);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          // Title
          const Row(
            children: [
              Icon(Icons.label_outline, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Text('Brother PT-P300BT',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          // MAC address input
          const Text('เชื่อมต่อผ่าน MAC Address',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _macCtrl,
                  decoration: InputDecoration(
                    hintText: 'XX:XX:XX:XX:XX:XX',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _connecting ? null : _connectByMac,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: _connecting
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('เชื่อมต่อ'),
              ),
            ],
          ),
          // MAC hint
          const SizedBox(height: 4),
          const Text(
            'ดู MAC ได้ที่ Settings → Connected devices → PT-P300BT5327 → ⚙️',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
          // Bonded devices section
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('อุปกรณ์ที่จับคู่ไว้แล้ว',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ),
              const Expanded(child: Divider()),
              if (_loadingBonded)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: _loadBonded,
                  color: const Color(0xFF7C3AED),
                  tooltip: 'รีเฟรช',
                ),
            ],
          ),
          if (_bonded.isEmpty && !_loadingBonded)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'ไม่พบ — ลอง pair เครื่องปริ้นผ่านแอฟ Brother Design&Print 2 ก่อน แล้วกด 🔄',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          if (_bonded.isNotEmpty)
            ..._bonded.map((d) => ListTile(
              dense: true,
              leading: const Icon(Icons.bluetooth_connected, color: Color(0xFF7C3AED), size: 20),
              title: Text(
                d.platformName.isNotEmpty ? d.platformName : '(ไม่มีชื่อ)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(d.remoteId.str,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              trailing: widget.brotherBLE.savedDeviceId == d.remoteId.str
                  ? const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18)
                  : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              onTap: () {
                _macCtrl.text = d.remoteId.str;
                _connectDevice(d);
              },
            )),
          // Error
          if (_errorMsg != null) ...[
            const SizedBox(height: 8),
            Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          // Scan divider
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('หรือค้นหา BLE',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (_scanning || _connecting) ? null : _scan,
              icon: _scanning
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.bluetooth_searching, size: 18),
              label: Text(_scanning ? 'กำลังค้นหา 8 วินาที…' : 'ค้นหาอุปกรณ์ BLE'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF7C3AED)),
                foregroundColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (_scanned.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._scanned.map((d) => ListTile(
              dense: true,
              leading: const Icon(Icons.bluetooth, color: Color(0xFF7C3AED), size: 20),
              title: Text(
                d.printerName ?? d.modelName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(d.macAddress ?? '',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              trailing: widget.brotherBLE.savedDeviceId == (d.macAddress ?? '')
                  ? const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18)
                  : null,
              onTap: () => _connectSdkDevice(d),
            )),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
