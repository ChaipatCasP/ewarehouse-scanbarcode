class PurchaseOrder {
  final String poNumber;
  final String supplier;
  final String storageType;
  final String temperature;
  final String status;
  final String? imageUrl;

  PurchaseOrder({
    required this.poNumber,
    required this.supplier,
    required this.storageType,
    required this.temperature,
    required this.status,
    this.imageUrl,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      poNumber: json['poNumber'] as String? ?? '',
      supplier: json['supplier'] as String? ?? '',
      storageType: json['storageType'] as String? ?? '',
      temperature: json['temperature'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

class POItem {
  final String name;
  final String sku;
  final String unit;
  final double ordered;
  final double received;
  final double pending;

  POItem({
    required this.name,
    required this.sku,
    required this.unit,
    required this.ordered,
    required this.received,
    required this.pending,
  });

  factory POItem.fromJson(Map<String, dynamic> json) {
    return POItem(
      name: json['name'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      ordered: (json['ordered'] as num?)?.toDouble() ?? 0,
      received: (json['received'] as num?)?.toDouble() ?? 0,
      pending: (json['pending'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PODetail {
  final String poNumber;
  final String vendor;
  final String orderDate;
  final int totalItems;
  final String totalWeight;
  final String status;
  final List<POItem> items;

  PODetail({
    required this.poNumber,
    required this.vendor,
    required this.orderDate,
    required this.totalItems,
    required this.totalWeight,
    required this.status,
    required this.items,
  });

  factory PODetail.fromJson(Map<String, dynamic> json) {
    return PODetail(
      poNumber: json['poNumber'] as String? ?? '',
      vendor: json['vendor'] as String? ?? '',
      orderDate: json['orderDate'] as String? ?? '',
      totalItems: json['totalItems'] as int? ?? 0,
      totalWeight: json['totalWeight'] as String? ?? '',
      status: json['status'] as String? ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => POItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class QRCodeData {
  final String qrContent;
  final String boxNumber;
  final String packDate;
  final String expDate;
  final double weight;

  QRCodeData({
    required this.qrContent,
    required this.boxNumber,
    required this.packDate,
    required this.expDate,
    required this.weight,
  });

  factory QRCodeData.fromJson(Map<String, dynamic> json) {
    return QRCodeData(
      qrContent: json['qrContent'] as String? ?? '',
      boxNumber: json['boxNumber'] as String? ?? '',
      packDate: json['packDate'] as String? ?? '',
      expDate: json['expDate'] as String? ?? '',
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// ── GetRcvPlanDtl ──────────────────────────────────────────────────────────

class RcvPlanDtlItem {
  // ── Identity ──────────────────────────────────────────────────────────────
  final String company;           // COMPANY       e.g. "JB"
  final String transactionType;   // TRANSACTION_TYPE e.g. "PE"
  final String poBookNo;          // PO_BOOK_NO    e.g. "PE68"
  final String poNo;              // PO_NO         e.g. "1407"
  final String status;            // STATUS        "Y" = active

  // ── Supplier ──────────────────────────────────────────────────────────────
  final String supCode;           // SUP_CODE
  final String supName;           // SUP_NAME
  final String supCountry;        // SUP_COUNTRY

  // ── Shipper ───────────────────────────────────────────────────────────────
  final String shipperSupCode;    // SHIPPER_SUP_CODE
  final String shipperSupName;    // SHIPPER_SUP_NAME

  // ── Schedule ──────────────────────────────────────────────────────────────
  final String eta;               // ETA           e.g. "16:00"
  final String deliveryDate;      // DELIVERY_DATE e.g. "20250423"
  final String whArrival;         // WH_ARRIVAL    e.g. "20250423 00:00"
  final String vEta;              // V_ETA         e.g. "20250423 06:30"

  // ── Shipment / Container ──────────────────────────────────────────────────
  final String shipmentName1;     // SHIPMENT_NAME1 e.g. "AIR"
  final String containerNo;       // CONTAINER_NO
  final String containerSize;     // CONTAINER_SIZE
  final String newContainerNo;    // NEW_CONTAINER_NO
  final String cntContainer;      // CNT_CONTAINER
  final String cntPo;             // CNT_PO

  // ── Storage ───────────────────────────────────────────────────────────────
  final String keepCode;          // KEEP_CODE
  final String keepName;          // KEEP_NAME     e.g. "FROZEN (-18C)"
  final String wareCode;          // WARE_CODE
  final String wareName;          // WARE_NAME

  // ── Priority / Queue ──────────────────────────────────────────────────────
  final String priority;          // PRIORITY
  final String cntPriority1;      // CNT_PRIORITY_1
  final String seq;               // SEQ

  // ── Flags ─────────────────────────────────────────────────────────────────
  final String hold;              // HOLD          "Y"/"N"
  final String productMeat;       // PRODUCT_MEAT  "Y"/"N"
  final String waitRevise;        // WAIT_REVISE   "Y"/"N"
  final String whCloseStatus;     // WH_CLOSE_STATUS "Y"/"N"
  final String q1Status;          // Q1_STATUS

  // ── Temperature ───────────────────────────────────────────────────────────
  final String tempBeforeLoad;    // TEMP_BEFORE_LOAD
  final String tempAfterLoad;     // TEMP_AFTER_LOAD

  // ── Inspection / Clearance ────────────────────────────────────────────────
  final String clear;             // CLEAR
  final String clearRemark;       // CLEAR_REMARK
  final String damaged;           // DAMAGED
  final String damagedRemark;     // DAMAGED_REMARK

  // ── Transport ─────────────────────────────────────────────────────────────
  final String truck;             // TRUCK
  final String motorSticker;      // MOTOR_STICKER
  final String vehicleRegSeal;    // VEHICLE_REG_SEAL

  // ── Reference ─────────────────────────────────────────────────────────────
  final String refType;           // REF_TYPE
  final String refBook;           // REF_BOOK
  final String refNo;             // REF_NO

  // ── QT ────────────────────────────────────────────────────────────────────
  final String qtStatus;          // QT_STATUS
  final String qtType;            // QT_TYPE
  final String qtBook;            // QT_BOOK
  final String qtNo;              // QT_NO
  final String qtRid;             // QT_RID

  // ── WMS ───────────────────────────────────────────────────────────────────
  final String wmsSeqId;          // WMS_SEQ_ID
  final String wmsAsnSeqId;       // WMS_ASN_SEQ_ID

  /// Raw JSON จาก API (ครบทุก field)
  final Map<String, dynamic> raw;

  RcvPlanDtlItem({
    required this.company,
    required this.transactionType,
    required this.poBookNo,
    required this.poNo,
    required this.status,
    required this.supCode,
    required this.supName,
    required this.supCountry,
    required this.shipperSupCode,
    required this.shipperSupName,
    required this.eta,
    required this.deliveryDate,
    required this.whArrival,
    required this.vEta,
    required this.shipmentName1,
    required this.containerNo,
    required this.containerSize,
    required this.newContainerNo,
    required this.cntContainer,
    required this.cntPo,
    required this.keepCode,
    required this.keepName,
    required this.wareCode,
    required this.wareName,
    required this.priority,
    required this.cntPriority1,
    required this.seq,
    required this.hold,
    required this.productMeat,
    required this.waitRevise,
    required this.whCloseStatus,
    required this.q1Status,
    required this.tempBeforeLoad,
    required this.tempAfterLoad,
    required this.clear,
    required this.clearRemark,
    required this.damaged,
    required this.damagedRemark,
    required this.truck,
    required this.motorSticker,
    required this.vehicleRegSeal,
    required this.refType,
    required this.refBook,
    required this.refNo,
    required this.qtStatus,
    required this.qtType,
    required this.qtBook,
    required this.qtNo,
    required this.qtRid,
    required this.wmsSeqId,
    required this.wmsAsnSeqId,
    required this.raw,
  });

  static String _s(Map<String, dynamic> j, String key) =>
      j[key] as String? ?? '';

  factory RcvPlanDtlItem.fromJson(Map<String, dynamic> json) {
    return RcvPlanDtlItem(
      company:          _s(json, 'COMPANY'),
      transactionType:  _s(json, 'TRANSACTION_TYPE'),
      poBookNo:         _s(json, 'PO_BOOK_NO'),
      poNo:             _s(json, 'PO_NO'),
      status:           _s(json, 'STATUS'),
      supCode:          _s(json, 'SUP_CODE'),
      supName:          _s(json, 'SUP_NAME'),
      supCountry:       _s(json, 'SUP_COUNTRY'),
      shipperSupCode:   _s(json, 'SHIPPER_SUP_CODE'),
      shipperSupName:   _s(json, 'SHIPPER_SUP_NAME'),
      eta:              _s(json, 'ETA'),
      deliveryDate:     _s(json, 'DELIVERY_DATE'),
      whArrival:        _s(json, 'WH_ARRIVAL'),
      vEta:             _s(json, 'V_ETA'),
      shipmentName1:    _s(json, 'SHIPMENT_NAME1'),
      containerNo:      _s(json, 'CONTAINER_NO'),
      containerSize:    _s(json, 'CONTAINER_SIZE'),
      newContainerNo:   _s(json, 'NEW_CONTAINER_NO'),
      cntContainer:     _s(json, 'CNT_CONTAINER'),
      cntPo:            _s(json, 'CNT_PO'),
      keepCode:         _s(json, 'KEEP_CODE'),
      keepName:         _s(json, 'KEEP_NAME'),
      wareCode:         _s(json, 'WARE_CODE'),
      wareName:         _s(json, 'WARE_NAME'),
      priority:         _s(json, 'PRIORITY'),
      cntPriority1:     _s(json, 'CNT_PRIORITY_1'),
      seq:              _s(json, 'SEQ'),
      hold:             _s(json, 'HOLD'),
      productMeat:      _s(json, 'PRODUCT_MEAT'),
      waitRevise:       _s(json, 'WAIT_REVISE'),
      whCloseStatus:    _s(json, 'WH_CLOSE_STATUS'),
      q1Status:         _s(json, 'Q1_STATUS'),
      tempBeforeLoad:   _s(json, 'TEMP_BEFORE_LOAD'),
      tempAfterLoad:    _s(json, 'TEMP_AFTER_LOAD'),
      clear:            _s(json, 'CLEAR'),
      clearRemark:      _s(json, 'CLEAR_REMARK'),
      damaged:          _s(json, 'DAMAGED'),
      damagedRemark:    _s(json, 'DAMAGED_REMARK'),
      truck:            _s(json, 'TRUCK'),
      motorSticker:     _s(json, 'MOTOR_STICKER'),
      vehicleRegSeal:   _s(json, 'VEHICLE_REG_SEAL'),
      refType:          _s(json, 'REF_TYPE'),
      refBook:          _s(json, 'REF_BOOK'),
      refNo:            _s(json, 'REF_NO'),
      qtStatus:         _s(json, 'QT_STATUS'),
      qtType:           _s(json, 'QT_TYPE'),
      qtBook:           _s(json, 'QT_BOOK'),
      qtNo:             _s(json, 'QT_NO'),
      qtRid:            _s(json, 'QT_RID'),
      wmsSeqId:         _s(json, 'WMS_SEQ_ID'),
      wmsAsnSeqId:      _s(json, 'WMS_ASN_SEQ_ID'),
      raw:              json,
    );
  }

  /// PO เลขเต็ม เช่น "PE68/1407"
  String get fullPoNo => poBookNo.isNotEmpty ? '$poBookNo/$poNo' : poNo;

  /// true ถ้า STATUS == "Y"
  bool get isActive => status == 'Y';

  /// true ถ้า HOLD == "Y"
  bool get isHold => hold == 'Y';

  Map<String, dynamic> toJson() => raw;
}

class RcvPlanDtlResult {
  final int records;          // records จาก API (จำนวน row ที่ได้)
  final int currentPage;
  final List<RcvPlanDtlItem> items;

  RcvPlanDtlResult({
    required this.records,
    required this.currentPage,
    required this.items,
  });

  factory RcvPlanDtlResult.fromJson(Map<String, dynamic> json, int page) {
    final rawItems = json['result'] as List<dynamic>? ?? [];
    return RcvPlanDtlResult(
      records:     (json['records'] as num?)?.toInt() ?? rawItems.length,
      currentPage: page,
      items:       rawItems
          .map((e) => RcvPlanDtlItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
