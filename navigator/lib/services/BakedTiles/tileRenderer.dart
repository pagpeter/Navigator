import 'dart:io';
import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlng/latlng.dart';
import 'package:image/image.dart';
import 'package:navigator/models/subway_line.dart';
import 'package:scidart/numdart.dart';

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
  
  LabelPlacement(this.x, this.y, this.text, this.angle, this.subwayLine, this.width, this.height);
  
  bool overlaps(LabelPlacement other) {
    double dx = (x - other.x).abs();
    double dy = (y - other.y).abs();
    return dx < (width + other.width) / 2 + 5 && dy < (height + other.height) / 2 + 5;
  }
}

class TileRenderer {
  final int tileSize = 256;
  final double lineWidth = 3.0;
  final double parallelOffset = 4.0;
  
  // Fixed Web Mercator projection
  (double, double) latLongToWebMercator(double lat, double lon, int zoom) {
    // Clamp latitude to valid Web Mercator range
    lat = lat.clamp(-85.0511, 85.0511);
    
    // Convert to radians
    final latRad = lat * pi / 180.0;
    
    // Web Mercator formulas - FIXED
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
    final img = Image(width: tileSize, height: tileSize);
    
    // FIXED: Properly set transparent background
    fill(img, color: ColorRgba8(0, 0, 0, 0)); // Fully transparent
    
    final originX = tileX * tileSize.toDouble();
    final originY = tileY * tileSize.toDouble();
    
    print('Rendering tile ${tileX}/${tileY} at zoom $zoom');
    print('Origin: ($originX, $originY)');
    
    // Debug: Print tile bounds in lat/lon
    final (tileLat1, tileLon1) = tileToLatLong(tileX, tileY, zoom);
    final (tileLat2, tileLon2) = tileToLatLong(tileX + 1, tileY + 1, zoom);
    print('Tile bounds: lat=$tileLat1 to $tileLat2, lon=$tileLon1 to $tileLon2');
    
    // Convert all line segments to local coordinates
    List<LineSegment> allSegments = [];
    int totalPoints = 0;
    int validSegments = 0;
    
    for (final subwayLine in subwayLines) {
      totalPoints += subwayLine.points.length;
      
      for (int i = 0; i < subwayLine.points.length - 1; i++) {
        final point1 = subwayLine.points[i];
        final point2 = subwayLine.points[i + 1];
        
        final (worldX1, worldY1) = latLongToWebMercator(point1.latitude, point1.longitude, zoom);
        final (worldX2, worldY2) = latLongToWebMercator(point2.latitude, point2.longitude, zoom);
        
        final localX1 = worldX1 - originX;
        final localY1 = worldY1 - originY;
        final localX2 = worldX2 - originX;
        final localY2 = worldY2 - originY;
        
        // Debug: Print first few coordinates
        if (i < 3) {
          print('Point ${i}: lat=${point1.latitude}, lon=${point1.longitude}');
          print('  -> world=($worldX1, $worldY1) -> local=($localX1, $localY1)');
        }
        
        // More generous bounds checking - include segments that cross tile boundaries
        if (_segmentIntersectsTile(localX1, localY1, localX2, localY2)) {
          allSegments.add(LineSegment(localX1, localY1, localX2, localY2, subwayLine));
          validSegments++;
        }
      }
    }
    
    print('Total points: $totalPoints, Valid segments: $validSegments');
    
    if (allSegments.isEmpty) {
      print('No segments in tile bounds - creating empty tile');
      final png = encodePng(img);
      File(outputPath).writeAsBytesSync(png);
      return;
    }
    
    // Group overlapping segments
    Map<LineSegment, List<LineSegment>> overlappingGroups = _groupOverlappingSegments(allSegments);
    
    // Draw segments with parallel offsets
    Set<LineSegment> processedSegments = {};
    int drawnSegments = 0;
    
    for (final segment in allSegments) {
      if (processedSegments.contains(segment)) continue;
      
      List<LineSegment> group = overlappingGroups[segment] ?? [segment];
      _drawParallelSegments(img, group);
      processedSegments.addAll(group);
      drawnSegments += group.length;
    }
    
    print('Drew $drawnSegments segments');
    
    // Add labels - only at higher zoom levels to avoid clutter
    if (zoom >= 12) {
      List<LabelPlacement> labelPlacements = _calculateLabelPlacements(allSegments, zoom);
      _drawLabels(img, labelPlacements);
    }
    
    final png = encodePng(img);
    File(outputPath).writeAsBytesSync(png);
    print('Generated tile: $outputPath');
  }
  
