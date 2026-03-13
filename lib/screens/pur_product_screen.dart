import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class PurProductScreen extends StatefulWidget {
  final ApiService apiService;
  final RcvPlanDtlItem plan; // PO ที่เลือกมาจากหน้า Receive Plan

  const PurProductScreen({
    super.key,
    required this.apiService,
    required this.plan,
  });

  @override
  State<PurProductScreen> createState() => _PurProductScreenState();
}

class _PurProductScreenState extends State<PurProductScreen> {
  List<PurProductItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  final _searchController = TextEditingController();

  List<PurProductItem> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((e) {
      return e.matCode.toLowerCase().contains(q) ||
          e.matDesc.toLowerCase().contains(q) ||
          e.barcode.toLowerCase().contains(q) ||
          e.brand.toLowerCase().contains(q);
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
      final result = await widget.apiService.getPurProduct(
        company:  widget.apiService.company,
        user:     widget.apiService.username,
        type:     widget.plan.transactionType,
        poBookNo: widget.plan.poBookNo,
        poNo:     widget.plan.poNo,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
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
          plan.fullPoNo,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
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
          // ── PO Summary Banner ─────────────────────────────────────────
          _PlanSummaryBanner(plan: plan),
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
                  hintText: 'ค้นหา รหัสสินค้า, ชื่อ, Barcode...',
                  hintStyle: TextStyle(
                      color: Colors.grey.shade500, fontSize: 13),
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
                      color: AppTheme.primary,
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
                    plan.keepName,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
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
                        color: AppTheme.primary))
                : _errorMessage != null
                    ? _ErrorView(
                        message: _errorMessage!,
                        onRetry: _load,
                      )
                    : filtered.isEmpty
                        ? _EmptyView(poNo: plan.fullPoNo)
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: AppTheme.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) =>
                                  _ProductCard(
                                item: filtered[i],
                                index: i + 1,
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ── PO Summary Banner ─────────────────────────────────────────────────────────

class _PlanSummaryBanner extends StatelessWidget {
  final RcvPlanDtlItem plan;
  const _PlanSummaryBanner({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Supplier
          Row(
            children: [
              const Icon(Icons.business_outlined,
                  size: 15, color: AppTheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  plan.supName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (plan.supCountry.isNotEmpty)
                Text(
                  '🌍 ${plan.supCountry}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Info chips row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Chip(
                icon: Icons.thermostat_outlined,
                label: plan.keepName,
                color: _keepColor(plan.keepCode),
              ),
              _Chip(
                icon: Icons.event_outlined,
                label: _fmtDate(plan.deliveryDate),
                color: Colors.grey.shade600,
              ),
              if (plan.shipmentName1.isNotEmpty)
                _Chip(
                  icon: Icons.flight_takeoff_outlined,
                  label: plan.shipmentName1,
                  color: Colors.grey.shade600,
                ),
              if (plan.containerNo.isNotEmpty)
                _Chip(
                  icon: Icons.inventory_2_outlined,
                  label: plan.containerNo,
                  color: Colors.grey.shade600,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _keepColor(String code) {
    switch (code) {
      case '1': return const Color(0xFF2563EB);
      case '2': return const Color(0xFF0891B2);
      case '3': return const Color(0xFF16A34A);
      default:  return Colors.grey.shade600;
    }
  }

  String _fmtDate(String raw) {
    if (raw.length == 8) {
      return '${raw.substring(6)}/${raw.substring(4, 6)}/${raw.substring(0, 4)}';
    }
    return raw;
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

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

// ── Product Card ──────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final PurProductItem item;
  final int index;
  const _ProductCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final pctReceived = item.poQty > 0
        ? (item.rcvQty / item.poQty).clamp(0.0, 1.0)
        : 0.0;

    return Container(
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
          // ── Header ─────────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.05),
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
                  decoration: BoxDecoration(
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
                const SizedBox(width: 8),
                // MAT_CODE
                Expanded(
                  child: Text(
                    item.matCode.isNotEmpty ? item.matCode : '-',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                // Line badge
                if (item.poLine.isNotEmpty)
                  _LineBadge('Line ${item.poLine}'),
              ],
            ),
          ),

          // ── Body ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product name
                Text(
                  item.matDesc.isNotEmpty ? item.matDesc : '-',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (item.matDesc2.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.matDesc2,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ),
                const SizedBox(height: 10),

                // Qty row
                Row(
                  children: [
                    _QtyBox(
                      label: 'PO Qty',
                      value:
                          '${_fmt(item.poQty)} ${item.uom}',
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    _QtyBox(
                      label: 'Received',
                      value:
                          '${_fmt(item.rcvQty)} ${item.uom}',
                      color: const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 8),
                    _QtyBox(
                      label: 'Pending',
                      value:
                          '${_fmt(item.remainQty)} ${item.uom}',
                      color: item.remainQty > 0
                          ? const Color(0xFFD97706)
                          : Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'รับแล้ว ${(pctReceived * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                        Text(
                          '${_fmt(item.rcvQty)} / ${_fmt(item.poQty)}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pctReceived,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          pctReceived >= 1.0
                              ? const Color(0xFF16A34A)
                              : AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                // Optional fields
                if (item.barcode.isNotEmpty ||
                    item.brand.isNotEmpty ||
                    item.lotNo.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (item.barcode.isNotEmpty)
                        _InfoChip(
                            icon: Icons.qr_code,
                            label: item.barcode),
                      if (item.brand.isNotEmpty)
                        _InfoChip(
                            icon: Icons.label_outline,
                            label: item.brand),
                      if (item.lotNo.isNotEmpty)
                        _InfoChip(
                            icon: Icons.tag,
                            label: 'Lot: ${item.lotNo}'),
                      if (item.expDate.isNotEmpty)
                        _InfoChip(
                            icon: Icons.hourglass_bottom_outlined,
                            label: 'EXP: ${item.expDate}'),
                    ],
                  ),
                ],

                // Price (ถ้ามี)
                if (item.unitPrice > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.attach_money,
                          size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        '${_fmt(item.unitPrice)} ${item.currency} / ${item.uom}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      if (item.amount > 0) ...[
                        Text(
                          '  •  รวม ${_fmt(item.amount)} ${item.currency}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Footer status ──────────────────────────────────────────
          if (item.status.isNotEmpty || item.remark.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  if (item.status.isNotEmpty) ...[
                    Icon(Icons.circle,
                        size: 8,
                        color: item.status == 'Y'
                            ? const Color(0xFF16A34A)
                            : Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      item.status == 'Y' ? 'Active' : item.status,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                  if (item.remark.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.remark,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) {
      return v.toInt().toString();
    }
    return v.toStringAsFixed(2);
  }
}

// ── Reusable small widgets ────────────────────────────────────────────────────

class _LineBadge extends StatelessWidget {
  final String label;
  const _LineBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppTheme.primary,
        ),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// ── Error / Empty views ───────────────────────────────────────────────────────

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
            Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('เกิดข้อผิดพลาด',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade400)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('ลองใหม่'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
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
  final String poNo;
  const _EmptyView({required this.poNo});

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
            Text('PO $poNo ไม่มีรายการสินค้าในระบบ',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }
}

