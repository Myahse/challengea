import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:latlong2/latlong.dart';

/// Demo friends live around Marcory, Abidjan.
const marcory = LatLng(5.3005, -3.9845);

/// Converts a point of the drawn demo map (3 m per pixel, centered on the
/// demo "me" at 700,1010) to real coordinates, so the same demo friends can
/// be shown on the real map.
LatLng drawnToLatLng(Offset p) {
  const metersPerPixel = 3.0;
  final dLat = -(p.dy - 1010) * metersPerPixel / 111320;
  final dLng =
      (p.dx - 700) *
      metersPerPixel /
      (111320 * cos(marcory.latitude * pi / 180));
  return LatLng(marcory.latitude + dLat, marcory.longitude + dLng);
}

double distanceKm(LatLng a, LatLng b) => const Distance().distance(a, b) / 1000;