  // Fixed bounds checking to be more inclusive
  bool _segmentIntersectsTile(double x1, double y1, double x2, double y2) {
    // Expand the tile bounds to catch segments that cross tile boundaries
    const padding = 50.0;
    final minX = min(x1, x2);
    final maxX = max(x1, x2);
    final minY = min(y1, y2);
    final maxY = max(y1, y2);
    
    // Check if segment bounding box intersects with expanded tile bounds
    return !(maxX < -padding || minX > tileSize + padding || 
             maxY < -padding || minY > tileSize + padding);
  }
  
  Map<LineSegment, List<LineSegment>> _groupOverlappingSegments(List<LineSegment> segments) {
    Map<LineSegment, List<LineSegment>> groups = {};
    
    for (int i = 0; i < segments.length; i++) {
      if (groups.containsKey(segments[i])) continue;
      
      List<LineSegment> group = [segments[i]];
      
      for (int j = i + 1; j < segments.length; j++) {
        if (segments[i].overlaps(segments[j], parallelOffset * 2)) {
          group.add(segments[j]);
        }
      }
      
      for (final segment in group) {
        groups[segment] = group;
      }
    }
    
    return groups;
  }
  
  void _drawParallelSegments(Image img, List<LineSegment> segments) {
    if (segments.length == 1) {
      _drawSegment(img, segments[0], 0);
      return;
    }
    
    double totalWidth = (segments.length - 1) * parallelOffset;
    double startOffset = -totalWidth / 2;
    
    for (int i = 0; i < segments.length; i++) {
      double offset = startOffset + i * parallelOffset;
      _drawSegment(img, segments[i], offset);
    }
  }
  
  void _drawSegment(Image img, LineSegment segment, double offset) {
    double x1 = segment.x1;
    double y1 = segment.y1;
    double x2 = segment.x2;
    double y2 = segment.y2;
    
    // Apply perpendicular offset for parallel lines
    if (offset != 0) {
      double length = segment.length;
      if (length > 0) {
        double perpX = -(y2 - y1) / length * offset;
        double perpY = (x2 - x1) / length * offset;
        
        x1 += perpX;
        y1 += perpY;
        x2 += perpX;
        y2 += perpY;
      }
    }
    
    // Debug: Print segment coordinates
    print('Drawing segment: (${x1.toStringAsFixed(1)}, ${y1.toStringAsFixed(1)}) to (${x2.toStringAsFixed(1)}, ${y2.toStringAsFixed(1)})');
    
    // Clip line to tile bounds but allow some overflow for smooth rendering
    final clippedCoords = _clipLineToTile(x1, y1, x2, y2);
    if (clippedCoords == null) {
      print('Segment clipped out completely');
      return;
    }
    
    final (clippedX1, clippedY1, clippedX2, clippedY2) = clippedCoords;
    
    // Get color from subway line
    final color = segment.subwayLine.color;
    final drawColor = ColorRgba8(
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
      255 // Force full opacity for lines
    );
    
    print('Drawing with color: R=${drawColor.r} G=${drawColor.g} B=${drawColor.b} A=${drawColor.a}');
    
    // Draw the line with proper thickness
    drawLine(img,
      x1: clippedX1.round(), 
      y1: clippedY1.round(),
      x2: clippedX2.round(), 
      y2: clippedY2.round(),
      color: drawColor,
      antialias: true,
      thickness: lineWidth.round()
    );
  }
  
