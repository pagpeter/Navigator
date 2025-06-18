import 'dart:io';
import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlng/latlng.dart';
import 'package:image/image.dart';

class TileRenderer {
  final int tileSize = 256;



  /// Converts all polylines to lists of pixel-space (x, y) tuples
  List<List<(double, double)>> polylinesToWebMercator(List<Polyline> lines, int zoom) {
    List<List<(double, double)>> convertedLines = [];

    for (final line in lines) {
      List<(double, double)> convertedLine = [];

      for (final point in line.points) {
        convertedLine.add(latLongToWebMercator(point.latitude, point.longitude, zoom));
      }

      convertedLines.add(convertedLine);
    }

    return convertedLines;
  }

  /// Converts a lat/lon to Web Mercator pixel coordinates at the given zoom
  (double, double) latLongToWebMercator(double lat, double lon, int zoom) {
    final scale = tileSize * pow(2, zoom);
    lat = lat.clamp(-85.05112878, 85.05112878);
    double x = (lon + 180) / 360 * scale;
    double sinLat = sin(radians(lat));
    double y = (0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi)) * scale;
    return (x, y);
  }

  double radians(double deg) => deg * (pi / 180);


  /// Draws polylines onto a 256x256 tile at (tileX, tileY) and zoom level `zoom`
void drawPolylinesToTile({
  required List<List<(double, double)>> polylines,
  required int tileX,
  required int tileY,
  required int zoom,
  required String outputPath,
}) {

  final img = Image(width: tileSize, height: tileSize);
  fill(img, color: ColorRgba8(0, 0, 0, 0)); // white background (or transparent)

  final originX = tileX * tileSize;
  final originY = tileY * tileSize;

  for (final polyline in polylines) {
    for (int i = 0; i < polyline.length - 1; i++) {
      final (x1, y1) = polyline[i];
      final (x2, y2) = polyline[i + 1];

      // Convert global pixel to local tile pixel
      final localX1 = (x1 - originX).round();
      final localY1 = (y1 - originY).round();
      final localX2 = (x2 - originX).round();
      final localY2 = (y2 - originY).round();

      // Skip lines outside the tile
      if (!_lineIntersectsTile(localX1, localY1, localX2, localY2, tileSize)) {
        continue;
      }

      drawLine(img, x1: localX1, y1: localY1, x2:localX2, y2:localY2, color: ColorRgba8(0, 0, 0, 0), antialias: true);
    }
  }

  final png = encodePng(img);
  File(outputPath).writeAsBytesSync(png);
}

bool _lineIntersectsTile(int x1, int y1, int x2, int y2, int size) {
  final minX = min(x1, x2);
  final maxX = max(x1, x2);
  final minY = min(y1, y2);
  final maxY = max(y1, y2);
  return maxX >= 0 && minX < size && maxY >= 0 && minY < size;
}


}
