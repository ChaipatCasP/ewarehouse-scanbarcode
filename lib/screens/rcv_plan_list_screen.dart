import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'pur_product_screen.dart';

class RcvPlanListScreen extends StatefulWidget {
  final ApiService apiService;

  const RcvPlanListScreen({super.key, required this.apiService});

  @override
  State<RcvPlanListScreen> createState() => _RcvPlanListScreenState();
}

class _RcvPlanListScreenState extends State<RcvPlanListScreen> {
  List<RcvPlanDtlItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  // ── Filters ──────────────────────────────────────────────────────────────
  DateTime _selectedDate = DateTime.now();
  String _selectedType = 'PO';
  final _searchController = TextEditingController();

  static const List<String> _types = ['PO', 'PE'];

  // ── Formatted date for API (YYYYMMDD) ────────────────────────────────────
  String get _apiDate => DateFormat('yyyyMMdd').format(_selectedDate);

  // ── Filtered list based on search text ──────────────────────────────────
  List<RcvPlanDtlItem> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((e) {
      return e.fullPoNo.toLowerCase().contains(q) ||
          e.supName.toLowerCase().contains(q) ||
          e.containerNo.toLowerCase().contains(q) ||
          e.keepName.toLowerCase().contains(q);
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
      final result = await widget.apiService.getRcvPlanDtl(
        company: widget.apiService.company,
        user: widget.apiService.username,
        type: _selectedType == 'ALL' ? '' : _selectedType,
        date: _apiDate,
        page: 1,
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'Receive Plan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
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
          // ── Filter bar ────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                // Date picker button
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd MMM yyyy').format(_selectedDate),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Type dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedType,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: AppTheme.primary, size: 18),
                      items: _types
                          .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t,
                                  style: const TextStyle(
                                      color: AppTheme.primary))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedType = v);
                          _load();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Search bar ────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                  hintText: 'ค้นหา PO, Supplier, Container...',
                  hintStyle:
                      TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  prefixIcon:
                      Icon(Icons.search, color: Colors.grey.shade500, size: 20),
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

          // ── Count badge ───────────────────────────────────────────────
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
                    DateFormat('dd/MM/yyyy').format(_selectedDate),
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),

          // ── Content ───────────────────────────────────────────────────
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
                        ? _EmptyView(date: _selectedDate)
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: AppTheme.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) => _RcvPlanCard(
                                item: filtered[i],
                                apiService: widget.apiService,
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _RcvPlanCard extends StatelessWidget {
  final RcvPlanDtlItem item;
  final ApiService apiService;
  const _RcvPlanCard({required this.item, required this.apiService});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PurProductScreen(
            apiService: apiService,
            plan: item,
          ),
        ),
      ),
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
          children: [
            // ── Header strip ──────────────────────────────────────────
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
                  Text(
                    item.fullPoNo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Badge(
                    label: item.transactionType,
                    color: const Color(0xFF2563EB),
                  ),
                  const Spacer(),
                  if (item.isHold)
                    const _Badge(label: 'HOLD', color: Colors.red),
                  _Badge(
                    label: item.isActive ? 'Active' : item.status,
                    color: item.isActive
                        ? const Color(0xFF16A34A)
                        : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      size: 18, color: Colors.grey.shade400),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    icon: Icons.business_outlined,
                    label: 'Supplier',
                    value: item.supName,
                    subValue: item.supCountry.isNotEmpty
                        ? '🌍 ${item.supCountry}'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.thermostat_outlined,
                    label: 'Storage',
                    value: item.keepName,
                    valueColor: _keepColor(item.keepCode),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoRow(
                          icon: Icons.event_outlined,
                          label: 'Delivery',
                          value: _formatDate(item.deliveryDate),
                        ),
                      ),
                      Expanded(
                        child: _InfoRow(
                          icon: Icons.access_time_outlined,
                          label: 'ETA',
                          value: item.eta.isNotEmpty ? item.eta : '-',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoRow(
                          icon: Icons.inventory_2_outlined,
                          label: 'Container',
                          value: item.containerNo.isNotEmpty
                              ? item.containerNo
                              : '-',
                        ),
                      ),
                      Expanded(
                        child: _InfoRow(
                          icon: Icons.flight_takeoff_outlined,
                          label: 'Shipment',
                          value: item.shipmentName1.isNotEmpty
                              ? item.shipmentName1
                              : '-',
                        ),
                      ),
                    ],
                  ),
                  if (item.shipperSupName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.local_shipping_outlined,
                      label: 'Shipper',
                      value: item.shipperSupName,
                    ),
                  ],
                ],
              ),
            ),

            // ── Footer ────────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                border:
                    Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Icon(Icons.low_priority,
                      size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    'Priority ${item.priority}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.format_list_numbered,
                      size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    'SEQ ${item.seq}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const Spacer(),
                  Text(
                    item.wareCode.isNotEmpty && item.wareCode != '-'
                        ? item.wareCode
                        : '',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _keepColor(String keepCode) {
    switch (keepCode) {
      case '1':
        return const Color(0xFF2563EB); // FROZEN → blue
      case '2':
        return const Color(0xFF0891B2); // CHILLED → cyan
      case '3':
        return const Color(0xFF16A34A); // DRY → green
      default:
        return Colors.grey.shade600;
    }
  }

  String _formatDate(String raw) {
    // raw = "20250423" → "23/04/2025"
    if (raw.length == 8) {
      return '${raw.substring(6, 8)}/${raw.substring(4, 6)}/${raw.substring(0, 4)}';
    }
    return raw;
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subValue;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.subValue,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
              Text(
                value.isNotEmpty ? value : '-',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? const Color(0xFF0F172A),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subValue != null)
                Text(
                  subValue!,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

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
            Text(
              'เกิดข้อผิดพลาด',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade400),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
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
  final DateTime date;
  const _EmptyView({required this.date});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'ไม่พบข้อมูล',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500),
            ),
            const SizedBox(height: 6),
            Text(
              'ไม่มีรายการสำหรับวันที่\n${DateFormat('dd MMMM yyyy').format(date)}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}

