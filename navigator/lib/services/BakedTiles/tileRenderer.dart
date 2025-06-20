import 'dart:io';
import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlng/latlng.dart';
import 'package:image/image.dart' as imge;
import 'package:navigator/models/subway_line.dart';
import 'package:scidart/numdart.dart';
import 'dart:ui' as ui show Color;

class LineSegment {
  final double x1, y1, x2, y2;
  final SubwayLine subwayLine;

  LineSegment(this.x1, this.y1, this.x2, this.y2, this.subwayLine);

  double get length => sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));

  (double, double) get center => ((x1 + x2) / 2, (y1 + y2) / 2);

  double get angle => atan2(y2 - y1, x2 - x1);

  bool overlaps(LineSegment other, double threshold) {
    double angleDiff = (angle - other.angle).abs();
    if (angleDiff > pi / 2) angleDiff = pi - angleDiff;

    if (angleDiff > pi / 6) return false;

    double dist = _distanceToSegment(other);
    return dist < threshold;
  }

  double _distanceToSegment(LineSegment other) {
    double midX = (x1 + x2) / 2;
    double midY = (y1 + y2) / 2;
    double otherMidX = (other.x1 + other.x2) / 2;
    double otherMidY = (other.y1 + other.y2) / 2;

    return sqrt(pow(midX - otherMidX, 2) + pow(midY - otherMidY, 2));
  }
}

class LabelPlacement {
  final double x, y;
  final String text;
  final double angle;
  final SubwayLine subwayLine;
  final double width, height;

  LabelPlacement(
    this.x,
    this.y,
    this.text,
    this.angle,
    this.subwayLine,
    this.width,
    this.height,
  );

  bool overlaps(LabelPlacement other) {
    double dx = (x - other.x).abs();
    double dy = (y - other.y).abs();
    return dx < (width + other.width) / 2 + 5 &&
        dy < (height + other.height) / 2 + 5;
  }
}

class TileRenderer {
  final int tileSize = 256;
  final double lineWidth = 4.0; // Increased for better visibility
  final double parallelOffset = 5.0; // Increased spacing

