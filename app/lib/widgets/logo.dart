import 'package:flutter/material.dart';

import '../theme.dart';

/// Text version of the nteri logo (black "nter" + green "i").
/// Replace with the exported logo image from Figma when it is final.
class NteriLogo extends StatelessWidget {
  const NteriLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'nter'),
          TextSpan(
            text: 'i',
            style: tx(size, weight: FontWeight.w800, color: AppColors.brand),
          ),
        ],
      ),
      style: tx(size, weight: FontWeight.w800),
    );
  }
}
