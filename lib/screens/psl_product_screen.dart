import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'scan_qr_screen.dart';

class PslProductScreen extends StatefulWidget {
  final ApiService apiService;
  final LstDocInboundItem psl; // PSL card ที่เลือกมาจากหน้า Receive Plan

  const PslProductScreen({
    super.key,
    required this.apiService,
    required this.psl,
  });

  @override
  State<PslProductScreen> createState() => _PslProductScreenState();
}

class _PslProductScreenState extends State<PslProductScreen> {
  List<LstDocInbDtlItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  final _searchController = TextEditingController();

  List<LstDocInbDtlItem> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((e) {
      return e.productCode.toLowerCase().contains(q) ||
          e.productName.toLowerCase().contains(q) ||
          e.reprocessCode.toLowerCase().contains(q) ||
          e.reprocessName.toLowerCase().contains(q) ||
          e.serviceName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await widget.apiService.getLstDocInbDtl(
        company:  widget.apiService.company,
        user:     widget.apiService.username,
        dType:    widget.psl.transactionType, // e.g. "RO"
        dBook:    widget.psl.rpBookNo,        // e.g. "RO69"
        dNo:      widget.psl.rpNo,            // e.g. "226"
      );
      if (!mounted) return;
      setState(() {
        _items = result;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = e.message; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final psl = widget.psl;
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          psl.fullPslNo,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF7C3AED),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primary),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── PSL Summary Banner ────────────────────────────────────────
          _PslSummaryBanner(psl: psl),
          const Divider(height: 1),

          // ── Search bar ────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'ค้นหา รหัสสินค้า, ชื่อ, Service...',
                  hintStyle:
                      TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  prefixIcon: Icon(Icons.search,
                      color: Colors.grey.shade500, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              size: 18, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const Divider(height: 1),

          // ── Count bar ─────────────────────────────────────────────────
          if (!_isLoading && _errorMessage == null)
            Container(
              color: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${filtered.length} รายการ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    psl.supName,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          const Divider(height: 1),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF7C3AED)))
                : _errorMessage != null
                    ? _ErrorView(
                        message: _errorMessage!,
                        onRetry: _load,
                      )
                    : filtered.isEmpty
                        ? _EmptyView(pslNo: psl.fullPslNo)
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: const Color(0xFF7C3AED),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) => _PslProductCard(
                                item: filtered[i],
                                index: i + 1,
                                apiService: widget.apiService,
                                psl: widget.psl,
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ── PSL Summary Banner ────────────────────────────────────────────────────────

class _PslSummaryBanner extends StatelessWidget {
  final LstDocInboundItem psl;
  const _PslSummaryBanner({required this.psl});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Supplier row
          Row(
            children: [
              const Icon(Icons.business_outlined,
                  size: 15, color: Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  psl.supName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Info chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Chip(
                icon: Icons.receipt_long_outlined,
                label: 'RP: ${psl.fullRpNo}',
                color: const Color(0xFF7C3AED),
              ),
              _Chip(
                icon: Icons.event_outlined,
                label: LstDocInboundItem.fmtDate(psl.docDate),
                color: Colors.grey.shade600,
              ),
              _Chip(
                icon: Icons.warehouse_outlined,
                label: 'WH: ${LstDocInboundItem.fmtDate(psl.whRecDate)}',
                color: Colors.grey.shade600,
              ),
              _Chip(
                icon: Icons.category_outlined,
                label: psl.transactionType,
                color: const Color(0xFF7C3AED),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(
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

// ── PSL Product Card ──────────────────────────────────────────────────────────

class _PslProductCard extends StatelessWidget {
  final LstDocInbDtlItem item;
  final int index;
  final ApiService apiService;
  final LstDocInboundItem psl;
  const _PslProductCard({required this.item, required this.index, required this.apiService, required this.psl});

  static const Color _purple = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // ── Map LstDocInbDtlItem → PurProductItem ───────────────────
        // PurProductItem.fromJson รองรับ PRODUCT_CODE → matCode, SEQ → poLine ฯลฯ
        final purItem = PurProductItem.fromJson({
          'COMPANY':          item.company,
          'TRANSACTION_TYPE': item.transactionType,
          'PO_BOOK_NO':       item.rpBookNo,
          'PO_NO':            item.rpNo,
          'SEQ':              item.seq,        // maps to poLine
          'PRODUCT_CODE':     item.productCode, // maps to matCode
          'PRODUCT_NAME':     item.productName, // maps to matDesc
          'PO_QTY':           item.qtyAvl,     // maps to poQty
          'UNIT':             item.unit,        // maps to uom
          'STATUS':           'Y',
        });

        // ── Map LstDocInboundItem → RcvPlanDtlItem ───────────────────
        final planItem = RcvPlanDtlItem.fromJson({
          'COMPANY':          psl.company,
          'TRANSACTION_TYPE': psl.transactionType,
          'PO_BOOK_NO':       psl.rpBookNo,
          'PO_NO':            psl.rpNo,
          'STATUS':           'Y',
          'SUP_CODE':         psl.supCode,
          'SUP_NAME':         psl.supName,
          'SUP_COUNTRY':      '',
          'SHIPPER_SUP_CODE': '',
          'SHIPPER_SUP_NAME': '',
          'ETA':              '',
          'DELIVERY_DATE':    psl.whRecDate,
          'WH_ARRIVAL':       '',
          'V_ETA':            '',
          'SHIPMENT_NAME1':   '',
          'CONTAINER_NO':     '',
          'CONTAINER_SIZE':   '',
          'NEW_CONTAINER_NO': '',
          'CNT_CONTAINER':    '',
          'CNT_PO':           '',
          'KEEP_CODE':        '',
          'KEEP_NAME':        '',
          'WARE_CODE':        '',
          'WARE_NAME':        '',
          'PRIORITY':         '',
          'CNT_PRIORITY_1':   '',
          'SEQ':              '',
          'HOLD':             'N',
          'PRODUCT_MEAT':     'N',
          'WAIT_REVISE':      'N',
          'WH_CLOSE_STATUS':  'N',
          'Q1_STATUS':        '',
          'TEMP_BEFORE_LOAD': '',
          'TEMP_AFTER_LOAD':  '',
          'CLEAR':            '',
          'CLEAR_REMARK':     '',
          'DAMAGED':          '',
          'DAMAGED_REMARK':   '',
          'TRUCK':            '',
          'MOTOR_STICKER':    '',
          'VEHICLE_REG_SEAL': '',
          'REF_TYPE':         '',
          'REF_BOOK':         psl.rpBookNo,
          'REF_NO':           psl.rpNo,
          'QT_STATUS':        '',
          'QT_TYPE':          '',
          'QT_BOOK':          '',
          'QT_NO':            '',
          'QT_RID':           '',
          'WMS_SEQ_ID':       '',
          'WMS_ASN_SEQ_ID':   '',
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScanQRScreen(
              apiService: apiService,
              item: purItem,
              plan: planItem,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.05),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                border: const Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  // Index circle
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: _purple,
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.productCode,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _purple,
                      ),
                    ),
                  ),
                  // SEQ badge
                  _SeqBadge(item.seqLabel),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Source product ─────────────────────────────────
                  _SectionLabel(
                      icon: Icons.inventory_2_outlined,
                      label: 'Source Product',
                      color: _purple),
                  const SizedBox(height: 4),
                  Text(
                    item.productName.isNotEmpty ? item.productName : '-',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Reprocess / Output product ─────────────────────
                  _SectionLabel(
                      icon: Icons.loop_outlined,
                      label: 'Output Product',
                      color: const Color(0xFF0891B2)),
                  const SizedBox(height: 4),
                  Text(
                    item.reprocessCode.isNotEmpty
                        ? item.reprocessCode
                        : '-',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0891B2),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.reprocessName.isNotEmpty
                        ? item.reprocessName
                        : '-',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Service ───────────────────────────────────────
                  _SectionLabel(
                      icon: Icons.build_circle_outlined,
                      label: 'Service',
                      color: const Color(0xFFF59E0B)),
                  const SizedBox(height: 4),
                  Text(
                    item.serviceName.isNotEmpty ? item.serviceName : '-',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Qty boxes ─────────────────────────────────────
                  Row(
                    children: [
                      _QtyBox(
                        label: 'Qty Available',
                        value:
                            '${item.qtyAvl.isNotEmpty ? item.qtyAvl : "-"} ${item.unit}',
                        color: const Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 8),
                      _QtyBox(
                        label: 'Qty',
                        value:
                            '${item.qty.isNotEmpty ? item.qty : "-"} ${item.unit}',
                        color: AppTheme.primary,
                      ),
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
}

// ── Reusable small widgets ────────────────────────────────────────────────────

class _SeqBadge extends StatelessWidget {
  final String label;
  const _SeqBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'SEQ $label',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF7C3AED),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionLabel(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
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
    );
  }
}

class _QtyBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _QtyBox(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade500)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
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

// ── Error / Empty ─────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 56, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('เกิดข้อผิดพลาด',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade400)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('ลองใหม่'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                minimumSize: const Size(140, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String pslNo;
  const _EmptyView({required this.pslNo});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('ไม่พบรายการสินค้า',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500)),
            const SizedBox(height: 6),
            Text('PSL $pslNo ไม่มีรายการสินค้าในระบบ',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }
}




