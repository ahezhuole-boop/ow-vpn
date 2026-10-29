import 'package:flutter/material.dart';

/// Temporary demo brand. Replace these values with your legally cleared name.
/// Brand/domain references here are NOT a running service or published app.
abstract final class Brand {
  static const productName = 'OwnNode VPN';
  static const shortName = 'OwnNode';
  static const slogan = '你的节点 · 你的网络';
  static const primary = Color(0xFF275CF4);
  static const background = Color(0xFFF7F9FC);
}

/// Vector-like in-app mark; independent of operating-system launcher icons.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    height: size,
    width: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .29),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF477BFF), Brand.primary, Color(0xFF153AB6)],
      ),
    ),
    child: Icon(Icons.power_settings_new_rounded,
      color: Colors.white, size: size * .63),
  );
}
