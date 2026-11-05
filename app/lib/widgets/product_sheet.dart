import 'package:flutter/material.dart';

import '../feed.dart';
import '../theme.dart';

/// Figma: product sheet over the live video (frame 57:281).
Future<void> showProduct(BuildContext context, Product product) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProductSheet(product: product),
  );
}

class _ProductSheet extends StatefulWidget {
  const _ProductSheet({required this.product});
  final Product product;

  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  String? _size;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            p.name,
            textAlign: TextAlign.center,
            style: tx(16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 1.15,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: p.colors,
                ),
              ),
              child: const Icon(
                Icons.checkroom_rounded,
                size: 90,
                color: Colors.white54,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(p.name, style: tx(17, weight: FontWeight.w700)),
              ),
              Text(
                '\$${p.price.toStringAsFixed(2)}',
                style: tx(17, weight: FontWeight.w800),
              ),
            ],
          ),
          Text(
            'Left: ${p.left}',
            style: tx(
              12,
              color: p.left < 10 ? const Color(0xFFE5484D) : AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(p.description, style: tx(13, weight: FontWeight.w300)),
          const SizedBox(height: 14),
          Text('Size', style: tx(14, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final s in p.sizes)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _size = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _size == s ? AppColors.ink : Colors.white,
                        border: Border.all(color: AppColors.ink),
                      ),
                      child: Text(
                        s,
                        style: tx(
                          12,
                          weight: FontWeight.w700,
                          color: _size == s ? Colors.white : AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _size == null
                  ? null
                  : () {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            '${p.name} (size $_size) added. Payment comes with the shop backend.',
                            style: tx(14, color: Colors.white),
                          ),
                        ),
                      );
                    },
              child: Text(
                _size == null ? 'Pick a size' : 'Buy',
                style: tx(16, weight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