  // Fixed Web Mercator projection
  (double, double) latLongToWebMercator(double lat, double lon, int zoom) {
    // Clamp latitude to valid Web Mercator range
    lat = lat.clamp(-85.0511, 85.0511);

    // Convert to radians
    final latRad = lat * pi / 180.0;

    // Web Mercator formulas
    final n = pow(2.0, zoom.toDouble());
    final x = (lon + 180.0) / 360.0 * n;
    final y = (1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0 * n;

    return (x * tileSize, y * tileSize);
  }

  // Convert tile coordinates back to lat/lon for debugging
  (double, double) tileToLatLong(int tileX, int tileY, int zoom) {
    final n = pow(2.0, zoom.toDouble());
    final lon = tileX / n * 360.0 - 180.0;
    final latRad = atan(sinh(pi * (1 - 2 * tileY / n)));
    final lat = latRad * 180.0 / pi;
    return (lat, lon);
  }

  double radians(double deg) => deg * (pi / 180);
  double degrees(double rad) => rad * (180 / pi);

  void drawSubwayLinesToTile({
    required List<SubwayLine> subwayLines,
    required int tileX,
    required int tileY,
    required int zoom,
    required String outputPath,
  }) {
    // Create image with proper transparent background
    final img = imge.Image(width: tileSize, height: tileSize);

    // CRITICAL FIX: Clear with fully transparent pixels
    imge.fill(img, color: imge.ColorRgba8(0, 0, 0, 0));

    final originX = tileX * tileSize.toDouble();
    final originY = tileY * tileSize.toDouble();

    print('Rendering tile ${tileX}/${tileY} at zoom $zoom');

    // Convert all subway lines to continuous paths instead of individual segments
    List<List<(double, double)>> allPaths = [];
    List<SubwayLine> pathLines = [];

    for (final subwayLine in subwayLines) {
      if (subwayLine.points.isEmpty) continue;

      List<(double, double)> path = [];
      bool hasValidPoints = false;

      for (final point in subwayLine.points) {
        final (worldX, worldY) = latLongToWebMercator(
          point.latitude,
          point.longitude,
          zoom,
        );
        final localX = worldX - originX;
        final localY = worldY - originY;

        path.add((localX, localY));

        // Check if any point is reasonably close to the tile
        if (localX >= -100 &&
            localX <= tileSize + 100 &&
            localY >= -100 &&
            localY <= tileSize + 100) {
          hasValidPoints = true;
        }
      }

      if (hasValidPoints && path.length >= 2) {
        allPaths.add(path);
        pathLines.add(subwayLine);
      }
    }

    print('Found ${allPaths.length} valid paths to render');

    if (allPaths.isEmpty) {
      print('No valid paths - creating empty tile');
      _savePngWithTransparency(img, outputPath);
      return;
    }

    // Group overlapping paths for parallel drawing
    Map<int, List<int>> overlappingGroups = _groupOverlappingPaths(
      allPaths,
      pathLines,
    );

    // Draw paths with parallel offsetting
    Set<int> processedPaths = {};

    for (int i = 0; i < allPaths.length; i++) {
      if (processedPaths.contains(i)) continue;

      List<int> group = overlappingGroups[i] ?? [i];
      _drawParallelPaths(
        img,
        group.map((idx) => allPaths[idx]).toList(),
        group.map((idx) => pathLines[idx]).toList(),
      );
      processedPaths.addAll(group);
    }

    // Add labels at higher zoom levels
    if (zoom >= 12) {
      List<LabelPlacement> labelPlacements = _calculateLabelPlacementsFromPaths(
        allPaths,
        pathLines,
        zoom,
      );
      _drawLabels(img, labelPlacements);
    }

    _savePngWithTransparency(img, outputPath);
    print('Generated tile: $outputPath');
  }

  // Fixed PNG saving with proper transparency
  void _savePngWithTransparency(imge.Image img, String outputPath) {
    // Ensure the image format supports transparency
    final supersampled = imge.copyResize(
      img,
      width: img.width ~/ 2,
      height: img.height ~/ 2,
      interpolation: imge.Interpolation.average,
    );
    final png = imge.encodePng(img);
    File(outputPath).writeAsBytesSync(png);
  }

  // Group overlapping paths for parallel rendering
  Map<int, List<int>> _groupOverlappingPaths(
    List<List<(double, double)>> paths,
    List<SubwayLine> lines,
  ) {
    Map<int, List<int>> groups = {};

    for (int i = 0; i < paths.length; i++) {
      if (groups.containsKey(i)) continue;

      List<int> group = [i];

      for (int j = i + 1; j < paths.length; j++) {
        if (_pathsOverlap(paths[i], paths[j], parallelOffset * 3)) {
          group.add(j);
        }
      }

      for (final idx in group) {
        groups[idx] = group;
      }
    }

    return groups;
  }

  // Check if two paths overlap significantly
  bool _pathsOverlap(
    List<(double, double)> path1,
    List<(double, double)> path2,
    double threshold,
  ) {
    // Sample points from both paths and check distances
    int samples = min(10, min(path1.length, path2.length));
    int overlapCount = 0;

    for (int i = 0; i < samples; i++) {
      int idx1 = (i * (path1.length - 1) / (samples - 1)).round();
      int idx2 = (i * (path2.length - 1) / (samples - 1)).round();

      final (x1, y1) = path1[idx1];
      final (x2, y2) = path2[idx2];

      double distance = sqrt(pow(x1 - x2, 2) + pow(y1 - y2, 2));
      if (distance < threshold) {
        overlapCount++;
      }
    }

    return overlapCount >= samples ~/ 2; // If at least half the samples overlap
  }

  // Draw multiple paths with parallel offsets
  void _drawParallelPaths(
    imge.Image img,
    List<List<(double, double)>> paths,
    List<SubwayLine> lines,
  ) {
    if (paths.length == 1) {
      _drawSinglePath(img, paths[0], lines[0], 0);
      return;
    }

    double totalWidth = (paths.length - 1) * parallelOffset;
    double startOffset = -totalWidth / 2;

    // Combine paths of the same group into a single visual stroke if lines share color
    final groupedByColor = <String, List<List<(double, double)>>>{};

    for (int i = 0; i < paths.length; i++) {
      final colorKey = lines[i].color.toString(); // key by color
      groupedByColor.putIfAbsent(colorKey, () => []).add(paths[i]);
    }

    for (final entry in groupedByColor.entries) {
      final color = lines[paths.indexOf(entry.value.first)].color;
      final merged = _mergePaths(
        entry.value,
      ); // You can write a simple line-averaging method if needed
      _drawPathAsPolygon(img, merged, _toRgba(color), lineWidth);
    }
  }

  // Draw a single path with proper line rendering
  void _drawSinglePath(
    imge.Image img,
    List<(double, double)> path,
    SubwayLine subwayLine,
    double offset,
  ) {
    if (path.length < 2) return;

    final ui.Color color = subwayLine.color;
    final imge.ColorRgba8 drawColor = _toRgba(color);

    List<(double, double)> offsetPath = offset != 0
        ? _applyOffsetToPath(path, offset)
        : path;

    // Clip each segment and collect the valid parts
    List<(double, double)> clippedPath = [];

    for (int i = 0; i < offsetPath.length - 1; i++) {
      final (x1, y1) = offsetPath[i];
      final (x2, y2) = offsetPath[i + 1];

      if (!_segmentIntersectsTile(x1, y1, x2, y2)) continue;

      final clipped = _clipLineToTile(x1, y1, x2, y2);
      if (clipped == null) continue;

      final (cx1, cy1, cx2, cy2) = clipped;
      clippedPath.add((cx1, cy1));
      clippedPath.add((cx2, cy2));
    }

    if (clippedPath.length >= 2) {
      _drawPathAsPolygon(img, clippedPath, drawColor, lineWidth);
    }
  }

  List<(double, double)> _mergePaths(List<List<(double, double)>> paths) {
  // TODO: sort paths, join endpoints if they touch
  final merged = <(double, double)>[];
  for (final path in paths) {
    if (merged.isNotEmpty && merged.last == path.first) {
      merged.addAll(path.skip(1));
    } else {
      merged.addAll(path);
    }
  }
  return merged;
}


  // Apply perpendicular offset to entire path
  List<(double, double)> _applyOffsetToPath(
    List<(double, double)> path,
    double offset,
  ) {
    List<(double, double)> offsetPath = [];

    for (int i = 0; i < path.length; i++) {
      final (x, y) = path[i];

      // Calculate perpendicular direction
      double perpX = 0, perpY = 0;

      if (i == 0 && path.length > 1) {
        // First point: use direction to next point
        final (nextX, nextY) = path[i + 1];
        double dx = nextX - x;
        double dy = nextY - y;
        double length = sqrt(dx * dx + dy * dy);
        if (length > 0) {
          perpX = -dy / length * offset;
          perpY = dx / length * offset;
        }
      } else if (i == path.length - 1) {
        // Last point: use direction from previous point
        final (prevX, prevY) = path[i - 1];
        double dx = x - prevX;
        double dy = y - prevY;
        double length = sqrt(dx * dx + dy * dy);
        if (length > 0) {
          perpX = -dy / length * offset;
          perpY = dx / length * offset;
        }
      } else {
        // Middle point: average of both directions
        final (prevX, prevY) = path[i - 1];
        final (nextX, nextY) = path[i + 1];

        double dx1 = x - prevX;
        double dy1 = y - prevY;
        double len1 = sqrt(dx1 * dx1 + dy1 * dy1);

        double dx2 = nextX - x;
        double dy2 = nextY - y;
        double len2 = sqrt(dx2 * dx2 + dy2 * dy2);

        double perpX1 = len1 > 0 ? -dy1 / len1 : 0;
        double perpY1 = len1 > 0 ? dx1 / len1 : 0;
        double perpX2 = len2 > 0 ? -dy2 / len2 : 0;
        double perpY2 = len2 > 0 ? dx2 / len2 : 0;

        perpX = (perpX1 + perpX2) / 2 * offset;
        perpY = (perpY1 + perpY2) / 2 * offset;
      }

      offsetPath.add((x + perpX, y + perpY));
    }

    return offsetPath;
  }

  // Draw thick line using the image package's drawLine function with custom thickness
  void _drawThickLine(
    imge.Image img,
    double x1,
    double y1,
    double x2,
    double y2,
    imge.ColorRgba8 color,
    double thickness,
  ) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final length = sqrt(dx * dx + dy * dy);
    if (length == 0) return; // avoid division by zero

    final ndx = dx / length;
    final ndy = dy / length;

    final offsetX = -ndy * (thickness / 2);
    final offsetY = ndx * (thickness / 2);

    // Define the corners of the thick line quad
    final p1 = imge.Point(x1 + offsetX, y1 + offsetY);
    final p2 = imge.Point(x1 - offsetX, y1 - offsetY);
    final p3 = imge.Point(x2 - offsetX, y2 - offsetY);
    final p4 = imge.Point(x2 + offsetX, y2 + offsetY);

    // Use the `fillPolygon()` method
    imge.fillPolygon(
      img,
      vertices: [
        imge.Point(p1.x.round(), p1.y.round()),
        imge.Point(p2.x.round(), p2.y.round()),
        imge.Point(p3.x.round(), p3.y.round()),
        imge.Point(p4.x.round(), p4.y.round()),
      ],
      color: color,
    );
  }

