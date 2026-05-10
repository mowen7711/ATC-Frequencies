import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/airport.dart';
import '../models/frequency.dart';
import '../providers/app_provider.dart';
import '../services/frequency_notification_service.dart';
import '../widgets/frequency_card.dart';
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
    ]);
    if (mounted) {
      setState(() {
        _isFav = results[0] as bool;
        _frequencies = results[1] as List<Frequency>;
        _isPinned = (results[2] as String?) == widget.airport.ident &&
            true; // will be confirmed by isEnabled check below
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
                _InfoSection(airport: airport),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: SignalReceptionCard(airport: airport),
                ),
                const SizedBox(height: 8),
                _FrequenciesSection(
                  frequencies: _frequencies,
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

// ── Info Section ──────────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.airport});
  final Airport airport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row(Icons.airplanemode_active_rounded,
                  kAirportTypeLabels[airport.type] ?? airport.type),
              if (airport.municipality.isNotEmpty || airport.isoCountry.isNotEmpty)
                _row(Icons.location_on_rounded, airport.locationString),
              if (airport.elevationFt != null)
                _row(Icons.terrain_rounded,
                    '${airport.elevationFt} ft elevation'),
              if (airport.iataCode.isNotEmpty)
                _row(Icons.confirmation_number_outlined,
                    'IATA: ${airport.iataCode}'),
              _CoordRow(airport: airport),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 17, color: kAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style:
                    const TextStyle(color: kTextPrimary, fontSize: 14)),
          ),
        ],
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
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            const Icon(Icons.my_location_rounded, size: 17, color: kAccent),
            const SizedBox(width: 10),
            Text(coord,
                style: const TextStyle(
                    color: kTextPrimary, fontSize: 14, fontFamily: 'monospace')),
            const SizedBox(width: 8),
            const Icon(Icons.copy_rounded, size: 13, color: kTextMuted),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
