import 'dart:io';
import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlng/latlng.dart';
import 'package:image/image.dart';
import 'package:navigator/models/subway_line.dart';

class LineSegment {
  final double x1, y1, x2, y2;
  final SubwayLine subwayLine;
  
  LineSegment(this.x1, this.y1, this.x2, this.y2, this.subwayLine);
  
  double get length => sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
  
  // Get the center point of the segment
  (double, double) get center => ((x1 + x2) / 2, (y1 + y2) / 2);
  
  // Get the angle of the line segment in radians
  double get angle => atan2(y2 - y1, x2 - x1);
  
  // Check if two line segments overlap (are close to each other)
  bool overlaps(LineSegment other, double threshold) {
    // Check if the segments are roughly parallel and close
    double angleDiff = (angle - other.angle).abs();
    if (angleDiff > pi / 2) angleDiff = pi - angleDiff;
    
    if (angleDiff > pi / 6) return false; // Not parallel enough
    
    // Check distance between segments
    double dist = _distanceToSegment(other);
    return dist < threshold;
  }
  
  double _distanceToSegment(LineSegment other) {
    // Simplified distance calculation between two line segments
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
  
  // Check if this label overlaps with another
  bool overlaps(LabelPlacement other) {
    double dx = (x - other.x).abs();
    double dy = (y - other.y).abs();
    return dx < (width + other.width) / 2 + 5 && dy < (height + other.height) / 2 + 5;
  }
}

class TileRenderer {
  final int tileSize = 256;
  final double lineWidth = 3.0;
  final double parallelOffset = 4.0; // Offset for parallel lines
  
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
  double degrees(double rad) => rad * (180 / pi);

  /// Enhanced drawing with parallel lines and labels
  void drawSubwayLinesToTile({
    required List<SubwayLine> subwayLines,
    required int tileX,
    required int tileY,
    required int zoom,
    required String outputPath,
  }) {
    final img = Image(width: tileSize, height: tileSize);
    fill(img, color: ColorRgba8(255, 255, 255, 0)); // transparent background
    
    final originX = tileX * tileSize;
    final originY = tileY * tileSize;
    
    // Step 1: Convert all line segments to local coordinates
    List<LineSegment> allSegments = [];
    for (final subwayLine in subwayLines) {
      for (int i = 0; i < subwayLine.points.length - 1; i++) {
        final point1 = subwayLine.points[i];
        final point2 = subwayLine.points[i + 1];
        
        final (x1, y1) = latLongToWebMercator(point1.latitude, point1.longitude, zoom);
        final (x2, y2) = latLongToWebMercator(point2.latitude, point2.longitude, zoom);
        
        final localX1 = x1 - originX;
        final localY1 = y1 - originY;
        final localX2 = x2 - originX;
        final localY2 = y2 - originY;
        
        if (_lineIntersectsTile(localX1.round(), localY1.round(), localX2.round(), localY2.round(), tileSize)) {
          allSegments.add(LineSegment(localX1, localY1, localX2, localY2, subwayLine));
        }
      }
    }
    
    // Step 2: Group overlapping segments
    Map<LineSegment, List<LineSegment>> overlappingGroups = _groupOverlappingSegments(allSegments);
    
    // Step 3: Draw segments with parallel offsets
    Set<LineSegment> processedSegments = {};
    for (final segment in allSegments) {
      if (processedSegments.contains(segment)) continue;
      
      List<LineSegment> group = overlappingGroups[segment] ?? [segment];
      _drawParallelSegments(img, group);
      processedSegments.addAll(group);
    }
    
    // Step 4: Add labels
    List<LabelPlacement> labelPlacements = _calculateLabelPlacements(allSegments, zoom);
    _drawLabels(img, labelPlacements);
    
    final png = encodePng(img);
    File(outputPath).writeAsBytesSync(png);
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
      
      // Assign this group to all segments in it
      for (final segment in group) {
        groups[segment] = group;
      }
    }
    
    return groups;
  }
  
  void _drawParallelSegments(Image img, List<LineSegment> segments) {
    if (segments.length == 1) {
      // Single line, draw normally
      _drawSegment(img, segments[0], 0);
      return;
    }
    
    // Multiple overlapping lines, draw with offsets
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
    
    if (offset != 0) {
      // Calculate perpendicular offset
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
    
    final color = segment.subwayLine.color;
    drawLine(img,
      x1: x1.round(), y1: y1.round(),
      x2: x2.round(), y2: y2.round(),
      color: ColorRgba8(color.r.round(), color.g.round(), color.b.round(), color.a.round()),
      antialias: true,
      thickness: lineWidth.round()
    );
  }
  
  List<LabelPlacement> _calculateLabelPlacements(List<LineSegment> segments, int zoom) {
    List<LabelPlacement> placements = [];
    
    // Group segments by subway line
    Map<SubwayLine, List<LineSegment>> lineSegments = {};
    for (final segment in segments) {
      lineSegments.putIfAbsent(segment.subwayLine, () => []).add(segment);
    }
    
    for (final entry in lineSegments.entries) {
      final subwayLine = entry.key;
      final lineSegs = entry.value;
      
      // Find the longest segment for label placement
      LineSegment? longestSegment;
      double maxLength = 0;
      
      for (final segment in lineSegs) {
        if (segment.length > maxLength) {
          maxLength = segment.length;
          longestSegment = segment;
        }
      }
      
      if (longestSegment != null && longestSegment.length > 30) { // Only label if segment is long enough
        final (centerX, centerY) = longestSegment.center;
        final angle = longestSegment.angle;
        
        // Adjust angle to keep text readable
        double labelAngle = angle;
        if (labelAngle > pi / 2 || labelAngle < -pi / 2) {
          labelAngle += pi; // Flip text to keep it readable
        }
        
        // Skip if line has no name
        final lineName = subwayLine.lineName ?? subwayLine.lineName ?? '';
        if (lineName.isEmpty) continue;
        
        // Estimate label dimensions (this would need to be more sophisticated in practice)
        double labelWidth = lineName.length * 8.0; // Rough estimate
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
    
    // Remove overlapping labels
    return _removeOverlappingLabels(placements);
  }
  
  List<LabelPlacement> _removeOverlappingLabels(List<LabelPlacement> placements) {
    List<LabelPlacement> result = [];
    
    // Sort by line length/importance (you might want to add importance to SubwayLine)
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
      drawString(img, label.text, font: arial14, x: label.x.round(), y: label.y.round());
      // For now, this is a placeholder - you'd need to implement actual text rendering
      // You might want to use a package like 'bitmap_font' or render text to a separate layer
      
      // Draw a simple text background rectangle as placeholder
      
      // TODO: Add actual text rendering here
      // You'll need to either:
      // 1. Use a text rendering package
      // 2. Pre-render text to images
      // 3. Use a bitmap font
      
      print('Label "${label.text}" at (${label.x.round()}, ${label.y.round()}) angle: ${degrees(label.angle).round()}°');
    }
  }
  
  bool _lineIntersectsTile(int x1, int y1, int x2, int y2, int size) {
    final minX = min(x1, x2);
    final maxX = max(x1, x2);
    final minY = min(y1, y2);
    final maxY = max(y1, y2);
    return maxX >= 0 && minX < size && maxY >= 0 && minY < size;
  }
}