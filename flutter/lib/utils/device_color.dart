import 'package:flutter/material.dart';

Color getDeviceColor(String deviceId) {
  final colors = const [
    Color(0xFF22D3EE),
    Color(0xFFA78BFA),
    Color(0xFF34D399),
    Color(0xFFF472B6),
    Color(0xFFFB923C),
    Color(0xFF60A5FA),
  ];
  final index = deviceId.length % colors.length;
  return colors[index];
}
