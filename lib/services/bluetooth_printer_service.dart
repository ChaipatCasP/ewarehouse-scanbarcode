import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Singleton service — Bluetooth thermal label printer (ESC/POS)
class BtPrinterService {
  static final BtPrinterService _instance = BtPrinterService._();
  factory BtPrinterService() => _instance;
  BtPrinterService._();

  BluetoothInfo? selectedPrinter;

  Future<bool> get isBluetoothEnabled => PrintBluetoothThermal.bluetoothEnabled;
  Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  Future<List<BluetoothInfo>> getPairedDevices() async {
    try {
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (e) {
      debugPrint('BtPrinterService.getPairedDevices: $e');
      return [];
    }
  }

  Future<bool> connect(BluetoothInfo device) async {
    selectedPrinter = device;
    final ok = await PrintBluetoothThermal.connect(
        macPrinterAddress: device.macAdress);
    debugPrint('BtPrinter connect ${device.name} → $ok');
    return ok;
  }

  Future<void> disconnect() async {
    selectedPrinter = null;
  }

  /// Print sticker label matching the PDF layout:
  ///
  ///  +-----------+------------------+
  ///  |           |  poNo            |
  ///  |  QR Code  |  supBarcode      |
  ///  |           |  Exp: expDate    |
  ///  +----boxNo--+----weight Kg.----+
  Future<bool> printStickerLabel({
    required String newBarcode,
    required String poNo,
    required String supBarcode,
    required String expDate,
    required String boxNo,
    required String weight,
  }) async {
    final connected = await PrintBluetoothThermal.connectionStatus;
    if (!connected) {
      debugPrint('BtPrinterService: not connected');
      return false;
    }
    try {
      final bytes = _buildESCPOS(
        newBarcode: newBarcode,
        poNo: poNo,
        supBarcode: supBarcode,
        expDate: expDate,
        boxNo: boxNo,
        weight: weight,
      );
      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      debugPrint('BtPrinterService.printStickerLabel error: $e');
      return false;
    }
  }

  // ── ESC/POS byte builder ──────────────────────────────────────────────────

  List<int> _buildESCPOS({
    required String newBarcode,
    required String poNo,
    required String supBarcode,
    required String expDate,
    required String boxNo,
    required String weight,
  }) {
    final List<int> bytes = [];

    // ESC @ — initialize
    bytes.addAll([0x1B, 0x40]);

    // Center align
    bytes.addAll([0x1B, 0x61, 0x01]);

    // QR Code (native ESC/POS)
    if (newBarcode.isNotEmpty) {
      _addQRCode(bytes, newBarcode, size: 8);
      bytes.add(0x0A); // line feed
    }

    // Left align
    bytes.addAll([0x1B, 0x61, 0x00]);

    // Bold on
    bytes.addAll([0x1B, 0x45, 0x01]);

    // PO No
    bytes.addAll(utf8.encode('${poNo.isNotEmpty ? poNo : '-'}\n'));

    // Supplier barcode
    bytes.addAll(utf8.encode(
        '${supBarcode.isNotEmpty ? supBarcode : '-'}\n'));

    // Exp date
    bytes.addAll(utf8.encode(
        'Exp: ${expDate.isNotEmpty ? expDate : '-'}\n'));

    // Divider
    bytes.addAll(utf8.encode('--------------------------------\n'));

    // Double height + width
    bytes.addAll([0x1B, 0x21, 0x30]);

    final displayBox = boxNo.isNotEmpty ? boxNo : '-';
    final displayWeight = weight.isNotEmpty ? weight : '-';
    bytes.addAll(utf8.encode('$displayBox   $displayWeight Kg.\n'));

    // Reset text size
    bytes.addAll([0x1B, 0x21, 0x00]);

    // Bold off
    bytes.addAll([0x1B, 0x45, 0x00]);

    // Feed 3 lines
    bytes.addAll([0x0A, 0x0A, 0x0A]);

    // Full cut
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);

    return bytes;
  }

  /// ESC/POS native QR code command (model 2)
  void _addQRCode(List<int> bytes, String data, {int size = 6}) {
    final dataBytes = utf8.encode(data);

    // QR model 2
    bytes.addAll([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);
    // QR size (cell size 1–16)
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, size]);
    // Error correction level H (48=L 49=M 50=Q 51=H)
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);
    // Store data
    final n = dataBytes.length + 3;
    bytes.addAll([
      0x1D, 0x28, 0x6B, n % 256, n ~/ 256, 0x31, 0x50, 0x30,
    ]);
    bytes.addAll(dataBytes);
    // Print QR
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);
  }
}
