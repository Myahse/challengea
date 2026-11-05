import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/city_map.dart';
import '../widgets/friend_profile_sheet.dart';
import 'chat_screen.dart';

/// Figma: map frame (node 4:74) + friend card (node 15:124).
/// Works like Snap Map: friends appear where they are, tap one to fly to
/// them and open their card over the map.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.store});
  final ChatStore store;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final _camera = TransformationController();
  late final _cameraAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();
  Animation<Matrix4>? _cameraTween;
  Size _viewport = Size.zero;
  bool _placed = false;

  FriendSpot? _selected;
  FriendSpot? _route; // friend we show a route to

  ChatStore get store => widget.store;
  static const _metersPerPixel = 3.0;

  @override
  void initState() {
    super.initState();
    _cameraAnim.addListener(() {
      if (_cameraTween != null) _camera.value = _cameraTween!.value;
    });
  }

  @override
  void dispose() {
    _camera.dispose();
    _cameraAnim.dispose();
    _pulse.dispose();
    super.dispose();
  }

  double get _scale => _camera.value.getMaxScaleOnAxis();

  Matrix4 _matrixFor(Offset world, double scale, double anchorY) {
    final w = CityMapPainter.world;
    final target = Offset(_viewport.width / 2, _viewport.height * anchorY);
    final t = target - world * scale;
    final tx = t.dx.clamp(_viewport.width - w.width * scale, 0.0);
    final ty = t.dy.clamp(_viewport.height - w.height * scale, 0.0);
    return Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _flyTo(Offset world, {double? scale, double anchorY = .45}) {
    final s = scale ?? max(_scale, 1.1);
    _cameraTween =
        Matrix4Tween(
          begin: _camera.value,
          end: _matrixFor(world, s, anchorY),
        ).animate(
          CurvedAnimation(parent: _cameraAnim, curve: Curves.easeInOutCubic),
        );
    _cameraAnim.forward(from: 0);
  }

  void _select(FriendSpot spot) {
    HapticFeedback.selectionClick();
    setState(() => _selected = spot);
    _flyTo(spot.position, anchorY: .24);
  }

  void _close() => setState(() => _selected = null);

  double _distanceKm(FriendSpot s) =>
      (s.position - store.myPosition).distance * _metersPerPixel / 1000;

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
    final mid = Offset.lerp(store.myPosition, s.position, .5)!;
    _flyTo(mid, scale: .9, anchorY: .5);
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
      body: LayoutBuilder(
        builder: (context, c) {
          _viewport = c.biggest;
          if (!_placed && !_viewport.isEmpty) {
            _placed = true;
            _camera.value = _matrixFor(store.myPosition, .8, .5);
          }
          return ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final spots = store.spots
                  .where((s) => s.online || store.showOffline)
                  .toList();
              return Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      transformationController: _camera,
                      constrained: false,
                      minScale: .5,
                      maxScale: 2.5,
                      onInteractionStart: (_) => _cameraAnim.stop(),
                      child: SizedBox.fromSize(
                        size: CityMapPainter.world,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Positioned.fill(
                              child: RepaintBoundary(
                                child: CustomPaint(painter: CityMapPainter()),
                              ),
                            ),
                            if (_route != null)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _RoutePainter(
                                    store.myPosition,
                                    _route!.position,
                                  ),
                                ),
                              ),
                            _me(),
                            for (final s in spots) _pin(s),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _topBar(context),
                  if (_selected != null) _sheet(_selected!),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- widgets
  Widget _me() {
    final p = store.myPosition;
    return Positioned(
      left: p.dx - 45,
      top: p.dy - 45,
      width: 90,
      height: 90,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => Stack(
            alignment: Alignment.center,
            children: [
              if (!store.ghostMode)
                Container(
                  width: 50 + 40 * _pulse.value,
                  height: 50 + 40 * _pulse.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(
                      0xFF3B82F6,
                    ).withValues(alpha: .35 * (1 - _pulse.value)),
                  ),
                ),
              store.ghostMode
                  ? Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: const Icon(
                        Icons.visibility_off_rounded,
                        color: AppColors.muted,
                      ),
                    )
                  : PersonAvatar(store.me, diameter: 50, border: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pin(FriendSpot s) {
    final selected = identical(s, _selected);
    const size = 62.0;
    return Positioned(
      left: s.position.dx - size / 2,
      top: s.position.dy - size - 8,
      child: GestureDetector(
        onTap: () => _select(s),
        child: AnimatedScale(
          scale: selected ? 1.2 : 1,
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.bottomCenter,
          child: Opacity(
            opacity: s.online ? 1 : .55,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: size,
                  height: size,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: selected
                        ? Border.all(color: AppColors.ink, width: 2)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.lerp(s.person.color, Colors.white, .45)!,
                            s.person.color,
                          ],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        s.person.initials,
                        style: tx(
                          26,
                          weight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    s.online
                        ? s.person.firstName
                        : '${s.person.firstName} · ${s.updated}',
                    style: tx(11, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                _flyTo(store.myPosition, scale: .8, anchorY: .5);
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
              onCall: () => _snack(
                'Calling ${s.person.firstName}… (calls come in the next step)',
              ),
              onChallenge: () => _snack(
                'Challenge ${s.person.firstName} to a game: coming with the games',
              ),
              onRoute: () => _showRoute(s),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed line from me to a friend.
class _RoutePainter extends CustomPainter {
  _RoutePainter(this.from, this.to);
  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    final corner = Offset(from.dx, to.dy); // follow the streets: one turn
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..lineTo(corner.dx, corner.dy)
      ..lineTo(to.dx, to.dy);
    final paint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 22) {
        canvas.drawPath(m.extractPath(d, min(d + 12, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.from != from || old.to != to;
}
