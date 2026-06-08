import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/airport.dart';
import '../providers/app_provider.dart';
import '../screens/airport_detail_screen.dart';

class HomeAirportCard extends StatelessWidget {
  const HomeAirportCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final airport = provider.homeAirport;
        if (airport == null) {
          return _SetHomePrompt();
        }
        return _HomeCard(airport: airport);
      },
    );
  }
}

// ── Empty state — prompt to set a home airport ────────────────────────────────

class _SetHomePrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickHomeAirport(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.col.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: context.col.accent.withAlpha(60), width: 1, style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.col.accent.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.home_outlined, color: context.col.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set Home Airport',
                      style: TextStyle(
                          color: context.col.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    'Pin your local airport for quick access to its frequencies.',
                    style: TextStyle(
                        color: context.col.textSecondary, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline_rounded,
                color: context.col.accent, size: 22),
          ],
        ),
      ),
    );
  }

  void _pickHomeAirport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.col.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _HomeAirportPicker(),
    );
  }
}

// ── Populated card ────────────────────────────────────────────────────────────

class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.airport});
  final Airport airport;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AirportDetailScreen(airport: airport),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          color: context.col.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.col.accent.withAlpha(80), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(
                children: [
                  Icon(Icons.home_rounded, color: context.col.accent, size: 16),
                  const SizedBox(width: 6),
                  Text('Home Airport',
                      style: TextStyle(
                          color: context.col.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showChangeDialog(context),
                    child: Text('Change',
                        style: TextStyle(
                            color: context.col.textMuted,
                            fontSize: 11,
                            decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  // Code badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.col.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.col.accent.withAlpha(100)),
                    ),
                    child: Text(
                      airport.displayCode,
                      style: TextStyle(
                        color: context.col.accent,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(airport.name,
                            style: TextStyle(
                                color: context.col.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(
                          [
                            airport.locationString,
                            kAirportTypeLabels[airport.type] ?? '',
                          ].where((s) => s.isNotEmpty).join(' · '),
                          style: TextStyle(
                              color: context.col.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: context.col.textMuted, size: 20),
                ],
              ),
            ),
            if (airport.elevationFt != null) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Row(
                  children: [
                    _Chip(
                        icon: Icons.terrain_rounded,
                        label:
                            '${airport.elevationFt} ft · ${(airport.elevationFt! * 0.3048).toStringAsFixed(0)} m'),
                    const SizedBox(width: 8),
                    if (airport.iataCode.isNotEmpty)
                      _Chip(
                          icon: Icons.confirmation_number_outlined,
                          label: airport.iataCode),
                  ],
                ),
              ),
            ] else
              const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showChangeDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.col.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _HomeAirportPicker(),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: context.col.textMuted),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(color: context.col.textMuted, fontSize: 11)),
      ],
    );
  }
}

// ── Bottom sheet picker ───────────────────────────────────────────────────────

class _HomeAirportPicker extends StatefulWidget {
  @override
  State<_HomeAirportPicker> createState() => _HomeAirportPickerState();
}

class _HomeAirportPickerState extends State<_HomeAirportPicker> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
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
            const SizedBox(height: 16),
            Text('Choose Home Airport',
                style: TextStyle(
                    color: context.col.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            // Search field
            TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: context.col.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by name, ICAO or IATA…',
                prefixIcon:
                    Icon(Icons.search_rounded, color: context.col.textMuted),
              ),
              onChanged: (q) =>
                  context.read<AppProvider>().search(q),
            ),
            const SizedBox(height: 12),
            // Results
            Expanded(
              child: Consumer<AppProvider>(
                builder: (context, provider, _) {
                  if (provider.searching) {
                    return Center(
                        child: CircularProgressIndicator(color: context.col.accent));
                  }
                  if (provider.searchResults.isEmpty &&
                      _controller.text.isNotEmpty) {
                    return Center(
                        child: Text('No airports found',
                            style: TextStyle(color: context.col.textSecondary)));
                  }
                  return ListView.separated(
                    itemCount: provider.searchResults.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final airport = provider.searchResults[i];
                      return ListTile(
                        tileColor: context.col.background,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        leading: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.col.card,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(airport.displayCode,
                              style: TextStyle(
                                  color: context.col.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  fontFamily: 'monospace')),
                        ),
                        title: Text(airport.name,
                            style: TextStyle(
                                color: context.col.textPrimary, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(airport.locationString,
                            style: TextStyle(
                                color: context.col.textSecondary, fontSize: 12)),
                        trailing: Icon(Icons.home_rounded,
                            color: context.col.accent, size: 18),
                        onTap: () {
                          context
                              .read<AppProvider>()
                              .setHomeAirport(airport.ident);
                          provider.clearSearch();
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
