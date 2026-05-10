import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../providers/app_provider.dart';

class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (provider.backgroundUpdating) {
          return Container(
            color: kAccent.withAlpha(20),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kAccent,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Updating airport data in background…',
                    style: TextStyle(color: kAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }
        return _StaleDataBanner();
      },
    );
  }
}

class _StaleDataBanner extends StatefulWidget {
  @override
  State<_StaleDataBanner> createState() => _StaleDataBannerState();
}

class _StaleDataBannerState extends State<_StaleDataBanner> {
  bool _dismissed = false;
  bool _isStale = false;
  String _lastUpdatedStr = '';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt('last_update') ?? 0;
    if (lastMs == 0) return;
    final lastDate = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final daysSince = DateTime.now().difference(lastDate).inDays;
    if (!mounted) return;
    setState(() {
      _isStale = daysSince >= kUpdateIntervalDays;
      _lastUpdatedStr = _formatDate(lastDate);
    });
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    return '$diff days ago';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isStale || _dismissed) return const SizedBox.shrink();
    return Container(
      color: const Color(0xFF1A2A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.update_rounded, size: 16, color: Color(0xFF81C784)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Data last updated $_lastUpdatedStr. Tap to refresh.',
              style:
                  const TextStyle(color: Color(0xFF81C784), fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: () =>
                context.read<AppProvider>().forceRefresh(),
            child: const Text('Refresh',
                style: TextStyle(
                    color: Color(0xFF81C784),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline)),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => setState(() => _dismissed = true),
            child: const Icon(Icons.close_rounded,
                size: 16, color: Color(0xFF81C784)),
          ),
        ],
      ),
    );
  }
}
