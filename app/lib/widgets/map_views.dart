import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../chat_store.dart';
import '../theme.dart';
import '../geo.dart';
import 'city_map.dart';
import 'map_markers.dart';

/// What the map screen needs from a map, whichever one is shown.
abstract class FriendMapState<T extends FriendMapView> extends State<T> {
  /// Moves the camera so [spot] sits in the visible part above the card.
  void focusSpot(FriendSpot spot);

  /// Moves the camera back to me.
  void focusMe();

  /// Frames both me and [spot] (used with the route line).
  void focusRoute(FriendSpot spot);
}

abstract class FriendMapView extends StatefulWidget {
  const FriendMapView({
    super.key,
    required this.store,
    required this.spots,
    required this.selected,
    required this.route,
    required this.onSelect,
  });
  final ChatStore store;
  final List<FriendSpot> spots;
  final FriendSpot? selected;
  final FriendSpot? route;
  final void Function(FriendSpot) onSelect;
}

// ===================================================================== drawn
/// Map drawn in code: used by the web prototype link (it cannot load tiles).
class DrawnFriendMap extends FriendMapView {
  const DrawnFriendMap({
    super.key,
    required super.store,
    required super.spots,
    required super.selected,
    required super.route,
    required super.onSelect,
  });

  @override
  State<DrawnFriendMap> createState() => DrawnFriendMapState();
}

