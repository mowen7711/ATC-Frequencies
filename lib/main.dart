import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'constants.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'screens/loading_screen.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise background service config (does not start it)
  BackgroundService.init();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ATCFreqApp());
}

class ATCFreqApp extends StatelessWidget {
  const ATCFreqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: MaterialApp(
        title: 'ATC Frequencies',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const _Root(),
        // Named route so the notification tap can deep-link to Nearby tab
        routes: {
          '/nearby': (_) => const HomeScreen(initialTab: 1),
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kBackground,
      colorScheme: const ColorScheme.dark(
        primary: kAccent,
        secondary: kAccent,
        surface: kSurface,
        onPrimary: Colors.black,
        onSurface: kTextPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kBackground,
        foregroundColor: kTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: kTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: kSurface,
        selectedItemColor: kAccent,
        unselectedItemColor: kTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kAccent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: kTextMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: kCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: kBorder, width: 0.5),
        ),
      ),
      dividerTheme: const DividerThemeData(color: kBorder, thickness: 0.5),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (provider.state == AppState.loading) {
          return LoadingScreen(
            status: provider.loadingStatus,
            progress: provider.loadingProgress,
          );
        }
        if (provider.state == AppState.error) {
          return _ErrorScreen(message: provider.globalError ?? 'Unknown error');
        }
        return const HomeScreen();
      },
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 64, color: kTextMuted),
              const SizedBox(height: 24),
              const Text('Could not load data',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kTextPrimary)),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: kTextSecondary, fontSize: 14)),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () =>
                    context.read<AppProvider>().forceRefresh(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
