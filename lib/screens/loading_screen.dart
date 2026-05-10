import 'package:flutter/material.dart';
import '../constants.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({
    super.key,
    required this.status,
    required this.progress,
  });

  final String status;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo / icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: kAccent.withAlpha(25),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: kAccent.withAlpha(80), width: 1.5),
                ),
                child: const Icon(Icons.radio, color: kAccent, size: 38),
              ),
              const SizedBox(height: 40),
              const Text(
                'ATC Frequencies',
                style: TextStyle(
                  color: kTextPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Worldwide airport radio frequencies',
                style: TextStyle(color: kTextSecondary, fontSize: 15),
              ),
              const SizedBox(height: 48),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress < 1.0 ? progress : null,
                  backgroundColor: kBorder,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(kAccent),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                status,
                style: const TextStyle(
                  color: kTextSecondary,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Downloading ~9 MB of ICAO data on first launch.',
                style: TextStyle(
                  color: kTextMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
