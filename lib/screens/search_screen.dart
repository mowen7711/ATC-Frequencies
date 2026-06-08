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
        title: Text('Search Airports'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Consumer<AppProvider>(
              builder: (context, provider, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onChanged,
                    autofocus: false,
                    style: TextStyle(color: context.col.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Airport name, ICAO, IATA, city, or frequency…',
                      prefixIcon: Icon(Icons.search_rounded, color: context.col.textMuted),
                      suffixIcon: _controller.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: context.col.textMuted),
                              onPressed: _clear,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _FreqFilterChip(
                    active: provider.hideNoFreq,
                    onTap: provider.toggleHideNoFreq,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          if (provider.searching) {
            return Center(
              child: CircularProgressIndicator(color: context.col.accent),
            );
          }

          final results = provider.searchResults;
          final query = _controller.text.trim();

          if (query.isEmpty) {
            return _SearchHint();
          }

          if (results.isEmpty) {
            return _NoResults(
                query: query, isFrequency: provider.isFrequencySearch);
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(16, provider.isFrequencySearch ? 0 : 12, 16, 24),
            itemCount: results.length + (provider.isFrequencySearch ? 1 : 0),
            separatorBuilder: (_, __) => SizedBox(height: 8),
            itemBuilder: (context, i) {
              if (provider.isFrequencySearch && i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                  child: Text(
                    '${results.length} airport${results.length == 1 ? '' : 's'} with a ${_controller.text.trim()} MHz frequency',
                    style: TextStyle(
                        color: context.col.textSecondary,
                        fontSize: 13),
                  ),
                );
              }
              final airport = results[provider.isFrequencySearch ? i - 1 : i];
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

// ── Frequency filter chip ─────────────────────────────────────────────────────

class _FreqFilterChip extends StatelessWidget {
  const _FreqFilterChip({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? context.col.accent : context.col.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? context.col.accent : context.col.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 12,
              color: active ? Colors.black : context.col.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              'With frequencies only',
              style: TextStyle(
                color: active ? Colors.black : context.col.textSecondary,
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
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
            Icon(Icons.travel_explore_rounded, size: 72, color: context.col.textMuted),
            SizedBox(height: 24),
            Text(
              'Search worldwide airports',
              style: TextStyle(
                  color: context.col.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'Search by name, ICAO, IATA or city.\nOr type a frequency like 121.5 to find\nall airports using that frequency.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: context.col.textSecondary, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query, required this.isFrequency});
  final String query;
  final bool isFrequency;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: context.col.textMuted),
            SizedBox(height: 20),
            Text(
              isFrequency
                  ? 'No airports found with a $query MHz frequency'
                  : 'No airports found for "$query"',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: context.col.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 10),
            Text(
              isFrequency
                  ? 'Check the frequency is correct,\ne.g. 118.1 or 121.500'
                  : 'Try the ICAO code (e.g. EGLL)\nor shorten the search term.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.col.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
