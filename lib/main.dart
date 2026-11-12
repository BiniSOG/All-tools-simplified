import 'package:flutter/material.dart';

import 'core/store.dart';
import 'core/theme.dart';
import 'core/ui.dart';
import 'registry.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.init();
  AppTheme.instance.load();
  runApp(ToolboxApp(streakExtended: Streak.touch()));
}

class ToolboxApp extends StatefulWidget {
  const ToolboxApp({super.key, this.streakExtended = false});
  final bool streakExtended;

  @override
  State<ToolboxApp> createState() => _ToolboxAppState();
}

class _ToolboxAppState extends State<ToolboxApp> {
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppTheme.instance,
    builder: (_, _) => MaterialApp(
      title: 'Utility Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.instance.build(Brightness.light),
      darkTheme: AppTheme.instance.build(Brightness.dark),
      themeMode: AppTheme.instance.mode,
      home: HomePage(streakExtended: widget.streakExtended),
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.streakExtended = false});
  final bool streakExtended;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.streakExtended) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) toast(context, '🔥 ${Streak.days}-day streak! Keep it up');
      });
    }
  }

  Future<void> _open(ToolDef t) async {
    final recent = Store.list('recent')
      ..remove(t.id)
      ..insert(0, t.id);
    Store.setList('recent', recent.take(4).toList());
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ToolPage(t)));
    if (mounted) setState(() {}); // refresh favourites, recents and best scores
  }

  List<ToolDef> _byIds(List<String> ids) => [for (final i in ids) toolById(i)].whereType<ToolDef>().toList();

  Widget _grid(List<ToolDef> tools) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    sliver: SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 112, mainAxisExtent: 104, mainAxisSpacing: 4, crossAxisSpacing: 4),
      delegate: SliverChildBuilderDelegate((_, i) => _Tile(tools[i], () => _open(tools[i])), childCount: tools.length),
    ),
  );

  Widget _header(String text) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );

  Widget _note(String text) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final q = _search.text.trim().toLowerCase();
    final slivers = <Widget>[];

    if (q.isNotEmpty) {
      final hits = allTools.where((t) => '${t.name} ${t.tags}'.toLowerCase().contains(q)).toList();
      slivers.add(_header('Results'));
      slivers.add(hits.isEmpty ? _note('Nothing matches “$q”.') : _grid(hits));
    } else {
      // Game of the day: the same pick all day, rotating daily, with a nudge to beat your best.
      final games = allTools.where((t) => t.cat == 'games').toList();
      final pick = games[DateTime.now().difference(DateTime(2024)).inDays % games.length];
      final best = Scores.best(pick.id);
      slivers.add(
        SliverToBoxAdapter(
          child: Card(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            color: cs.secondaryContainer,
            child: ListTile(
              leading: Icon(pick.icon, color: cs.primary, size: 32),
              title: Text(
                'Game of the day: ${pick.name}',
                style: TextStyle(color: cs.onSecondaryContainer, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(best == null ? 'You have not played this one yet. Set a first score!' : 'Your best: $best. Can you beat it today?', style: TextStyle(color: cs.onSecondaryContainer)),
              trailing: Icon(Icons.play_arrow, color: cs.primary),
              onTap: () => _open(pick),
            ),
          ),
        ),
      );
      final favs = _byIds(Store.list('favs'));
      slivers.add(_header('★ Favorites'));
      slivers.add(favs.isEmpty ? _note('Open a tool and tap ☆ to pin it here.') : _grid(favs));
      final recent = _byIds(Store.list('recent'));
      if (recent.isNotEmpty) {
        slivers.add(_header('Recently used'));
        slivers.add(_grid(recent));
      }
      for (final c in categories.entries) {
        slivers.add(_header(c.value));
        slivers.add(_grid(allTools.where((t) => t.cat == c.key).toList()));
      }
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(child: Text('Works offline · Best streak: ${Streak.best} ${Streak.best == 1 ? 'day' : 'days'}', style: const TextStyle(fontSize: 12))),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Utility Hub'),
        actions: [
          Chip(
            avatar: const Icon(Icons.local_fire_department, color: Colors.deepOrange, size: 18),
            label: Text('${Streak.days} ${Streak.days == 1 ? 'day' : 'days'}'),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
            tooltip: dark ? 'Light mode' : 'Dark mode',
            onPressed: () => AppTheme.instance.setMode(dark ? ThemeMode.light : ThemeMode.dark),
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Appearance',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search ${allTools.length} tools and games',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: q.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), tooltip: 'Clear', onPressed: () => setState(_search.clear)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ),
            Expanded(child: CustomScrollView(slivers: slivers)),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.tool, this.onTap);
  final ToolDef tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: tool.color,
            child: Icon(tool.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(tool.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    ),
  );
}

/// Frame around a single tool: title bar, favourite star, and the tool itself.
class ToolPage extends StatefulWidget {
  const ToolPage(this.tool, {super.key});
  final ToolDef tool;

  @override
  State<ToolPage> createState() => _ToolPageState();
}

class _ToolPageState extends State<ToolPage> {
  bool get _fav => Store.list('favs').contains(widget.tool.id);

  void _toggleFav() {
    final was = _fav;
    final favs = Store.list('favs');
    was ? favs.remove(widget.tool.id) : favs.add(widget.tool.id);
    Store.setList('favs', favs);
    setState(() {});
    toast(context, was ? 'Removed from favorites' : 'Added to favorites');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.tool.name),
      actions: [IconButton(icon: Icon(_fav ? Icons.star : Icons.star_border), tooltip: _fav ? 'Remove from favorites' : 'Add to favorites', onPressed: _toggleFav)],
    ),
    body: SafeArea(child: widget.tool.builder()),
  );
}