  void _drawPathAsPolygon(
    imge.Image img,
    List<(double, double)> path,
    imge.ColorRgba8 color,
    double thickness,
  ) {
    if (path.length < 2) return;

    final half = thickness / 2;
    final List<imge.Point> leftEdge = [];
    final List<imge.Point> rightEdge = [];

    for (int i = 0; i < path.length - 1; i++) {
      final (x1, y1) = path[i];
      final (x2, y2) = path[i + 1];

      final dx = x2 - x1;
      final dy = y2 - y1;
      final len = sqrt(dx * dx + dy * dy);
      if (len == 0) continue;

      final nx = -dy / len * half;
      final ny = dx / len * half;

      final leftStart = imge.Point((x1 + nx).round(), (y1 + ny).round());
      final rightStart = imge.Point((x1 - nx).round(), (y1 - ny).round());
      final leftEnd = imge.Point((x2 + nx).round(), (y2 + ny).round());
      final rightEnd = imge.Point((x2 - nx).round(), (y2 - ny).round());

      if (i == 0) {
        leftEdge.add(leftStart);
        rightEdge.add(rightStart);
      }

      leftEdge.add(leftEnd);
      rightEdge.add(rightEnd);
    }

    // Reverse rightEdge to create proper polygon
    final polygon = [...leftEdge, ...rightEdge.reversed];
    imge.fillPolygon(img, vertices: polygon, color: color);
  }