  // Add line clipping to tile bounds
  (double, double, double, double)? _clipLineToTile(double x1, double y1, double x2, double y2) {
    const margin = 10.0;
    final left = -margin;
    final right = tileSize.toDouble() + margin;
    final top = -margin;
    final bottom = tileSize.toDouble() + margin;
    
    // Simple bounds check - if both points are outside same boundary, skip
    if ((x1 < left && x2 < left) || (x1 > right && x2 > right) ||
        (y1 < top && y2 < top) || (y1 > bottom && y2 > bottom)) {
      return null;
    }
    
    // For now, just clamp coordinates - proper line clipping would be more complex
    return (
      x1.clamp(left, right),
      y1.clamp(top, bottom),
      x2.clamp(left, right),
      y2.clamp(top, bottom)
    );
  }
  
  List<LabelPlacement> _calculateLabelPlacements(List<LineSegment> segments, int zoom) {
    List<LabelPlacement> placements = [];
    
    Map<SubwayLine, List<LineSegment>> lineSegments = {};
    for (final segment in segments) {
      lineSegments.putIfAbsent(segment.subwayLine, () => []).add(segment);
    }
    
    for (final entry in lineSegments.entries) {
      final subwayLine = entry.key;
      final lineSegs = entry.value;
      
      LineSegment? longestSegment;
      double maxLength = 0;
      
      for (final segment in lineSegs) {
        if (segment.length > maxLength) {
          maxLength = segment.length;
          longestSegment = segment;
        }
      }
      
      // Adjust minimum length based on zoom level
      double minLength = zoom >= 14 ? 20 : 40;
      
      if (longestSegment != null && longestSegment.length > minLength) {
        final (centerX, centerY) = longestSegment.center;
        final angle = longestSegment.angle;
        
        double labelAngle = angle;
        if (labelAngle > pi / 2 || labelAngle < -pi / 2) {
          labelAngle += pi;
        }
        
        final lineName = subwayLine.lineName ?? '';
        if (lineName.isEmpty) continue;
        
        double labelWidth = lineName.length * 8.0;
        double labelHeight = 12.0;
        
        placements.add(LabelPlacement(
          centerX, centerY,
          lineName,
          labelAngle,
          subwayLine,
          labelWidth,
          labelHeight
        ));
      }
    }
    
    return _removeOverlappingLabels(placements);
  }
  
  List<LabelPlacement> _removeOverlappingLabels(List<LabelPlacement> placements) {
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
  
  void _drawLabels(Image img, List<LabelPlacement> labels) {
    for (final label in labels) {
      // Simple text rendering - draw a background rectangle
      int textX = label.x.round().clamp(5, tileSize - 5);
      int textY = label.y.round().clamp(5, tileSize - 5);
      
      // Draw background rectangle for text
      int bgWidth = (label.width).round();
      int bgHeight = (label.height).round();
      
      fillRect(img, 
        x1: textX - bgWidth ~/ 2, 
        y1: textY - bgHeight ~/ 2,
        x2: textX + bgWidth ~/ 2, 
        y2: textY + bgHeight ~/ 2,
        color: ColorRgba8(255, 255, 255, 200)
      );
      
      // For now, just print the label info
      // In a real implementation, you'd render the actual text
      print('Label "${label.text}" at ($textX, $textY) angle: ${degrees(label.angle).round()}°');
    }
  }
  
  bool _lineIntersectsTile(int x1, int y1, int x2, int y2, int size) {
    final minX = min(x1, x2);
    final maxX = max(x1, x2);
    final minY = min(y1, y2);
    final maxY = max(y1, y2);
    
    // Add some padding to catch lines that just touch the tile edge
    return maxX >= -10 && minX < size + 10 && maxY >= -10 && minY < size + 10;
  }
}