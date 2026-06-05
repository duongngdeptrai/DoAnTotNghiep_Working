import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/top_nav.dart';
import '../utils/device_color.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _deviceIdController = TextEditingController();
  String? _error;
  bool _isProcessing = false;
  String? _deletingDeviceId;

  @override
  void dispose() {
    _deviceIdController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final deviceId = _deviceIdController.text.trim();
    if (deviceId.isEmpty) {
      setState(() => _error = 'Vui lòng nhập deviceId');
      return;
    }

    setState(() {
      _error = null;
      _isProcessing = true;
    });

    try {
      final provider = context.read<AppProvider>();
      await provider.registerDevice(deviceId);
      _deviceIdController.clear();
      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng ký thiết bị thành công'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isProcessing = false;
      });
    }
  }

  Future<void> _confirmDelete(BuildContext context, String deviceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Xóa thiết bị?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bạn có chắc muốn xóa "$deviceId"? Hành động này không thể hoàn tác.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      setState(() => _deletingDeviceId = deviceId);
      try {
        await context.read<AppProvider>().unregisterDevice(deviceId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã xóa $deviceId'), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi xóa thiết bị: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _deletingDeviceId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B0F1A), Color(0xFF0F172A), Color(0xFF111827)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              TopNav(
                token: provider.token,
                userEmail: provider.currentUser?.email,
                onLogout: () {
                  provider.logout();
                  Navigator.of(context).pushReplacementNamed('/auth');
                },
                onNavigateHome: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hồ sơ thiết bị',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Quản lý danh sách thiết bị bạn đang theo dõi.',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                      ),
                      const SizedBox(height: 24),

                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Thiết bị hiện tại',
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: provider.selectedDeviceId,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.08),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                                ),
                              ),
                              items: provider.devices.map((device) {
                                return DropdownMenuItem(
                                  value: device.deviceId,
                                  child: Text(
                                    '${device.deviceId} (${device.role})',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                );
                              }).toList(),
                              onChanged: provider.devices.isEmpty ? null : (value) {
                                if (value != null) {
                                  provider.selectDevice(value);
                                }
                              },
                              dropdownColor: const Color(0xFF0F172A),
                            ),
                            const SizedBox(height: 20),

                            const Text(
                              'Đăng ký deviceId mới',
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _deviceIdController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'deviceId (ví dụ: child_02)',
                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.08),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                                ),
                                prefixIcon: Icon(Icons.qr_code, color: Colors.white.withOpacity(0.5)),
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error, color: Colors.orangeAccent, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                          color: Colors.orangeAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isProcessing ? null : _handleRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyan,
                                  foregroundColor: const Color(0xFF0B0F1A),
                                  padding: const EdgeInsets.all(14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                ),
                                child: _isProcessing
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF0B0F1A),
                                        ),
                                      )
                                    : const Text(
                                        'Đăng ký thiết bị',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      if (provider.devices.isNotEmpty) ...[
                        const Text(
                          'Danh sách thiết bị',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        ...provider.devices.map((device) {
                          final colors = getDeviceColor(device.deviceId);
                          final isDeleting = _deletingDeviceId == device.deviceId;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(color: colors, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        device.deviceId,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        device.role.toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isDeleting)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                                  )
                                else
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () => _confirmDelete(context, device.deviceId),
                                    tooltip: 'Xóa thiết bị',
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
