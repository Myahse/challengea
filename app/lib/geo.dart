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

/// Inverse of [drawnToLatLng]: where a real position falls on the drawn map.
Offset latLngToDrawn(LatLng p) {
  const metersPerPixel = 3.0;
  final dy = -(p.latitude - marcory.latitude) * 111320 / metersPerPixel;
  final dx =
      (p.longitude - marcory.longitude) *
      111320 *
      cos(marcory.latitude * pi / 180) /
      metersPerPixel;
  return Offset(700 + dx, 1010 + dy);
}

double distanceKm(LatLng a, LatLng b) => const Distance().distance(a, b) / 1000;
