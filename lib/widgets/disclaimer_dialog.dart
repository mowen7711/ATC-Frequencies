import 'package:flutter/material.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';

void showDisclaimerDialog(BuildContext context, AppProvider provider) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DisclaimerDialog(provider: provider),
  );
}

class _DisclaimerDialog extends StatefulWidget {
  const _DisclaimerDialog({required this.provider});
  final AppProvider provider;

  @override
  State<_DisclaimerDialog> createState() => _DisclaimerDialogState();
}

class _DisclaimerDialogState extends State<_DisclaimerDialog> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: context.col.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: context.col.accent, size: 26),
            const SizedBox(width: 10),
            Text(
              'Recreational Use Only',
              style: TextStyle(
                color: context.col.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                kDisclaimerText,
                style: TextStyle(
                  color: context.col.textSecondary,
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: () => setState(() => _agreed = !_agreed),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreed,
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                      activeColor: context.col.accent,
                      checkColor: Colors.black,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'I understand this app is for recreational and reference use only, and I will always verify ATC frequencies through official channels before flight.',
                          style: TextStyle(
                            color: context.col.textPrimary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: _agreed
                ? () {
                    widget.provider.acceptDisclaimer();
                    Navigator.of(context).pop();
                  }
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: context.col.accent,
              disabledBackgroundColor: context.col.border,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'I Agree',
              style: TextStyle(
                color: _agreed ? Colors.black : context.col.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const kDisclaimerText =
    'ATC Frequencies is intended for recreational, educational, and '
    'reference purposes only.\n\n'
    'Frequency data is sourced from OurAirports.com, a community-maintained '
    'database. It may be incomplete, out of date, or contain errors. '
    'Frequencies change regularly and this app may not reflect the latest '
    'published information.\n\n'
    'Do not use this app as a primary or sole source of ATC frequency '
    'information when operating an aircraft. Always verify frequencies '
    'through official channels — ATIS, your national AIP, a certified '
    'flight planning service, or direct communication with ATC.\n\n'
    'The developer accepts no liability for any errors, omissions, or '
    'consequences arising from reliance on this data.';
