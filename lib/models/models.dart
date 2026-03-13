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
