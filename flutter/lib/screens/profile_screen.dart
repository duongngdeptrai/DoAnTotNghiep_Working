import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../widgets/top_nav.dart';
import '../utils/device_color.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _deviceIdController = TextEditingController();
  final _searchController = TextEditingController();
  String _filterRole = 'all'; // 'all' | 'owner' | 'shared'
  String? _error;
  bool _isProcessing = false;
  String? _deletingDeviceId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Device> _filteredDevices(List<Device> devices) {
    return devices.where((d) {
      final matchSearch = d.deviceId.toLowerCase().contains(_searchController.text.toLowerCase());
      final matchRole = _filterRole == 'all' || d.role == _filterRole;
      return matchSearch && matchRole;
    }).toList();
  }

  Future<void> _handleRegister() async {
    final deviceId = _deviceIdController.text.trim();
    if (deviceId.isEmpty) {
      setState(() => _error = 'Vui lòng nhập deviceId');
      return;
    }
    setState(() { _error = null; _isProcessing = true; });
    try {
      await context.read<AppProvider>().registerDevice(deviceId);
      _deviceIdController.clear();
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng ký thiết bị thành công'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() { _error = e.toString(); _isProcessing = false; });
    }
  }

  Future<void> _confirmDelete(String deviceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Xóa thiết bị?', style: TextStyle(color: Colors.white)),
        content: Text('Bạn có chắc muốn xóa "$deviceId"?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xóa', style: TextStyle(color: Colors.redAccent))),
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
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _deletingDeviceId = null);
      }
    }
  }

  void _showShareModal(String deviceId) {
    final emailController = TextEditingController();
    String? shareError;
    bool shareLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('Chia sẻ $deviceId', style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chia sẻ thiết bị với người dùng khác qua email.',
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email người nhận',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (shareError != null) ...[
                const SizedBox(height: 8),
                Text(shareError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: shareLoading ? null : () async {
                final email = emailController.text.trim();
                if (email.isEmpty) {
                  setDialogState(() => shareError = 'Vui lòng nhập email');
                  return;
                }
                setDialogState(() { shareLoading = true; shareError = null; });
                try {
                  await context.read<AppProvider>().apiService.shareDevice(deviceId, email);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã chia sẻ $deviceId với $email'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  setDialogState(() { shareLoading = false; shareError = e.toString(); });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22D3EE)),
              child: shareLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                  : const Text('Chia sẻ', style: TextStyle(color: Colors.black87)),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfigModal(String deviceId) async {
    final api = context.read<AppProvider>().apiService;
    String parentEmail = '';
    bool alertEnabled = true;
    bool loading = true;
    bool saving = false;
    String? configError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Load config once
          if (loading) {
            api.fetchDeviceConfig(deviceId).then((cfg) {
              setDialogState(() {
                parentEmail = cfg.parentEmail;
                alertEnabled = cfg.alertEnabled;
                loading = false;
              });
            }).catchError((_) {
              setDialogState(() => loading = false);
            });
          }

          final emailController = TextEditingController(text: parentEmail);

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('Cấu hình thông báo', style: TextStyle(color: Colors.white, fontSize: 16)),
            content: loading
                ? const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        onChanged: (v) => parentEmail = v,
                        decoration: InputDecoration(
                          labelText: 'Email phụ huynh',
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Bật thông báo email', style: TextStyle(color: Colors.white70)),
                          ),
                          Switch(
                            value: alertEnabled,
                            onChanged: (v) => setDialogState(() => alertEnabled = v),
                            activeColor: const Color(0xFF22D3EE),
                          ),
                        ],
                      ),
                      if (configError != null) ...[
                        const SizedBox(height: 8),
                        Text(configError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ],
                    ],
                  ),
            actions: [
              TextButton(
                onPressed: () async {
                  try {
                    await api.deleteDeviceConfig(deviceId);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã xóa cấu hình'), backgroundColor: Colors.orange),
                      );
                    }
                  } catch (e) {
                    setDialogState(() => configError = e.toString());
                  }
                },
                child: const Text('Xóa cấu hình', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
              TextButton(onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đóng', style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                onPressed: saving ? null : () async {
                  setDialogState(() { saving = true; configError = null; });
                  try {
                    await api.postDeviceConfig(deviceId, parentEmail, alertEnabled);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã lưu cấu hình'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    setDialogState(() { saving = false; configError = e.toString(); });
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22D3EE)),
                child: saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                    : const Text('Lưu', style: TextStyle(color: Colors.black87)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final filtered = _filteredDevices(provider.devices);

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
                onNavigateStats: provider.devices.isNotEmpty
                    ? () => Navigator.of(context).pushNamed('/statistics', arguments: provider.selectedDeviceId)
                    : null,
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
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                      ),
                      const SizedBox(height: 24),

                      // Device selector + register
                      _buildRegisterCard(provider),

                      const SizedBox(height: 24),

                      // Search + filter bar
                      if (provider.devices.isNotEmpty) ...[
                        _buildSearchFilter(),
                        const SizedBox(height: 12),
                        const Text(
                          'Danh sách thiết bị',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        if (filtered.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text('Không tìm thấy thiết bị',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                            ),
                          )
                        else
                          ...filtered.map((device) => _buildDeviceCard(context, device)),
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

  Widget _buildRegisterCard(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Thiết bị hiện tại',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: provider.devices.any((d) => d.deviceId == provider.selectedDeviceId)
                ? provider.selectedDeviceId
                : (provider.devices.isNotEmpty ? provider.devices.first.deviceId : null),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
            ),
            items: provider.devices.map((device) => DropdownMenuItem(
              value: device.deviceId,
              child: Text('${device.deviceId} (${device.role})', style: const TextStyle(color: Colors.white)),
            )).toList(),
            onChanged: provider.devices.isEmpty ? null : (value) {
              if (value != null) provider.selectDevice(value);
            },
            dropdownColor: const Color(0xFF0F172A),
          ),
          const SizedBox(height: 20),
          const Text('Đăng ký deviceId mới',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _deviceIdController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'deviceId (ví dụ: child_02)',
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
              prefixIcon: Icon(Icons.qr_code, color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.error, color: Colors.orangeAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 12))),
              ]),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              ),
              child: _isProcessing
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0B0F1A)))
                  : const Text('Đăng ký thiết bị',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilter() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Tìm device ID...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
              prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.4), size: 18),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: DropdownButton<String>(
            value: _filterRole,
            underline: const SizedBox(),
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Tất cả')),
              DropdownMenuItem(value: 'owner', child: Text('Owner')),
              DropdownMenuItem(value: 'shared', child: Text('Shared')),
            ],
            onChanged: (v) => setState(() => _filterRole = v ?? 'all'),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(BuildContext context, Device device) {
    final color = getDeviceColor(device.deviceId);
    final isOwner = device.role == 'owner';
    final isDeleting = _deletingDeviceId == device.deviceId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    device.deviceId.substring(0, 1).toUpperCase(),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.deviceId,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOwner ? const Color(0xFF22D3EE).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isOwner ? 'OWNER' : 'SHARED',
                          style: TextStyle(
                            color: isOwner ? const Color(0xFF22D3EE) : Colors.white54,
                            fontSize: 9, fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              if (isDeleting)
                const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),
          // Action buttons row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _ActionChip(
                icon: Icons.bar_chart,
                label: 'Thống kê',
                color: Colors.cyanAccent,
                onTap: () => Navigator.of(context).pushNamed('/statistics', arguments: device.deviceId),
              ),
              if (isOwner) ...[
                _ActionChip(
                  icon: Icons.share,
                  label: 'Chia sẻ',
                  color: Colors.purpleAccent,
                  onTap: () => _showShareModal(device.deviceId),
                ),
                _ActionChip(
                  icon: Icons.notifications_outlined,
                  label: 'Cấu hình',
                  color: Colors.orangeAccent,
                  onTap: () => _showConfigModal(device.deviceId),
                ),
                _ActionChip(
                  icon: Icons.delete_outline,
                  label: 'Xóa',
                  color: Colors.redAccent,
                  onTap: isDeleting ? null : () => _confirmDelete(device.deviceId),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionChip({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
