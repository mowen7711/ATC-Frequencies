import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.col.accent.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.col.accent.withAlpha(60), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 14, color: context.col.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'For recreational use only — always verify frequencies with official sources before flight.',
              style: TextStyle(
                color: context.col.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