class DrawnFriendMapState extends FriendMapState<DrawnFriendMap>
    with SingleTickerProviderStateMixin {
  final _camera = TransformationController();
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  Animation<Matrix4>? _tween;
  Size _viewport = Size.zero;
  bool _placed = false;

  Offset get _me => widget.store.myPosition;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      if (_tween != null) _camera.value = _tween!.value;
    });
  }

  @override
  void dispose() {
    _camera.dispose();
    _anim.dispose();
    super.dispose();
  }

  Matrix4 _matrixFor(Offset world, double scale, double anchorY) {
    final w = CityMapPainter.world;
    final t =
        Offset(_viewport.width / 2, _viewport.height * anchorY) - world * scale;
    return Matrix4.identity()
      ..translateByDouble(
        t.dx.clamp(_viewport.width - w.width * scale, 0.0),
        t.dy.clamp(_viewport.height - w.height * scale, 0.0),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _fly(Offset world, double scale, double anchorY) {
    _tween = Matrix4Tween(
      begin: _camera.value,
      end: _matrixFor(world, scale, anchorY),
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOutCubic));
    _anim.forward(from: 0);
  }

  @override
  void focusSpot(FriendSpot spot) =>
      _fly(spot.position, max(_camera.value.getMaxScaleOnAxis(), 1.1), .24);

  @override
  void focusMe() => _fly(_me, .8, .5);

  @override
  void focusRoute(FriendSpot spot) =>
      _fly(Offset.lerp(_me, spot.position, .5)!, .9, .5);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        _viewport = c.biggest;
        if (!_placed && !_viewport.isEmpty) {
          _placed = true;
          _camera.value = _matrixFor(_me, .8, .5);
        }
        final route = widget.route;
        return InteractiveViewer(
          transformationController: _camera,
          constrained: false,
          minScale: .5,
          maxScale: 2.5,
          onInteractionStart: (_) => _anim.stop(),
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
                if (route != null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RoutePainter(_me, route.position),
                    ),
                  ),
                Positioned(
                  left: _me.dx - 45,
                  top: _me.dy - 45,
                  width: 90,
                  height: 90,
                  child: MeMarker(
                    me: widget.store.me,
                    ghost: widget.store.ghostMode,
                  ),
                ),
                for (final s in widget.spots)
                  Positioned(
                    left: s.position.dx - FriendPin.size / 2,
                    top: s.position.dy - FriendPin.size - 8,
                    child: FriendPin(
                      spot: s,
                      selected: identical(s, widget.selected),
                      onTap: () => widget.onSelect(s),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.from, this.to);
  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..lineTo(from.dx, to.dy) // one turn, like following the streets
      ..lineTo(to.dx, to.dy);
    final paint = Paint()
      ..color = routeColor
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

const routeColor = Color(0xFF3B82F6);

// ====================================================================== real
/// Real OpenStreetMap map with the phone's GPS position (installed app).
class RealFriendMap extends FriendMapView {
  const RealFriendMap({
    super.key,
    required super.store,
    required super.spots,
    required super.selected,
    required super.route,
    required super.onSelect,
    this.onLocationUnavailable,
  });

  /// Called once when the phone does not share its position.
  final VoidCallback? onLocationUnavailable;

  @override
  State<RealFriendMap> createState() => RealFriendMapState();
}

class RealFriendMapState extends FriendMapState<RealFriendMap>
    with SingleTickerProviderStateMixin {
  final _map = MapController();
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  bool _ready = false;
  StreamSubscription<Position>? _positions;

  ChatStore get store => widget.store;

  /// My real position, or the demo position in Marcory until GPS answers.
  LatLng get _me => store.myLocation ?? marcory;

  @override
  void initState() {
    super.initState();
    _startLocation();
  }

  @override
  void dispose() {
    _positions?.cancel();
    _anim.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _startLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _unavailable();
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _unavailable();
      }
      final first = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      store.setMyLocation(LatLng(first.latitude, first.longitude));
      if (_ready) focusMe();
      _positions = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
        ),
      ).listen((p) => store.setMyLocation(LatLng(p.latitude, p.longitude)));
    } catch (_) {
      _unavailable();
    }
  }

  void _unavailable() {
    if (mounted) widget.onLocationUnavailable?.call();
  }

  LatLng _centerFor(LatLng point, double zoom, double anchorY) {
    final cam = _map.camera;
    final px =
        cam.projectAtZoom(point, zoom) +
        Offset(0, (.5 - anchorY) * cam.nonRotatedSize.height);
    return cam.unprojectAtZoom(px, zoom);
  }

  void _fly(LatLng point, double zoom, double anchorY) {
    if (!_ready) return;
    final start = _map.camera;
    final end = _centerFor(point, zoom, anchorY);
    final lat = Tween(begin: start.center.latitude, end: end.latitude);
    final lng = Tween(begin: start.center.longitude, end: end.longitude);
    final z = Tween(begin: start.zoom, end: zoom);
    final curve = CurvedAnimation(parent: _anim, curve: Curves.easeInOutCubic);
    void tick() => _map.move(
      LatLng(lat.evaluate(curve), lng.evaluate(curve)),
      z.evaluate(curve),
    );
    _anim
      ..stop()
      ..reset();
    _anim.addListener(tick);
    _anim.forward().whenCompleteOrCancel(() => _anim.removeListener(tick));
  }

  @override
  void focusSpot(FriendSpot spot) =>
      _fly(spot.latLng, max(_map.camera.zoom, 16), .24);

  @override
  void focusMe() => _fly(_me, 15.5, .5);

  @override
  void focusRoute(FriendSpot spot) {
    final a = _me, b = spot.latLng;
    final km = distanceKm(a, b);
    // Rough zoom that fits both points on screen.
    final zoom = (16.8 - log(max(km, .2)) / ln2).clamp(3.0, 16.5);
    _fly(
      LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2),
      zoom,
      .5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: _me,
        initialZoom: 15.5,
        minZoom: 3,
        maxZoom: 19,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () => _ready = true,
        onPointerDown: (_, _) => _anim.stop(),
      ),
      children: [
        TileLayer(
          // Fine for development. A production app with many users needs its
          // own tile provider (OSM's public servers have a fair-use policy).
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          tileBuilder: AppColors.dark ? darkModeTileBuilder : null,
          userAgentPackageName: 'com.challengea.challengea',
          maxZoom: 19,
        ),
        if (route != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [
                  _me,
                  LatLng(route.latLng.latitude, _me.longitude),
                  route.latLng,
                ],
                color: routeColor,
                strokeWidth: 6,
                pattern: StrokePattern.dashed(segments: const [14, 10]),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: _me,
              width: 90,
              height: 90,
              child: MeMarker(me: store.me, ghost: store.ghostMode),
            ),
            for (final s in widget.spots)
              Marker(
                point: s.latLng,
                width: 96,
                height: 92,
                alignment: Alignment.topCenter,
                child: FriendPin(
                  spot: s,
                  selected: identical(s, widget.selected),
                  onTap: () => widget.onSelect(s),
                ),
              ),
          ],
        ),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }
}

/// Small non-interactive real map (address card in the friend profile).
class RealMiniMap extends StatelessWidget {
  const RealMiniMap({super.key, required this.center});
  final LatLng center;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 15,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            tileBuilder: AppColors.dark ? darkModeTileBuilder : null,
            userAgentPackageName: 'com.challengea.challengea',
          ),
        ],
      ),
    );
  }
}
