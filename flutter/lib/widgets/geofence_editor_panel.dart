import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

class GeofenceEditorPanel extends StatefulWidget {
  final void Function(Geofence)? onFocusGeofence;

  const GeofenceEditorPanel({super.key, this.onFocusGeofence});

  @override
  State<GeofenceEditorPanel> createState() => _GeofenceEditorPanelState();
}

class _GeofenceEditorPanelState extends State<GeofenceEditorPanel> {
  final _nameController = TextEditingController();
  final _radiusController = TextEditingController();
  bool _saving = false;

  // Track initial values to detect unsaved changes
  String? _capturedEditingId;
  String _initialName = '';
  double _initialRadius = 0;
  int _initialPathLength = 0;

  void _captureInitialValues(AppProvider provider) {
    final cfg = provider.pendingConfig;
    _initialName = cfg.name;
    _initialRadius = cfg.radius;
    _initialPathLength = cfg.path.length;
    _capturedEditingId = provider.editingGeofenceId;
  }

  bool _hasUnsavedChanges(AppProvider provider) {
    final cfg = provider.pendingConfig;
    return cfg.name != _initialName ||
        cfg.radius != _initialRadius ||
        cfg.path.length != _initialPathLength;
  }

  void _onCancel(BuildContext context, AppProvider provider) {
    if (_hasUnsavedChanges(provider)) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Hủy thay đổi?',
              style: TextStyle(color: Colors.white, fontSize: 15)),
          content: const Text(
            'Bạn có thay đổi chưa lưu. Bạn có chắc muốn hủy không?',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tiếp tục chỉnh sửa',
                  style: TextStyle(color: Color(0xFF22D3EE))),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                provider.cancelPlanMode();
              },
              child: const Text('Hủy bỏ',
                  style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
    } else {
      provider.cancelPlanMode();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  void _syncFromProvider(AppProvider provider) {
    final cfg = provider.pendingConfig;
    if (_nameController.text != cfg.name) {
      _nameController.text = cfg.name;
    }
    final radiusStr = cfg.radius.toStringAsFixed(0);
    if (_radiusController.text != radiusStr) {
      _radiusController.text = radiusStr;
    }
  }

  Future<void> _save(AppProvider provider) async {
    setState(() => _saving = true);
    await provider.saveGeofence();
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    if (provider.isPlanMode) {
      // Capture initial values when entering plan mode for a new/different geofence
      if (_capturedEditingId != provider.editingGeofenceId) {
        _captureInitialValues(provider);
      }
      _syncFromProvider(provider);
      return _buildEditorView(context, provider);
    }
    return _buildListView(context, provider);
  }

  Widget _buildListView(BuildContext context, AppProvider provider) {
    final onFocus = widget.onFocusGeofence;
    final geofences = provider.geofenceState.geofences;
    final isOwner = provider.isOwner;

    return Container(
      width: 210,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1729).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            child: Row(
              children: [
                const Text(
                  'Vùng an toàn',
                  style: TextStyle(
                    color: Color(0xFF22D3EE),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (isOwner)
                  GestureDetector(
                    onTap: () => provider.startPlanMode(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22D3EE).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.add, color: Color(0xFF22D3EE), size: 16),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          if (geofences.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Chưa có vùng an toàn',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                  ),
                  if (provider.error != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      provider.error!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: geofences.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                itemBuilder: (context, i) {
                  final g = geofences[i];
                  return _GeofenceListItem(
                    geofence: g,
                    isOwner: isOwner,
                    onFocus: onFocus != null ? () => onFocus(g) : null,
                    onEdit: () => provider.startPlanMode(editTarget: g),
                    onDelete: () => provider.removeGeofence(g.id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditorView(BuildContext context, AppProvider provider) {
    final cfg = provider.pendingConfig;
    final isPath = cfg.mode == 'mobile';

    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1729).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF22D3EE).withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            child: Row(
              children: [
                Text(
                  provider.editingGeofenceId == null ? 'Thêm vùng mới' : 'Chỉnh sửa vùng',
                  style: const TextStyle(
                    color: Color(0xFF22D3EE),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _onCancel(context, provider),
                  child: const Icon(Icons.close, color: Colors.white54, size: 18),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Name field
                _buildLabel('Tên vùng'),
                const SizedBox(height: 4),
                _buildTextField(
                  controller: _nameController,
                  hint: 'Ví dụ: Nhà, Trường học...',
                  onChanged: (v) => provider.updatePendingConfig(cfg.copyWith(name: v)),
                ),
                const SizedBox(height: 10),

                // Mode toggle
                _buildLabel('Loại vùng'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _ModeButton(
                      label: 'Hình tròn',
                      active: !isPath,
                      onTap: () => provider.updatePendingConfig(cfg.copyWith(mode: 'fixed', path: [])),
                    ),
                    const SizedBox(width: 6),
                    _ModeButton(
                      label: 'Đường đi',
                      active: isPath,
                      onTap: () => provider.updatePendingConfig(cfg.copyWith(mode: 'mobile')),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Radius
                _buildLabel('Bán kính (m)'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: cfg.radius.clamp(10, 5000),
                        min: 10,
                        max: 5000,
                        divisions: 499,
                        activeColor: const Color(0xFF22D3EE),
                        inactiveColor: Colors.white12,
                        onChanged: (v) {
                          provider.updatePendingConfig(cfg.copyWith(radius: v));
                          _radiusController.text = v.toStringAsFixed(0);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: _buildTextField(
                        controller: _radiusController,
                        hint: '100',
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final val = double.tryParse(v);
                          if (val != null) provider.updatePendingConfig(cfg.copyWith(radius: val.clamp(10, 5000)));
                        },
                      ),
                    ),
                  ],
                ),

                // Path mode info
                if (isPath) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Điểm: ${cfg.path.length}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const Spacer(),
                      if (cfg.path.isNotEmpty)
                        GestureDetector(
                          onTap: provider.removeLastPathPoint,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              'Xóa điểm cuối',
                              style: TextStyle(color: Colors.redAccent, fontSize: 10),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chạm vào bản đồ để thêm điểm',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    'Chạm vào bản đồ để đặt tâm',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
                  ),
                ],

                // Error
                if (provider.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    provider.error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                  ),
                ],

                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onCancel(context, provider),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text('Hủy', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: _saving ? null : () => _save(provider),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22D3EE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: _saving
                                ? const SizedBox(
                                    width: 14, height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                                  )
                                : const Text('Lưu', style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(color: Colors.white54, fontSize: 11),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF22D3EE)),
        ),
      ),
    );
  }
}

class _GeofenceListItem extends StatelessWidget {
  final Geofence geofence;
  final bool isOwner;
  final VoidCallback? onFocus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GeofenceListItem({
    required this.geofence,
    required this.isOwner,
    this.onFocus,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPath = geofence.mode == 'mobile';
    return GestureDetector(
      onTap: onFocus,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Icon(
            isPath ? Icons.route : Icons.radio_button_checked,
            color: isPath ? const Color(0xFFA78BFA) : const Color(0xFF22D3EE),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  geofence.name.isEmpty ? 'Vùng ${geofence.id.substring(0, 6)}' : geofence.name,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isPath ? 'Đường đi' : 'Hình tròn · ${geofence.radiusM.toStringAsFixed(0)}m',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          if (isOwner) ...[
            GestureDetector(
              onTap: onEdit,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.edit_outlined, color: Colors.white54, size: 15),
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_outline, color: Colors.redAccent, size: 15),
              ),
            ),
          ],
        ],
      ),
    ));
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF22D3EE).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? const Color(0xFF22D3EE) : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF22D3EE) : Colors.white54,
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