  // Improved segment intersection check
  bool _segmentIntersectsTile(double x1, double y1, double x2, double y2) {
    const padding = 20.0;
    final minX = min(x1, x2);
    final maxX = max(x1, x2);
    final minY = min(y1, y2);
    final maxY = max(y1, y2);

    return !(maxX < -padding ||
        minX > tileSize + padding ||
        maxY < -padding ||
        minY > tileSize + padding);
  }

  // Improved line clipping
  (double, double, double, double)? _clipLineToTile(
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    const margin = 20.0;
    final left = -margin;
    final right = tileSize.toDouble() + margin;
    final top = -margin;
    final bottom = tileSize.toDouble() + margin;

    // Cohen-Sutherland line clipping algorithm
    int outcode1 = _computeOutCode(x1, y1, left, right, top, bottom);
    int outcode2 = _computeOutCode(x2, y2, left, right, top, bottom);

    while (true) {
      if ((outcode1 | outcode2) == 0) {
        // Both points inside
        return (x1, y1, x2, y2);
      } else if ((outcode1 & outcode2) != 0) {
        // Both points outside same region
        return null;
      } else {
        // Some segment of line lies within rectangle
        double x = 0, y = 0;
        int outcodeOut = outcode1 != 0 ? outcode1 : outcode2;

        if ((outcodeOut & 8) != 0) {
          // point is above
          x = x1 + (x2 - x1) * (top - y1) / (y2 - y1);
          y = top;
        } else if ((outcodeOut & 4) != 0) {
          // point is below
          x = x1 + (x2 - x1) * (bottom - y1) / (y2 - y1);
          y = bottom;
        } else if ((outcodeOut & 2) != 0) {
          // point is to the right
          y = y1 + (y2 - y1) * (right - x1) / (x2 - x1);
          x = right;
        } else if ((outcodeOut & 1) != 0) {
          // point is to the left
          y = y1 + (y2 - y1) * (left - x1) / (x2 - x1);
          x = left;
        }

        if (outcodeOut == outcode1) {
          x1 = x;
          y1 = y;
          outcode1 = _computeOutCode(x1, y1, left, right, top, bottom);
        } else {
          x2 = x;
          y2 = y;
          outcode2 = _computeOutCode(x2, y2, left, right, top, bottom);
        }
      }
    }
  }

