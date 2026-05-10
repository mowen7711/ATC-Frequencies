import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../models/frequency.dart';

class FrequencyCard extends StatelessWidget {
  const FrequencyCard({super.key, required this.frequency});
  final Frequency frequency;

  @override
  Widget build(BuildContext context) {
    final color = frequency.color;
    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _copyToClipboard(context),
        onLongPress: () => _copyToClipboard(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorder, width: 0.5),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Type badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withAlpha(100)),
                ),
                child: Text(
                  frequency.type,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Description
              Expanded(
                child: Text(
                  frequency.description.isNotEmpty
                      ? frequency.description
                      : frequency.type,
                  style: const TextStyle(
                    color: kTextSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              // Frequency value
              Text(
                frequency.formatted,
                style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.copy_rounded, size: 14, color: kTextMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: frequency.formatted));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${frequency.type}: ${frequency.formatted} copied'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: kCard,
      ),
    );
  }
}
