import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
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
            backgroundColor: kCard,
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Frequency notification removed'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: kCard,
          duration: Duration(seconds: 2),
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
          backgroundColor: kCard,
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
                // ATC frequencies first — primary use-case
                _FrequenciesSection(
                  frequencies: _frequencies,
                  loading: _loadingFreqs,
                ),
                const SizedBox(height: 16),
                // Combined airport info + runways + navaids
                _AirportInfoSection(
                  airport: airport,
                  runways: _runways,
                  navaids: _navaids,
                  loading: _loadingFreqs,
                ),
                const SizedBox(height: 16),
                // Signal reception at the bottom — secondary tool
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: SignalReceptionCard(airport: airport),
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
      backgroundColor: kBackground,
      foregroundColor: kTextPrimary,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            airport.name,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            [airport.ident, if (airport.iataCode.isNotEmpty) airport.iataCode]
                .join(' · '),
            style: const TextStyle(
                fontSize: 12, color: kAccent, fontWeight: FontWeight.w600),
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
              color: _isPinned ? kAccent : kTextSecondary,
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
                  color: isHome ? kAccent : kTextSecondary,
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
              color: _isFav ? kAccent : kTextSecondary,
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
                  color: kAccent,
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
          // ── Airport details card ─────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder, width: 0.5),
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
                      _infoRow(Icons.airplanemode_active_rounded,
                          kAirportTypeLabels[airport.type] ?? airport.type),
                      if (airport.municipality.isNotEmpty ||
                          airport.isoCountry.isNotEmpty)
                        _infoRow(Icons.location_on_rounded,
                            airport.locationString),
                      if (airport.elevationFt != null)
                        _infoRow(Icons.terrain_rounded,
                            '${airport.elevationFt} ft  ·  '
                            '${(airport.elevationFt! * 0.3048).round()} m elevation'),
                      if (airport.iataCode.isNotEmpty)
                        _infoRow(Icons.confirmation_number_outlined,
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
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(color: kAccent)),
                  )
                else if (runways.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Text('No runway data available.',
                        style: TextStyle(color: kTextMuted, fontSize: 13)),
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

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: kAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: kTextPrimary, fontSize: 13)),
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
        style: const TextStyle(
          color: kAccent,
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
            const Icon(Icons.my_location_rounded, size: 16, color: kAccent),
            const SizedBox(width: 10),
            Text(coord,
                style: const TextStyle(
                    color: kTextSecondary,
                    fontSize: 13,
                    fontFamily: 'monospace')),
            const SizedBox(width: 8),
            const Icon(Icons.copy_rounded, size: 12, color: kTextMuted),
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
              color: kBackground,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: kBorder),
            ),
            alignment: Alignment.center,
            child: Text(navaid.typeDisplay,
                style: const TextStyle(
                    color: kAccent,
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
                    style: const TextStyle(
                        color: kTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace')),
                if (navaid.name.isNotEmpty)
                  Text(navaid.name,
                      style: const TextStyle(
                          color: kTextSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(navaid.frequencyDisplay,
                  style: const TextStyle(
                      color: kTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace')),
              if (navaid.dmeFrequencyKhz != null)
                Text(navaid.dmeFrequencyDisplay,
                    style: const TextStyle(
                        color: kTextMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Frequencies Section ───────────────────────────────────────────────────────

class _FrequenciesSection extends StatelessWidget {
  const _FrequenciesSection(
      {required this.frequencies, required this.loading});
  final List<Frequency> frequencies;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ATC Frequencies',
              style: TextStyle(
                  color: kTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (loading)
            const Center(
                child: CircularProgressIndicator(color: kAccent))
          else if (frequencies.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder, width: 0.5),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: kTextMuted, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No frequency data available for this airport.',
                      style:
                          TextStyle(color: kTextSecondary, fontSize: 14),
                    ),
                  ),
                ],
              ),
            )
          else
            ...frequencies.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FrequencyCard(frequency: f),
                )),
        ],
      ),
    );
  }
}
