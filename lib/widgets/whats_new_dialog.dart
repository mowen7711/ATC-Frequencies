import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

// ── Changelog ─────────────────────────────────────────────────────────────────
// Add a new entry here whenever a new version ships.
// The first entry is always shown to new users as "what to expect".

const List<_Release> _kChangelog = [
  _Release(
    version: '1.0.1',
    title: 'Bug fixes & improvements',
    items: [
      'Runways and nav aids now shown on airport detail screens',
      'Shake-to-report is less sensitive — fewer accidental triggers',
      'Fixed several crashes and display issues',
    ],
  ),
  _Release(
    version: '1.0.0',
    title: 'Welcome to ATC Frequencies',
    items: [
      'Search 70,000+ airports worldwide by name, ICAO, IATA, or city',
      'Search by frequency — type 121.5 to find all airports using that frequency',
      'Nearby airports via GPS with adjustable radius',
      'Full ATC frequency lists with tap-to-copy',
      'VHF signal reception estimate',
      'SDR Touch integration for live listening',
      'LiveATC.net link-out for live audio streams',
      'Data updated weekly from OurAirports.com',
    ],
  ),
];

// ── Model ─────────────────────────────────────────────────────────────────────

class _Release {
  const _Release(
      {required this.version, required this.title, required this.items});
  final String version;
  final String title;
  final List<String> items;
}

// ── Public API ────────────────────────────────────────────────────────────────

const String _kLastSeenVersionKey = 'last_seen_version';

/// Shows the What's New dialog if the app version has changed since last launch.
/// Pass [forceShow] to always show (e.g. from Settings).
Future<void> maybeShowWhatsNew(BuildContext context, String currentVersion,
    {bool forceShow = false}) async {
  final prefs = await SharedPreferences.getInstance();
  final lastSeen = prefs.getString(_kLastSeenVersionKey);

  if (!forceShow && lastSeen == currentVersion) return;

  await prefs.setString(_kLastSeenVersionKey, currentVersion);

  if (!context.mounted) return;

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => _WhatsNewDialog(currentVersion: currentVersion),
  );
}

// ── Dialog ────────────────────────────────────────────────────────────────────

class _WhatsNewDialog extends StatelessWidget {
  const _WhatsNewDialog({required this.currentVersion});
  final String currentVersion;

  @override
  Widget build(BuildContext context) {
    // Find changelog entries up to and including currentVersion
    final entries = _kChangelog
        .where((r) => _versionCompare(r.version, currentVersion) <= 0)
        .take(2) // show at most 2 releases worth of notes
        .toList();

    final isFirstRun = entries.length == 1 &&
        entries.first.version == _kChangelog.last.version;

    return Dialog(
      backgroundColor: context.col.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.col.accent.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.new_releases_rounded,
                      color: context.col.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFirstRun ? 'Welcome!' : "What's New",
                        style: TextStyle(
                          color: context.col.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Version $currentVersion',
                        style: TextStyle(
                            color: context.col.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final release in entries) ...[
                      if (entries.length > 1) ...[
                        Text(
                          release.version,
                          style: TextStyle(
                            color: context.col.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      for (final item in release.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: context.col.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    color: context.col.textSecondary,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (entries.length > 1) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: context.col.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Let's go",
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple semver comparator. Returns negative if a < b, 0 if equal, positive if a > b.
int _versionCompare(String a, String b) {
  final aParts = a.split('.').map(int.tryParse).toList();
  final bParts = b.split('.').map(int.tryParse).toList();
  for (var i = 0; i < 3; i++) {
    final diff = (aParts.elementAtOrNull(i) ?? 0) -
        (bParts.elementAtOrNull(i) ?? 0);
    if (diff != 0) return diff;
  }
  return 0;
}
