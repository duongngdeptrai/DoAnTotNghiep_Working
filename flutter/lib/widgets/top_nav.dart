import 'package:flutter/material.dart';

class TopNav extends StatelessWidget {
  final String? token;
  final String? userEmail;
  final VoidCallback onLogout;
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateProfile;

  const TopNav({
    super.key,
    this.token,
    this.userEmail,
    required this.onLogout,
    this.onNavigateHome,
    this.onNavigateProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.14)),
        ),
        color: const Color(0xFF0F172A).withOpacity(0.85),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Row(
            children: [
              // Brand
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Child Tracking',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Fraunces',
                      ),
                    ),
                    Text(
                      'Real-time safety dashboard',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Navigation
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: const Color(0xFF0F172A).withOpacity(0.6),
                  border: Border.all(color: Colors.white.withOpacity(0.14)),
                ),
                child: Row(
                  children: [
                    NavButton(
                      label: 'Theo dõi',
                      onTap: onNavigateHome,
                    ),
                    NavButton(
                      label: 'Hồ sơ',
                      onTap: onNavigateProfile,
                    ),
                  ],
                ),
              ),

              // User info
              if (token != null)
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  onSelected: (value) {
                    if (value == 'logout') onLogout();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          userEmail ?? 'Đã đăng nhập',
                          style: TextStyle(color: Colors.white.withOpacity(0.8)),
                        ),
                      ),
                    ),
                    const PopupMenuItem(value: 'logout', child: Text('Đăng xuất', style: TextStyle(color: Colors.red))),
                  ],
                )
              else
                Text(
                  'Chưa đăng nhập',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}