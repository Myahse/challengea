import 'package:flutter/material.dart';

import '../theme.dart';

/// Figma: hidden "Contact support" panel on the LOGIN frames (the "?" icon).
void showSupportSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Contact support', style: tx(20, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Pick one of the two options',
              style: tx(14, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            _option(
              ctx,
              Icons.chat_rounded,
              'WhatsApp',
              'Messages and voice notes only',
            ),
            const SizedBox(height: 10),
            _option(
              ctx,
              Icons.call_rounded,
              'Toll-free call',
              'Available 24/7',
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _option(BuildContext ctx, IconData icon, String title, String subtitle) {
  return Material(
    color: const Color(0xFFF2F2F2),
    borderRadius: BorderRadius.circular(16),
    child: ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Icon(icon, color: AppColors.ink),
      title: Text(title, style: tx(16, weight: FontWeight.w600)),
      subtitle: Text(subtitle, style: tx(13, color: AppColors.muted)),
      trailing: const Icon(Icons.navigate_next),
      onTap: () {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              '$title: support contact comes with the backend',
              style: tx(14, color: Colors.white),
            ),
          ),
        );
      },
    ),
  );
}