  int _computeOutCode(
    double x,
    double y,
    double left,
    double right,
    double top,
    double bottom,
  ) {
    int code = 0;
    if (x < left) code |= 1; // left
    if (x > right) code |= 2; // right
    if (y < top) code |= 8; // above
    if (y > bottom) code |= 4; // below
    return code;
  }

  // Calculate label placements from paths
  List<LabelPlacement> _calculateLabelPlacementsFromPaths(
    List<List<(double, double)>> paths,
    List<SubwayLine> lines,
    int zoom,
  ) {
    List<LabelPlacement> placements = [];

    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      final subwayLine = lines[i];

      if (path.length < 2) continue;

      // Find the longest segment in the visible area
      double maxLength = 0;
      int bestSegmentIndex = -1;

      for (int j = 0; j < path.length - 1; j++) {
        final (x1, y1) = path[j];
        final (x2, y2) = path[j + 1];

        // Check if segment is reasonably within tile
        if (x1 >= -50 &&
                x1 <= tileSize + 50 &&
                y1 >= -50 &&
                y1 <= tileSize + 50 ||
            x2 >= -50 &&
                x2 <= tileSize + 50 &&
                y2 >= -50 &&
                y2 <= tileSize + 50) {
          double length = sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
          if (length > maxLength) {
            maxLength = length;
            bestSegmentIndex = j;
          }
        }
      }

      double minLength = zoom >= 14 ? 20 : 40;
      if (bestSegmentIndex >= 0 && maxLength > minLength) {
        final (x1, y1) = path[bestSegmentIndex];
        final (x2, y2) = path[bestSegmentIndex + 1];

        final centerX = (x1 + x2) / 2;
        final centerY = (y1 + y2) / 2;
        final angle = atan2(y2 - y1, x2 - x1);

        double labelAngle = angle;
        if (labelAngle > pi / 2 || labelAngle < -pi / 2) {
          labelAngle += pi;
        }

        final lineName = subwayLine.lineName ?? '';
        if (lineName.isEmpty) continue;

        double labelWidth = lineName.length * 8.0;
        double labelHeight = 14.0;

        placements.add(
          LabelPlacement(
            centerX,
            centerY,
            lineName,
            labelAngle,
            subwayLine,
            labelWidth,
            labelHeight,
          ),
        );
      }
    }

    return _removeOverlappingLabels(placements);
  }

  List<LabelPlacement> _removeOverlappingLabels(
    List<LabelPlacement> placements,
  ) {
    List<LabelPlacement> result = [];

    placements.sort((a, b) => b.text.length.compareTo(a.text.length));

    for (final placement in placements) {
      bool overlaps = false;
      for (final existing in result) {
        if (placement.overlaps(existing)) {
          overlaps = true;
          break;
        }
      }

      if (!overlaps) {
        result.add(placement);
      }
    }

    return result;
  }

  void _drawLabels(imge.Image img, List<LabelPlacement> labels) {
    for (final label in labels) {
      int textX = label.x.round().clamp(10, tileSize - 10);
      int textY = label.y.round().clamp(10, tileSize - 10);

      final color = imge.ColorRgba8(
        (label.subwayLine.color.r * 255).round(),
        (label.subwayLine.color.g * 255).round(),
        (label.subwayLine.color.b * 255).round(),
        255,
      );

      // Draw label text
      imge.drawString(
        img,
        font: imge.arial14,
        x: textX - (label.text.length * 4), // center horizontally
        y: textY - 7, // center vertically
        label.text,
        color: color,
      );
    }
  }

  imge.ColorRgba8 _toRgba(ui.Color color) {
    return imge.ColorRgba8(
      (color.r * 255).round(),
      (color.g * 255).round(),
      (color.b * 255).round(),
      255,
    );
  }
}
