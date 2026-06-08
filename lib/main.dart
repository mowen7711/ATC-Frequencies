import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'constants.dart';
import 'providers/app_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/splash_screen.dart';
import 'services/background_service.dart';
import 'services/frequency_notification_service.dart';
import 'services/metrics_service.dart';
import 'services/shake_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'widgets/bug_report_sheet.dart';
import 'widgets/disclaimer_dialog.dart';
import 'widgets/whats_new_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise background service config (does not start it)
  BackgroundService.init();

  // Initialise frequency display notification (restores if previously enabled)
  await FrequencyNotificationService.instance.init();

  // Initialise anonymous metrics (no-op if InfluxDB URL not configured)
  await MetricsService.instance.init();

  // Load persisted theme preference before the first frame
  final themeProvider = ThemeProvider();
  await themeProvider.init();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(ATCFreqApp(themeProvider: themeProvider));
}

class ATCFreqApp extends StatefulWidget {
  const ATCFreqApp({super.key, required this.themeProvider});
  final ThemeProvider themeProvider;

  @override
  State<ATCFreqApp> createState() => _ATCFreqAppState();
}

class _ATCFreqAppState extends State<ATCFreqApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MetricsService.instance.trackAppOpen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      MetricsService.instance.trackAppOpen();
    } else if (state == AppLifecycleState.paused) {
      MetricsService.instance.trackAppClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.themeProvider),
        ChangeNotifierProvider(create: (_) => AppProvider()..init()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'ATC Frequencies',
            debugShowCheckedModeBanner: false,
            theme: _lightTheme(),
            darkTheme: _darkTheme(),
            themeMode: themeProvider.themeMode,
            home: const _Root(),
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/nearby':
                  return MaterialPageRoute(
                    settings: settings,
                    builder: (_) => const HomeScreen(initialTab: 1),
                  );
              }
              return null;
            },
          );
        },
      ),
    );
  }

  ThemeData _darkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kBackground,
      colorScheme: const ColorScheme.dark(
        primary: kAccent,
        secondary: kAccent,
        surface: kBackground,
        onPrimary: Colors.black,
        onSurface: kTextPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kBackground,
        foregroundColor: kTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
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
    return base.copyWith(extensions: [AppColors.dark]);
  }

  ThemeData _lightTheme() {
    const lightAccent = Color(0xFFE6A000);
    const lightBackground = Color(0xFFF0F4F8);
    const lightSurface = Color(0xFFFFFFFF);
    const lightCard = Color(0xFFFFFFFF);
    const lightBorder = Color(0xFFD0DCE8);
    const lightTextPrimary = Color(0xFF0B1120);
    const lightTextSecondary = Color(0xFF4A6280);
    const lightTextMuted = Color(0xFF8EA4C0);

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: lightAccent,
        secondary: lightAccent,
        surface: lightBackground,
        onPrimary: Colors.white,
        onSurface: lightTextPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: lightAccent,
        unselectedItemColor: lightTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightAccent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: lightTextMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lightBorder, width: 0.5),
        ),
      ),
      dividerTheme:
          const DividerThemeData(color: lightBorder, thickness: 0.5),
    );
    return base.copyWith(extensions: [AppColors.light]);
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _splashVisible = true;
  bool _disclaimerTriggered = false;
  bool _whatsNewTriggered = false;

  @override
  void initState() {
    super.initState();
    ShakeService.instance.init(onShake: _onShake);
  }

  @override
  void dispose() {
    ShakeService.instance.dispose();
    super.dispose();
  }

  void _onShake() {
    final ctx = context;
    if (!mounted) return;
    // Don't show during splash or loading
    if (_splashVisible) return;
    showBugReportSheet(ctx);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.col.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Consumer<AppProvider>(
            builder: (context, provider, _) {
              if (provider.state == AppState.ready &&
                  !_splashVisible &&
                  provider.needsDisclaimer &&
                  !_disclaimerTriggered) {
                _disclaimerTriggered = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) showDisclaimerDialog(context, provider);
                });
              }
              // Show What's New after disclaimer (or immediately if no disclaimer)
              if (provider.state == AppState.ready &&
                  !_splashVisible &&
                  !provider.needsDisclaimer &&
                  !_whatsNewTriggered) {
                _whatsNewTriggered = true;
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!mounted) return;
                  final info = await PackageInfo.fromPlatform();
                  if (mounted) {
                    await maybeShowWhatsNew(context, info.version);
                  }
                });
              }
              if (provider.state == AppState.loading) {
                return LoadingScreen(
                  status: provider.loadingStatus,
                  progress: provider.loadingProgress,
                  runwayLabels: provider.runwayLabels,
                  eta: provider.estimatedTimeRemaining,
                );
              }
              if (provider.state == AppState.error) {
                return _ErrorScreen(message: provider.globalError ?? 'Unknown error');
              }
              return const HomeScreen();
            },
          ),
          if (_splashVisible)
            SplashScreen(
              onDone: () => setState(() => _splashVisible = false),
            ),
        ],
      ),
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
              Icon(Icons.wifi_off_rounded, size: 64, color: context.col.textMuted),
              const SizedBox(height: 24),
              Text('Could not load data',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: context.col.textPrimary)),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.col.textSecondary, fontSize: 14)),
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
