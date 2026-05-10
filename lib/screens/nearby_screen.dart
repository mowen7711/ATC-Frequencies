import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/airport.dart';
import '../providers/app_provider.dart';
import '../widgets/airport_tile.dart';
import 'airport_detail_screen.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  bool _mapView = false;
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final hasLocation = provider.nearbyLat != 0 || provider.nearbyLon != 0;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Nearby Airports'),
            actions: [
              if (hasLocation)
                IconButton(
                  icon: Icon(_mapView
                      ? Icons.list_rounded
                      : Icons.map_outlined),
                  tooltip: _mapView ? 'List view' : 'Map view',
                  onPressed: () => setState(() => _mapView = !_mapView),
                ),
              IconButton(
                icon: const Icon(Icons.my_location_rounded),
                tooltip: 'Find nearby airports',
                onPressed: () => provider.findNearby(),
              ),
            ],
            bottom: hasLocation
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(72),
                    child: _FilterBar(provider: provider),
                  )
                : null,
          ),
          body: _buildBody(provider),
        );
      },
    );
  }

  Widget _buildBody(AppProvider provider) {
    if (provider.loadingNearby) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: kAccent),
            SizedBox(height: 16),
            Text('Finding nearby airports…',
                style: TextStyle(color: kTextSecondary)),
          ],
        ),
      );
    }

    if (provider.nearbyError != null) {
      return _ErrorView(
        error: provider.nearbyError!,
        onRetry: provider.findNearby,
      );
    }

    final hasLocation = provider.nearbyLat != 0 || provider.nearbyLon != 0;
    if (!hasLocation) {
      return _NearbyHint(onTap: provider.findNearby);
    }

    if (provider.nearbyAirports.isEmpty) {
      return _EmptyNearby(
          radius: provider.nearbyRadius, onRefresh: provider.findNearby);
    }

    if (_mapView) {
      return _MapView(
        provider: provider,
        mapController: _mapController,
      );
    }

    return _ListView(provider: provider);
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.provider});
  final AppProvider provider;

  static const _radii = [10.0, 25.0, 50.0, 100.0, 200.0];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          const Text('Radius:', style: TextStyle(color: kTextSecondary, fontSize: 13)),
          const SizedBox(width: 12),
          ..._radii.map((r) {
            final selected = provider.nearbyRadius == r;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => provider.updateNearbyRadius(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: selected ? kAccent : kCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: selected ? kAccent : kBorder, width: 1),
                  ),
                  child: Text(
                    r >= 100 ? '${r.toInt()}km' : '${r.toInt()}km',
                    style: TextStyle(
                      color: selected ? Colors.black : kTextSecondary,
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── List view ─────────────────────────────────────────────────────────────────

class _ListView extends StatelessWidget {
  const _ListView({required this.provider});
  final AppProvider provider;

  @override
  Widget build(BuildContext context) {
    final airports = provider.nearbyAirports;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: airports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final (airport, dist) = airports[i];
        return FutureBuilder<bool>(
          future: provider.isFavourite(airport.ident),
          builder: (context, snap) {
            return AirportTile(
              airport: airport,
              isFavourite: snap.data ?? false,
              distanceKm: dist,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AirportDetailScreen(airport: airport),
                ),
              ),
              onFavouriteTap: () => provider.toggleFavourite(airport.ident),
            );
          },
        );
      },
    );
  }
}

// ── Map view ──────────────────────────────────────────────────────────────────

class _MapView extends StatelessWidget {
  const _MapView({required this.provider, required this.mapController});
  final AppProvider provider;
  final MapController mapController;

  @override
  Widget build(BuildContext context) {
    final userLatLng =
        LatLng(provider.nearbyLat, provider.nearbyLon);
    final airports = provider.nearbyAirports;

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: userLatLng,
        initialZoom: _zoomForRadius(provider.nearbyRadius),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.atcfreq.app',
        ),
        // User location marker
        MarkerLayer(markers: [
          Marker(
            point: userLatLng,
            width: 24,
            height: 24,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 4)
                ],
              ),
            ),
          ),
        ]),
        // Airport markers
        MarkerLayer(
          markers: airports.map((t) {
            final (airport, _) = t;
            if (!airport.hasCoordinates) return null;
            return Marker(
              point: LatLng(airport.latitude!, airport.longitude!),
              width: 36,
              height: 36,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AirportDetailScreen(airport: airport),
                  ),
                ),
                child: _AirportMarker(airport: airport),
              ),
            );
          }).whereType<Marker>().toList(),
        ),
      ],
    );
  }

  double _zoomForRadius(double km) {
    if (km <= 10) return 12;
    if (km <= 25) return 11;
    if (km <= 50) return 10;
    if (km <= 100) return 9;
    return 8;
  }
}

class _AirportMarker extends StatelessWidget {
  const _AirportMarker({required this.airport});
  final Airport airport;

  @override
  Widget build(BuildContext context) {
    final isLarge = airport.type == 'large_airport';
    final isMedium = airport.type == 'medium_airport';
    final color = isLarge
        ? kAccent
        : isMedium
            ? const Color(0xFF64B5F6)
            : kTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: kCard,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
      ),
      child: Icon(
        Icons.flight_rounded,
        color: color,
        size: isLarge ? 18 : 14,
      ),
    );
  }
}

// ── Empty / hint states ───────────────────────────────────────────────────────

class _NearbyHint extends StatelessWidget {
  const _NearbyHint({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.near_me_outlined, size: 72, color: kTextMuted),
            const SizedBox(height: 24),
            const Text('Find airports near you',
                style: TextStyle(
                    color: kTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text(
              'Tap the locate button to see airports\nwithin your selected radius.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: kTextSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('Find Nearby Airports'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNearby extends StatelessWidget {
  const _EmptyNearby({required this.radius, required this.onRefresh});
  final double radius;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.airplanemode_inactive_rounded,
                size: 64, color: kTextMuted),
            const SizedBox(height: 20),
            Text(
              'No airports within ${radius.toInt()} km',
              style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const Text(
              'Try increasing the radius above.',
              style: TextStyle(color: kTextSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_rounded, size: 64, color: kTextMuted),
            const SizedBox(height: 20),
            const Text('Location unavailable',
                style: TextStyle(
                    color: kTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(error,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: kTextSecondary, fontSize: 13)),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
