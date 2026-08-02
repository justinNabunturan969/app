import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Compact "alternative login" button row. Currently stubbed (no platform
/// integration), but visually represents fingerprint + QR scan so the
/// future flow is communicated.
class BiometricLoginRow extends StatelessWidget {
  const BiometricLoginRow({super.key, required this.onBiometric, required this.onScan});

  final VoidCallback onBiometric;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark
        ? PupColors.darkCardAlt
        : PupColors.lightCard;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : PupColors.ashGray.withValues(alpha: 0.22);
    final labelColor = isDark ? Colors.white : PupColors.slateGray;

    return Row(
      children: [
        Expanded(
          child: _AltButton(
            label: 'Fingerprint',
            icon: Icons.fingerprint_rounded,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Biometric login (prototype).'),
                  duration: Duration(seconds: 2),
                ),
              );
              onBiometric();
            },
            fillColor: fillColor,
            borderColor: borderColor,
            labelColor: labelColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AltButton(
            label: 'Scan PUP ID',
            icon: Icons.qr_code_scanner_rounded,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PUP ID scan (prototype).'),
                  duration: Duration(seconds: 2),
                ),
              );
              onScan();
            },
            fillColor: fillColor,
            borderColor: borderColor,
            labelColor: labelColor,
          ),
        ),
      ],
    );
  }
}

class _AltButton extends StatelessWidget {
  const _AltButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.fillColor,
    required this.borderColor,
    required this.labelColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color fillColor;
  final Color borderColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: labelColor, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
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
