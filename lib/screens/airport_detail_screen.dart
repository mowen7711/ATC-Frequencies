import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/airport.dart';
import '../models/frequency.dart';
import '../providers/app_provider.dart';
import '../models/navaid.dart';
import '../models/runway.dart';
import '../services/database_service.dart';
import '../services/frequency_notification_service.dart';
import '../services/metrics_service.dart';
import '../widgets/disclaimer_banner.dart';
import '../widgets/frequency_card.dart';
import '../widgets/runway_card.dart';
import '../widgets/signal_reception_card.dart';

class AirportDetailScreen extends StatefulWidget {
  const AirportDetailScreen({super.key, required this.airport});
  final Airport airport;

  @override
  State<AirportDetailScreen> createState() => _AirportDetailScreenState();
}

class _AirportDetailScreenState extends State<AirportDetailScreen> {
  bool _isFav = false;
  bool _isPinned = false;
  List<Frequency> _frequencies = [];
  List<Runway> _runways = [];
  List<Navaid> _navaids = [];
  bool _loadingFreqs = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    MetricsService.instance.trackAirportView(
        widget.airport.ident, widget.airport.type);
    final provider = context.read<AppProvider>();
    final results = await Future.wait([
      provider.isFavourite(widget.airport.ident),
      provider.getFrequencies(widget.airport.id),
      FrequencyNotificationService.instance.selectedIdent,
      DatabaseService.instance.getRunways(widget.airport.ident),
      DatabaseService.instance.getNavaids(widget.airport.ident),
    ]);
    if (mounted) {
      setState(() {
        _isFav = results[0] as bool;
        _frequencies = results[1] as List<Frequency>;
        _isPinned = (results[2] as String?) == widget.airport.ident;
        _runways = results[3] as List<Runway>;
        _navaids = results[4] as List<Navaid>;
        _loadingFreqs = false;
      });
    }
    // Confirm enabled flag (separate async call)
    final enabled = await FrequencyNotificationService.instance.isEnabled;
    final ident   = await FrequencyNotificationService.instance.selectedIdent;
    if (mounted) {
      setState(() => _isPinned = enabled && ident == widget.airport.ident);
    }
  }

  Future<void> _toggleHome() async {
    final provider = context.read<AppProvider>();
    if (provider.isHome(widget.airport.ident)) {
      await provider.clearHomeAirport();
    } else {
      await provider.setHomeAirport(widget.airport.ident);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.airport.name} set as home airport'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.col.card,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _togglePin() async {
    final svc = FrequencyNotificationService.instance;
    if (_isPinned) {
      await svc.disable();
      if (mounted) {
        setState(() => _isPinned = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Frequency notification removed'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: context.col.card,
          duration: const Duration(seconds: 2),
        ));
      }
    } else {
      await svc.enable(widget.airport.ident);
      if (mounted) {
        setState(() => _isPinned = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${widget.airport.name} frequencies pinned to notifications'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: context.col.card,
          duration: const Duration(seconds: 2),
        ));
      }
    }
  }

  Future<void> _toggleFavourite() async {
    final provider = context.read<AppProvider>();
    final nowFav = await provider.toggleFavourite(widget.airport.ident);
    if (mounted) setState(() => _isFav = nowFav);
  }

  @override
  Widget build(BuildContext context) {
    final airport = widget.airport;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(airport),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (airport.hasCoordinates) _MapSection(airport: airport),
                // ATC frequencies — primary use-case
                _FrequenciesSection(
                  frequencies: _frequencies,
                  loading: _loadingFreqs,
                  icao: airport.ident,
                  isoCountry: airport.isoCountry,
                ), // icao/isoCountry retained for future use
                const SizedBox(height: 16),
                // Signal reception directly under frequencies
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: SignalReceptionCard(airport: airport),
                ),
                const SizedBox(height: 16),
                // Airport information at the bottom
                _AirportInfoSection(
                  airport: airport,
                  runways: _runways,
                  navaids: _navaids,
                  loading: _loadingFreqs,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(Airport airport) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: context.col.background,
      foregroundColor: context.col.textPrimary,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            airport.name,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: context.col.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            [airport.ident, if (airport.iataCode.isNotEmpty) airport.iataCode]
                .join(' · '),
            style: TextStyle(
                fontSize: 12, color: context.col.accent, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
        // Pin frequencies to notification shade
        IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _isPinned
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              key: ValueKey(_isPinned),
              color: _isPinned ? context.col.accent : context.col.textSecondary,
            ),
          ),
          tooltip: _isPinned
              ? 'Remove frequencies from notifications'
              : 'Pin frequencies to notification shade',
          onPressed: _togglePin,
        ),
        Consumer<AppProvider>(
          builder: (context, provider, _) {
            final isHome = provider.isHome(widget.airport.ident);
            return IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isHome ? Icons.home_rounded : Icons.home_outlined,
                  key: ValueKey(isHome),
                  color: isHome ? context.col.accent : context.col.textSecondary,
                ),
              ),
              tooltip: isHome ? 'Remove home airport' : 'Set as home airport',
              onPressed: _toggleHome,
            );
          },
        ),
        IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _isFav ? Icons.star_rounded : Icons.star_outline_rounded,
              key: ValueKey(_isFav),
              color: _isFav ? context.col.accent : context.col.textSecondary,
            ),
          ),
          tooltip: _isFav ? 'Remove from favourites' : 'Add to favourites',
          onPressed: _toggleFavourite,
        ),
      ],
    );
  }
}

