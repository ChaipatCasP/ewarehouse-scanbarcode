import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'po_list_screen.dart';
import 'scan_qr_screen.dart';
import 'login_screen.dart';
import 'rcv_plan_list_screen.dart';

class DashboardScreen extends StatelessWidget {
  final ApiService apiService;

  const DashboardScreen({super.key, required this.apiService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.warehouse_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'JAGOTA',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_outlined,
                        color: Colors.grey),
                  ),
                  PopupMenuButton<String>(
                    offset: const Offset(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xFFE8EDF2),
                      child: Icon(Icons.account_circle,
                          color: AppTheme.primary, size: 30),
                    ),
                    onSelected: (value) {
                      if (value == 'logout') {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Row(
                              children: [
                                Icon(Icons.logout, color: Colors.redAccent),
                                SizedBox(width: 8),
                                Text('Logout'),
                              ],
                            ),
                            content:
                                const Text('Are you sure you want to logout?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                        builder: (_) => const LoginScreen()),
                                    (route) => false,
                                  );
                                },
                                child: const Text('Logout'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(Icons.person_outline, size: 20),
                            SizedBox(width: 10),
                            Text('Profile'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, size: 20, color: Colors.redAccent),
                            SizedBox(width: 10),
                            Text('Logout',
                                style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inbound Tasks',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your incoming shipments and logistics',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Task Grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                      children: [
                        // _TaskCard(
                        //   icon: Icons.public,
                        //   iconBgColor: const Color(0xFFEFF6FF),
                        //   iconColor: const Color(0xFF2563EB),
                        //   title: 'Receive International',
                        //   badge: '35',
                        //   onTap: () => Navigator.push(
                        //     context,
                        //     MaterialPageRoute(
                        //       builder: (_) => POListScreen(
                        //         apiService: apiService,
                        //         title: 'Receive International',
                        //       ),
                        //     ),
                        //   ),
                        // ),
                        // _TaskCard(
                        //   icon: Icons.local_shipping,
                        //   iconBgColor: const Color(0xFFF0FDF4),
                        //   iconColor: const Color(0xFF16A34A),
                        //   title: 'Receive Domestic',
                        //   badge: '61',
                        //   onTap: () => Navigator.push(
                        //     context,
                        //     MaterialPageRoute(
                        //       builder: (_) => POListScreen(
                        //         apiService: apiService,
                        //         title: 'Receive Domestic',
                        //       ),
                        //     ),
                        //   ),
                        // ),
                        // _TaskCard(
                        //   icon: Icons.cloud_upload,
                        //   iconBgColor: const Color(0xFFFAF5FF),
                        //   iconColor: const Color(0xFF9333EA),
                        //   title: 'EDI inbound LPN upload',
                        //   onTap: () {},
                        // ),
                        _TaskCard(
                          icon: Icons.qr_code_2,
                          iconBgColor: Colors.white.withValues(alpha: 0.2),
                          iconColor: Colors.white,
                          title: 'Gen QR Code',
                          isHighlighted: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RcvPlanListScreen(apiService: apiService),
                            ),
                          ),
                        ),
                        // _TaskCard(
                        //   icon: Icons.verified_user,
                        //   iconBgColor: const Color(0xFFFFFBEB),
                        //   iconColor: const Color(0xFFD97706),
                        //   title: 'Receive Approval',
                        //   onTap: () {},
                        // ),
                        // _TaskCard(
                        //   icon: Icons.bar_chart,
                        //   iconBgColor: const Color(0xFFF1F5F9),
                        //   iconColor: const Color(0xFF475569),
                        //   title: 'View Q1',
                        //   onTap: () {},
                        // ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Tip Card
                    // Container(
                    //   padding: const EdgeInsets.all(16),
                    //   decoration: BoxDecoration(
                    //     color: AppTheme.primary.withValues(alpha: 0.05),
                    //     borderRadius: BorderRadius.circular(12),
                    //     border: Border.all(
                    //       color: AppTheme.primary.withValues(alpha: 0.1),
                    //     ),
                    //   ),
                    //   child: Column(
                    //     crossAxisAlignment: CrossAxisAlignment.start,
                    //     children: [
                    //       Row(
                    //         children: [
                    //           Icon(Icons.info_outline,
                    //               color: AppTheme.primary, size: 18),
                    //           const SizedBox(width: 8),
                    //           Text(
                    //             'Warehouse Tip',
                    //             style: TextStyle(
                    //               color: AppTheme.primary,
                    //               fontWeight: FontWeight.w600,
                    //             ),
                    //           ),
                    //         ],
                    //       ),
                    //       const SizedBox(height: 8),
                    //       Text(
                    //         'Scan the QR code on the pallet to automatically update the LPN status for domestic arrivals.',
                    //         style: TextStyle(
                    //           fontSize: 14,
                    //           color: Colors.grey.shade600,
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Bottom Navigation
      bottomNavigationBar: _BottomNavBar(
        onScanTapped: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScanQRScreen(apiService: apiService),
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String? badge;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _TaskCard({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    this.badge,
    this.isHighlighted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isHighlighted ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighlighted
                ? AppTheme.primary
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade500,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                color: isHighlighted ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final VoidCallback onScanTapped;

  const _BottomNavBar({required this.onScanTapped});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          _NavItem(
            icon: Icons.home,
            label: 'Home',
            isActive: true,
            onTap: () {},
          ),
          _NavItem(
            icon: Icons.assignment_outlined,
            label: 'Tasks',
            onTap: () {},
          ),
          // Center scan button
          GestureDetector(
            onTap: onScanTapped,
            child: Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.qr_code_scanner,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          _NavItem(
            icon: Icons.inventory_2_outlined,
            label: 'Stock',
            onTap: () {},
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Config',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.primary : Colors.grey.shade400;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
