import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/metrics_service.dart';

/// Shows the bug report bottom sheet.
/// Can be triggered by shake or by the settings button.
Future<void> showBugReportSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.col.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _BugReportSheet(),
  );
}

class _BugReportSheet extends StatefulWidget {
  const _BugReportSheet();

  @override
  State<_BugReportSheet> createState() => _BugReportSheetState();
}

class _BugReportSheetState extends State<_BugReportSheet> {
  final _descController    = TextEditingController();
  final _contextController = TextEditingController();
  final _formKey           = GlobalKey<FormState>();
  bool _sending  = false;
  bool _sent     = false;

  @override
  void dispose() {
    _descController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    MetricsService.instance.trackBugReport(
      description: _descController.text.trim(),
      context:     _contextController.text.trim(),
    );

    // Small delay so the flush has time to fire
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() { _sending = false; _sent = true; });
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: context.col.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.col.accent.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.bug_report_rounded, color: context.col.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Report a Problem',
                        style: TextStyle(
                            color: context.col.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    Text('Anonymous — no account needed',
                        style: TextStyle(color: context.col.textMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_sent) ...[
              // Success state
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withAlpha(80)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Report sent — thank you!',
                          style: TextStyle(color: Colors.green, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Description field
              TextFormField(
                controller: _descController,
                maxLines: 4,
                autofocus: true,
                style: TextStyle(color: context.col.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'What went wrong? The more detail the better…',
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Please describe the problem' : null,
              ),
              const SizedBox(height: 12),

              // Context field
              TextFormField(
                controller: _contextController,
                maxLines: 2,
                style: TextStyle(color: context.col.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'What were you doing when it happened? (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),

              // Privacy note
              Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 13, color: context.col.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Reports are anonymous. We don\'t collect your name, '
                      'email, or location. App version is included automatically.',
                      style: TextStyle(color: context.col.textMuted, fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _sending ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.col.textMuted,
                        side: BorderSide(color: context.col.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: context.col.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _sending
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_sending ? 'Sending…' : 'Send Report',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