// ── Map Section ───────────────────────────────────────────────────────────────

class _MapSection extends StatelessWidget {
  const _MapSection({required this.airport});
  final Airport airport;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(airport.latitude!, airport.longitude!);
    final accentColor = context.col.accent;
    return SizedBox(
      height: 200,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: point,
          initialZoom: 12,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.atcfreq.app',
          ),
          MarkerLayer(markers: [
            Marker(
              point: point,
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 6)
                  ],
                ),
                child: const Icon(Icons.flight_rounded,
                    color: Colors.black, size: 20),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Combined Airport Info + Runways + Navaids ─────────────────────────────────

class _AirportInfoSection extends StatelessWidget {
  const _AirportInfoSection({
    required this.airport,
    required this.runways,
    required this.navaids,
    required this.loading,
  });
  final Airport airport;
  final List<Runway> runways;
  final List<Navaid> navaids;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ilsNavaids    = navaids.where((n) => n.isIls).toList();
    final otherNavaids  = navaids.where((n) => !n.isIls).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Airport Information',
              style: TextStyle(
                  color: context.col.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          // ── Airport details card ─────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: context.col.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.col.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info rows
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(context, Icons.airplanemode_active_rounded,
                          kAirportTypeLabels[airport.type] ?? airport.type),
                      if (airport.municipality.isNotEmpty ||
                          airport.isoCountry.isNotEmpty)
                        _infoRow(context, Icons.location_on_rounded,
                            airport.locationString),
                      if (airport.elevationFt != null)
                        _infoRow(context, Icons.terrain_rounded,
                            '${airport.elevationFt} ft  ·  '
                            '${(airport.elevationFt! * 0.3048).round()} m elevation'),
                      if (airport.iataCode.isNotEmpty)
                        _infoRow(context, Icons.confirmation_number_outlined,
                            'IATA: ${airport.iataCode}'),
                    ],
                  ),
                ),
                if (airport.hasCoordinates) _CoordRow(airport: airport),
                const SizedBox(height: 6),

                // ── Runways sub-section ──────────────────────────────────
                const Divider(height: 1),
                _SubHeader('Runways'),
                if (loading)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(color: context.col.accent)),
                  )
                else if (runways.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Text('No runway data available.',
                        style: TextStyle(color: context.col.textMuted, fontSize: 13)),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Column(
                      children: runways
                          .map((rwy) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: RunwayCard(runway: rwy, navaids: ilsNavaids),
                              ))
                          .toList(),
                    ),
                  ),

                // ── Navigation Aids sub-section ──────────────────────────
                if (!loading && otherNavaids.isNotEmpty) ...[
                  const Divider(height: 1),
                  _SubHeader('Navigation Aids'),
                  for (var i = 0; i < otherNavaids.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14),
                    _NavaidRow(navaid: otherNavaids[i]),
                  ],
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.col.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(color: context.col.textPrimary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  const _SubHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: context.col.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _CoordRow extends StatelessWidget {
  const _CoordRow({required this.airport});
  final Airport airport;

  @override
  Widget build(BuildContext context) {
    if (!airport.hasCoordinates) return const SizedBox.shrink();
    final coord =
        '${airport.latitude!.toStringAsFixed(4)}, ${airport.longitude!.toStringAsFixed(4)}';
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: coord));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coordinates copied'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: Row(
          children: [
            Icon(Icons.my_location_rounded, size: 16, color: context.col.accent),
            const SizedBox(width: 10),
            Text(coord,
                style: TextStyle(
                    color: context.col.textSecondary,
                    fontSize: 13,
                    fontFamily: 'monospace')),
            const SizedBox(width: 8),
            Icon(Icons.copy_rounded, size: 12, color: context.col.textMuted),
          ],
        ),
      ),
    );
  }
}

