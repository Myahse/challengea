import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_store.dart';
import '../geo.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/friend_profile_sheet.dart';
import '../widgets/map_views.dart';
import 'call_screen.dart';
import 'chat_screen.dart';

/// Real map in the installed app; drawn map in the web prototype link.
/// Force the real map on the web with `--dart-define=REAL_MAP=true`.
const useRealMapByDefault = bool.fromEnvironment(
  'REAL_MAP',
  defaultValue: !kIsWeb,
);

/// Figma: map frame (node 4:74) + friend card (node 15:124).
/// Works like Snap Map: friends appear where they are, tap one to fly to
/// them and open their card over the map.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.store,
    this.useRealMap = useRealMapByDefault,
  });
  final ChatStore store;
  final bool useRealMap;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = GlobalKey<FriendMapState>();
  FriendSpot? _selected;
  FriendSpot? _route;

  ChatStore get store => widget.store;

  void _select(FriendSpot spot) {
    HapticFeedback.selectionClick();
    setState(() => _selected = spot);
    _map.currentState?.focusSpot(spot);
  }

  void _close() => setState(() => _selected = null);

  double _distanceKm(FriendSpot s) {
    if (widget.useRealMap) {
      return distanceKm(store.myLocation ?? marcory, s.latLng);
    }
    return (s.position - store.myPosition).distance *
        3 /
        1000; // drawn map: 3 m per pixel
  }

  void _openChat(Person p) {
    final node = store.nodeFor(p);
    store.markRead(node);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(store: store, node: node),
      ),
    );
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text, style: tx(14, color: Colors.white)),
        ),
      );
  }

  void _showRoute(FriendSpot s) {
    setState(() {
      _route = s;
      _selected = null;
    });
    _map.currentState?.focusRoute(s);
    _snack(
      'Route to ${s.person.firstName}: ${_distanceKm(s).toStringAsFixed(1)} km',
    );
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => ListenableBuilder(
        listenable: store,
        builder: (ctx, _) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Map settings', style: tx(18, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off_outlined),
                title: Text(
                  'Ghost mode',
                  style: tx(16, weight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Friends can’t see where you are',
                  style: tx(13, color: AppColors.muted),
                ),
                value: store.ghostMode,
                onChanged: store.setGhostMode,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.people_outline),
                title: Text(
                  'Show offline friends',
                  style: tx(16, weight: FontWeight.w600),
                ),
                subtitle: Text(
                  'With their last known place',
                  style: tx(13, color: AppColors.muted),
                ),
                value: store.showOffline,
                onChanged: store.setShowOffline,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final spots = store.spots
              .where((s) => s.online || store.showOffline)
              .toList();
          return Stack(
            children: [
              Positioned.fill(
                child: widget.useRealMap
                    ? RealFriendMap(
                        key: _map,
                        store: store,
                        spots: spots,
                        selected: _selected,
                        route: _route,
                        onSelect: _select,
                        onLocationUnavailable: () => _snack(
                          'Location is off: showing a demo position in Marcory, Abidjan',
                        ),
                      )
                    : DrawnFriendMap(
                        key: _map,
                        store: store,
                        spots: spots,
                        selected: _selected,
                        route: _route,
                        onSelect: _select,
                      ),
              ),
              _topBar(context),
              if (_selected != null) _sheet(_selected!),
            ],
          );
        },
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 10;
    final sel = _selected;
    return Positioned(
      left: 0,
      right: 0,
      top: top,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Me: tap to come back to my position.
            GestureDetector(
              onTap: () {
                setState(() => _route = null);
                _map.currentState?.focusMe();
              },
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: PersonAvatar(store.me, diameter: 42),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      store.ghostMode ? 'Ghost' : 'Online',
                      style: tx(
                        10,
                        weight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: sel == null
                    ? const SizedBox.shrink()
                    : Column(
                        key: ValueKey(sel.person.id),
                        children: [
                          PersonAvatar(sel.person, diameter: 44, border: 3),
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  sel.person.firstName,
                                  style: tx(15, weight: FontWeight.w800),
                                ),
                                Text(
                                  sel.online
                                      ? 'Online · ${sel.place}'
                                      : 'Seen ${sel.updated}',
                                  style: tx(9, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 1,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _openFilters,
                child: const SizedBox(
                  width: 46,
                  height: 46,
                  child: Icon(Icons.tune_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheet(FriendSpot s) {
    final mutuals = store.spots.where((o) => !identical(o, s)).take(3).toList();
    return Positioned.fill(
      child: NotificationListener<DraggableScrollableNotification>(
        onNotification: (n) {
          if (n.extent <= .05) _close();
          return false;
        },
        child: TweenAnimationBuilder<double>(
          key: ValueKey(s.person.id),
          tween: Tween(begin: 1, end: 0),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          builder: (context, v, child) =>
              FractionalTranslation(translation: Offset(0, v), child: child),
          child: DraggableScrollableSheet(
            initialChildSize: .56,
            minChildSize: 0,
            maxChildSize: .86,
            snap: true,
            snapSizes: const [.56],
            builder: (context, scroll) => FriendProfileSheet(
              spot: s,
              distanceKm: _distanceKm(s),
              mutuals: mutuals,
              scroll: scroll,
              onMessage: () => _openChat(s.person),
              onCall: () =>
                  CallScreen.open(context, store, store.startCall([s.person])),
              onChallenge: () => _snack(
                'Challenge ${s.person.firstName} to a game: coming with the games',
              ),
              onRoute: () => _showRoute(s),
              miniMap: widget.useRealMap
                  ? RealMiniMap(key: ValueKey(s.person.id), center: s.latLng)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
