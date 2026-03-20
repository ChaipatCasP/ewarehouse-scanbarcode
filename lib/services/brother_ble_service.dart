import 'dart:io';

import 'package:brother_printer/brother_printer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';

/// Brother PT-P300BT label printer service.
///
/// Uses the official Brother BRLM SDK (via `brother_printer` package) for
/// printing. Device discovery uses:
///   • FlutterBluePlus.bondedDevices  — paired devices in Android (instant)
///   • BrotherPrinter.searchDevices() — native SDK scan (better than raw BLE)
class BrotherBLEService {
  static final BrotherBLEService _instance = BrotherBLEService._();
  factory BrotherBLEService() => _instance;
  BrotherBLEService._();

  String savedDeviceId   = ''; // MAC address e.g. "80:6F:B0:BA:BE:7D"
  String savedDeviceName = '';

  // ── Permissions ───────────────────────────────────────────────────────────

  /// Returns 'granted', 'denied', or 'permanentlyDenied'.
  /// If permanently denied, opens App Settings automatically.
  Future<String> requestPermissions() async {
    final needed = <Permission>[
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ];

    // Android ≤ 11 requires location for BLE scan
    final locStatus = await Permission.locationWhenInUse.status;
    if (!locStatus.isGranted) needed.add(Permission.locationWhenInUse);

    final statuses = await needed.request();
    debugPrint('BrotherBLE permissions response: $statuses');

    // Case 1: any permanently denied → open Settings
    final permanent = statuses.entries
        .where((e) => e.value.isPermanentlyDenied)
        .map((e) => e.key.toString())
        .toList();
    if (permanent.isNotEmpty) {
      debugPrint('BrotherBLE permanently denied: $permanent → opening settings');
      await openAppSettings();
      return 'permanentlyDenied';
    }

    // Case 2: BT permissions must be granted (location optional on Android 12+)
    final btOk =
        statuses[Permission.bluetoothConnect]?.isGranted == true &&
        statuses[Permission.bluetoothScan]?.isGranted == true;
    return btOk ? 'granted' : 'denied';
  }

  // ── Device Discovery ──────────────────────────────────────────────────────

  /// Devices already bonded (paired) in Android — shows instantly, no scan needed.
  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      return await FlutterBluePlus.bondedDevices;
    } catch (e) {
      debugPrint('Brother bondedDevices error: $e');
      return [];
    }
  }

  /// Scan via Brother native SDK — finds PT-P300BT better than raw BLE scan.
  Future<List<BrotherDevice>> scanForPrinters() async {
    try {
      debugPrint('BrotherSDK: searchDevices start...');
      final devices = await BrotherPrinter.searchDevices(delay: 8);
      debugPrint('BrotherSDK: found ${devices.length} device(s)');
      for (final d in devices) {
        debugPrint('  • "${d.printerName}" MAC:${d.macAddress} src:${d.source}');
      }
      return devices;
    } catch (e) {
      debugPrint('BrotherSDK searchDevices error: $e');
      return [];
    }
  }

  // ── Save Device ───────────────────────────────────────────────────────────

  /// Save a device found via SDK scan.
  void saveDevice(BrotherDevice device) {
    savedDeviceId   = device.macAddress ?? '';
    savedDeviceName = device.printerName ?? device.modelName;
  }

  /// Save a bonded BluetoothDevice from Android.
  void saveBondedDevice(BluetoothDevice device) {
    savedDeviceId   = device.remoteId.str;
    savedDeviceName = device.platformName.isNotEmpty
        ? device.platformName
        : device.remoteId.str;
  }

  /// Save MAC entered manually.
  void saveByMac(String mac, {String name = ''}) {
    savedDeviceId   = mac;
    savedDeviceName = name.isNotEmpty
        ? name
        : (savedDeviceName.isNotEmpty ? savedDeviceName : mac);
  }

  // ── Print ─────────────────────────────────────────────────────────────────

  /// Prints BOX NUMBER + weight using the official Brother BRLM SDK.
  Future<bool> printLabel({required String boxNo, required String weight}) async {
    debugPrint('BrotherSDK.printLabel boxNo=$boxNo weight=$weight mac=$savedDeviceId');
    if (savedDeviceId.isEmpty) {
      debugPrint('BrotherSDK: no saved device');
      return false;
    }
    String? pdfPath;
    try {
      pdfPath = await _buildPDF(boxNo, weight);
      debugPrint('BrotherSDK: PDF at $pdfPath');

      final device = BrotherDevice(
        source: BrotherDeviceSource.bluetooth,
        model: BRLMPrinterModelPT_P300BT,
        modelName: 'PT-P300BT',
        macAddress: savedDeviceId,
      );

      await BrotherPrinter.printPDF(
        path: pdfPath,
        device: device,
        labelSize: BrotherLabelSize.PT12mm,
      );
      debugPrint('BrotherSDK: print OK');
      return true;
    } catch (e) {
      debugPrint('BrotherSDK print error: $e');
      return false;
    } finally {
      if (pdfPath != null) {
        try { File(pdfPath).deleteSync(); } catch (_) {}
      }
    }
  }

  // ── PDF Generation ────────────────────────────────────────────────────────

  Future<String> _buildPDF(String boxNo, String weight) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(
        40.0 * PdfPageFormat.mm,
        12.0 * PdfPageFormat.mm,
        marginAll: 1.0 * PdfPageFormat.mm,
      ),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(boxNo,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.Text('$weight Kg.', style: pw.TextStyle(fontSize: 14)),
        ],
      ),
    ));
    final tmpDir = await getTemporaryDirectory();
    final path   = '${tmpDir.path}/brother_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await File(path).writeAsBytes(await doc.save());
    return path;
  }
}