class _NavaidRow extends StatelessWidget {
  const _NavaidRow({required this.navaid});
  final Navaid navaid;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: context.col.background,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: context.col.border),
            ),
            alignment: Alignment.center,
            child: Text(navaid.typeDisplay,
                style: TextStyle(
                    color: context.col.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(navaid.ident,
                    style: TextStyle(
                        color: context.col.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace')),
                if (navaid.name.isNotEmpty)
                  Text(navaid.name,
                      style: TextStyle(
                          color: context.col.textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(navaid.frequencyDisplay,
                  style: TextStyle(
                      color: context.col.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace')),
              if (navaid.dmeFrequencyKhz != null)
                Text(navaid.dmeFrequencyDisplay,
                    style: TextStyle(
                        color: context.col.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Frequencies Section ───────────────────────────────────────────────────────

// Countries where public ATC listening is legally restricted.
// LiveATC does not provide feeds for these countries.
// Exported so signal_reception_card can use the same set.
const kRestrictedCountries = {
  'GB', 'DE', 'BE', 'FR', 'IS', 'IN', 'IT', 'NZ', 'ES',
};

class _FrequenciesSection extends StatelessWidget {
  const _FrequenciesSection({
    required this.frequencies,
    required this.loading,
    required this.icao,
    required this.isoCountry,
  });
  final List<Frequency> frequencies;
  final bool loading;
  final String icao;
  final String isoCountry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ATC Frequencies',
              style: TextStyle(
                  color: context.col.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          const DisclaimerBanner(),
          const SizedBox(height: 12),
          if (loading)
            Center(
                child: CircularProgressIndicator(color: context.col.accent))
          else if (frequencies.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.col.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.col.border, width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: context.col.textMuted, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No frequency data available for this airport.',
                      style: TextStyle(
                          color: context.col.textSecondary, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _ContributeLink(icao: icao),
          ] else ...[
            ...frequencies.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FrequencyCard(frequency: f),
                )),
            const SizedBox(height: 4),
            _ContributeLink(icao: icao),
          ],
        ],
      ),
    );
  }
}

// ── Contribute link ───────────────────────────────────────────────────────────

class _ContributeLink extends StatelessWidget {
  const _ContributeLink({required this.icao});
  final String icao;

  Future<void> _launch() async {
    final uri = Uri.parse('https://ourairports.com/airports/$icao/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _launch,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_outlined, size: 11, color: context.col.textMuted),
          const SizedBox(width: 4),
          Text(
            'Missing a frequency? Add it at ourairports.com',
            style: TextStyle(
              color: context.col.textMuted,
              fontSize: 11,
              decoration: TextDecoration.underline,
              decorationColor: context.col.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── LiveATC button ────────────────────────────────────────────────────────────

class _LiveAtcButton extends StatelessWidget {
  const _LiveAtcButton({required this.icao, required this.restricted});
  final String icao;
  final bool restricted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => restricted ? _showRestrictedDialog(context) : _launch(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: restricted
              ? context.col.textMuted.withAlpha(20)
              : context.col.accent.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: restricted
                ? context.col.border
                : context.col.accent.withAlpha(120),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.headphones_rounded,
              size: 14,
              color: restricted ? context.col.textMuted : context.col.accent,
            ),
            const SizedBox(width: 5),
            Text(
              'Listen on LiveATC.net',
              style: TextStyle(
                color: restricted ? context.col.textMuted : context.col.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (restricted) ...[
              const SizedBox(width: 4),
              Icon(Icons.info_outline_rounded,
                  size: 12, color: context.col.textMuted),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _launch(BuildContext context) async {
    MetricsService.instance.trackFeature('liveatc_launched');
    final uri = Uri.parse(
        'https://www.liveatc.net/search/?icao=${icao.toUpperCase()}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Could not open LiveATC'),
          backgroundColor: context.col.card,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _showRestrictedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.col.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.gavel_rounded, color: ctx.col.accent, size: 22),
            const SizedBox(width: 10),
            Text('Not Available',
                style: TextStyle(
                    color: ctx.col.textPrimary, fontSize: 17)),
          ],
        ),
        content: Text(
          'Live ATC listening is legally restricted in this country. '
          'LiveATC.net does not provide feeds here in accordance with local communications law.',
          style: TextStyle(
              color: ctx.col.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.col.accent),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
