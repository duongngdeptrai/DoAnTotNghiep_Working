import 'package:flutter/material.dart';

class TopNav extends StatelessWidget {
  final String? token;
  final String? userEmail;
  final VoidCallback onLogout;
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateProfile;
  final VoidCallback? onNavigateStats;

  const TopNav({
    super.key,
    this.token,
    this.userEmail,
    required this.onLogout,
    this.onNavigateHome,
    this.onNavigateProfile,
    this.onNavigateStats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Row(
            children: [
              // Brand
              const Text(
                'Child Tracking',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Fraunces',
                ),
              ),
              const SizedBox(width: 12),

              // Navigation
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                ),
                child: Row(
                  children: [
                    NavButton(label: 'Theo dõi', onTap: onNavigateHome),
                    NavButton(label: 'Thống kê', onTap: onNavigateStats),
                    NavButton(label: 'Hồ sơ', onTap: onNavigateProfile),
                  ],
                ),
              ),

              const Spacer(),

              // User info
              if (token != null)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 16),
                  ),
                  onSelected: (value) {
                    if (value == 'logout') onLogout();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Text(
                        userEmail ?? 'Đã đăng nhập',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ),
                    const PopupMenuItem(value: 'logout', child: Text('Đăng xuất', style: TextStyle(color: Colors.red))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class NavButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const NavButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: isActive
            ? BoxDecoration(
                color: const Color(0xFF22D3EE).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: const Color(0xFF22D3EE).withValues(alpha: 0.4)),
              )
            : null,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isActive ? const Color(0xFF22D3EE) : Colors.white70,
          ),
        ),
      ),
    );
  }
}
