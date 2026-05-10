import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../providers/app_provider.dart';
import '../widgets/airport_tile.dart';
import '../widgets/home_airport_card.dart';
import '../widgets/update_banner.dart';
import 'search_screen.dart';
import 'nearby_screen.dart';
import 'settings_screen.dart';
import 'airport_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  static const _tabs = [
    _FavouritesTab(),
    NearbyScreen(),
    SearchScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _tabs),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const UpdateBanner(),
          BottomNavigationBar(
            currentIndex: _tab,
            onTap: (i) => setState(() => _tab = i),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.star_outline_rounded),
                activeIcon: Icon(Icons.star_rounded),
                label: 'Favourites',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.near_me_outlined),
                activeIcon: Icon(Icons.near_me_rounded),
                label: 'Nearby',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search_rounded),
                activeIcon: Icon(Icons.search_rounded),
                label: 'Search',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Favourites Tab ────────────────────────────────────────────────────────────

class _FavouritesTab extends StatelessWidget {
  const _FavouritesTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final favs = provider.favourites;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Icon(Icons.radio, color: kAccent, size: 22),
                const SizedBox(width: 10),
                const Text('ATC Frequencies'),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          body: CustomScrollView(
              slivers: [
                // Home airport always shown at top
                const SliverToBoxAdapter(child: HomeAirportCard()),

                // Favourites section header
                if (favs.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 16, 8),
                      child: Text('FAVOURITES',
                          style: TextStyle(
                              color: kAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2)),
                    ),
                  ),

                if (favs.isEmpty)
                  SliverToBoxAdapter(child: _EmptyFavourites())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: favs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final airport = favs[i];
                        return AirportTile(
                          airport: airport,
                          isFavourite: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AirportDetailScreen(airport: airport),
                            ),
                          ).then((_) => provider.loadFavourites()),
                          onFavouriteTap: () =>
                              provider.toggleFavourite(airport.ident),
                        );
                      },
                    ),
                  ),
              ],
            ),
        );
      },
    );
  }
}

class _EmptyFavourites extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_outline_rounded, size: 72, color: kTextMuted),
            const SizedBox(height: 24),
            const Text(
              'No favourites yet',
              style: TextStyle(
                  color: kTextPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Star airports in Search or Nearby\nto pin them here for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextSecondary, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
