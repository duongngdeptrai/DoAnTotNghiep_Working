import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';

const _eventLabels = {
  'outside_entered': 'Rời khỏi vùng an toàn',
  'outside_reminder': 'Vẫn đang ngoài vùng an toàn',
  'inside_entered': 'Đã đến',
  'inside_moved': 'Đã chuyển đến',
};

String _buildMessage(Alert alert) {
  final zone = alert.zoneName ?? 'vùng an toàn';
  switch (alert.event) {
    case 'outside_entered':
      return '${alert.deviceId} đã rời khỏi vùng an toàn';
    case 'outside_reminder':
      return '${alert.deviceId} vẫn đang ngoài vùng an toàn';
    case 'inside_entered':
      return '${alert.deviceId} đã đến $zone';
    case 'inside_moved':
      return '${alert.deviceId} đã chuyển đến $zone';
    default:
      return 'Cảnh báo từ ${alert.deviceId}';
  }
}

class NotificationToast extends StatelessWidget {
  final List<ToastItem> toasts;
  final void Function(String id) onDismiss;

  const NotificationToast({
    super.key,
    required this.toasts,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (toasts.isEmpty) return const SizedBox.shrink();
    return Positioned(
      bottom: 24,
      right: 16,
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: toasts
            .map((t) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _ToastItemWidget(
                    key: ValueKey(t.id),
                    item: t,
                    onDismiss: () => onDismiss(t.id),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _ToastItemWidget extends StatefulWidget {
  final ToastItem item;
  final VoidCallback onDismiss;

  const _ToastItemWidget({
    super.key,
    required this.item,
    required this.onDismiss,
  });

  @override
  State<_ToastItemWidget> createState() => _ToastItemWidgetState();
}

class _ToastItemWidgetState extends State<_ToastItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..forward();

    _dismissTimer = Timer(const Duration(seconds: 5), widget.onDismiss);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.item.alert;
    final isOutside = alert.event.startsWith('outside');
    final accentColor =
        isOutside ? const Color(0xFFF97316) : const Color(0xFF34D399);
    final label = _eventLabels[alert.event] ?? 'Cảnh báo';
    final message = _buildMessage(alert);

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      color: const Color(0xFF1F2937),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: accentColor, width: 4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
              child: Row(
                children: [
                  Text(
                    isOutside ? '⚠️' : '✅',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: const Icon(Icons.close,
                        size: 18, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFE5E7EB),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _progressController,
              builder: (_, __) => ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
                child: LinearProgressIndicator(
                  value: 1 - _progressController.value,
                  minHeight: 3,
                  backgroundColor: const Color(0xFF374151),
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
