import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../providers/app_provider.dart';
import '../widgets/airport_tile.dart';
import 'airport_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    context.read<AppProvider>().search(q);
  }

  void _clear() {
    _controller.clear();
    context.read<AppProvider>().clearSearch();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Airports'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onChanged,
              autofocus: false,
              style: const TextStyle(color: kTextPrimary),
              decoration: InputDecoration(
                hintText: 'Airport name, ICAO, IATA, city…',
                prefixIcon: const Icon(Icons.search_rounded, color: kTextMuted),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: kTextMuted),
                        onPressed: _clear,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          if (provider.searching) {
            return const Center(
              child: CircularProgressIndicator(color: kAccent),
            );
          }

          final results = provider.searchResults;
          final query = _controller.text.trim();

          if (query.isEmpty) {
            return _SearchHint();
          }

          if (results.isEmpty) {
            return _NoResults(query: query);
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final airport = results[i];
              return FutureBuilder<bool>(
                future: provider.isFavourite(airport.ident),
                builder: (context, snap) {
                  final isFav = snap.data ?? false;
                  return AirportTile(
                    airport: airport,
                    isFavourite: isFav,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AirportDetailScreen(airport: airport),
                      ),
                    ).then((_) => setState(() {})),
                    onFavouriteTap: () async {
                      await provider.toggleFavourite(airport.ident);
                      if (mounted) setState(() {});
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore_rounded, size: 72, color: kTextMuted),
            const SizedBox(height: 24),
            const Text(
              'Search worldwide airports',
              style: TextStyle(
                  color: kTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Try "Heathrow", "EGLL", "LHR",\nor any city name.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: kTextSecondary, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: kTextMuted),
            const SizedBox(height: 20),
            Text(
              'No airports found for "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const Text(
              'Try the ICAO code (e.g. EGLL)\nor shorten the search term.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
