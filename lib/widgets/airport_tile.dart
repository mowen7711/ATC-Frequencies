import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/airport.dart';

class AirportTile extends StatelessWidget {
  const AirportTile({
    super.key,
    required this.airport,
    required this.isFavourite,
    required this.onTap,
    required this.onFavouriteTap,
    this.distanceKm,
  });

  final Airport airport;
  final bool isFavourite;
  final VoidCallback onTap;
  final VoidCallback onFavouriteTap;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder, width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Type indicator strip
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: _typeColor(airport.type),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // Code badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: kBorder),
                ),
                child: Text(
                  airport.displayCode,
                  style: const TextStyle(
                    color: kAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name and location
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      airport.name,
                      style: const TextStyle(
                        color: kTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (airport.locationString.isNotEmpty) ...[
                          Flexible(
                            child: Text(
                              airport.locationString,
                              style: const TextStyle(
                                color: kTextSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        if (distanceKm != null) ...[
                          if (airport.locationString.isNotEmpty)
                            const Text(' · ',
                                style: TextStyle(
                                    color: kTextMuted, fontSize: 12)),
                          Text(
                            _formatDist(distanceKm!),
                            style: const TextStyle(
                              color: kAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Favourite button
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    isFavourite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    key: ValueKey(isFavourite),
                    color: isFavourite ? kAccent : kTextMuted,
                    size: 22,
                  ),
                ),
                onPressed: onFavouriteTap,
                splashRadius: 20,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'large_airport':
        return kAccent;
      case 'medium_airport':
        return const Color(0xFF64B5F6);
      case 'small_airport':
        return const Color(0xFF81C784);
      case 'heliport':
        return const Color(0xFFCE93D8);
      case 'seaplane_base':
        return const Color(0xFF4DD0E1);
      default:
        return kTextMuted;
    }
  }

  String _formatDist(double km) {
    if (km < 1) return '${(km * 1000).toInt()} m';
    return '${km.toStringAsFixed(1)} km';
  }
}
