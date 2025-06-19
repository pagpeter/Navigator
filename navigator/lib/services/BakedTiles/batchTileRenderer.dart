import 'dart:io';
import 'package:navigator/models/subway_line.dart';
import 'package:path/path.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:navigator/services/BakedTiles/tileRenderer.dart';
import 'dart:math';

class BatchTileRenderer {
  final TileRenderer renderer = TileRenderer();

  void renderSubwayLinesToTiles({
    required List<SubwayLine> subwayLines,
    required int zoom,
    required String outputDir
  }) {
    // Map tiles to the subway lines that intersect them
    final tileMap = <(int, int), List<SubwayLine>>{};
    final tileSize = renderer.tileSize;

    // For each subway line, find which tiles it crosses
    for (final subwayLine in subwayLines) {
      final tilesForLine = _getTilesCrossedBySubwayLine(subwayLine, zoom, tileSize);
      
      for (final tileCoord in tilesForLine) {
        tileMap.putIfAbsent(tileCoord, () => []).add(subwayLine);
      }
    }

    // Render each tile with its intersecting subway lines
    for (final entry in tileMap.entries) {
      final (tileX, tileY) = entry.key;
      final subwayLinesInTile = entry.value;
      
      final outputPath = '$outputDir/$zoom/$tileX/$tileY.png';
      Directory(dirname(outputPath)).createSync(recursive: true);
      
      renderer.drawSubwayLinesToTile(
        subwayLines: subwayLinesInTile,
        tileX: tileX,
        tileY: tileY,
        zoom: zoom,
        outputPath: outputPath
      );
    }
  }

  /// Gets all tiles that a subway line crosses
  Set<(int, int)> _getTilesCrossedBySubwayLine(SubwayLine subwayLine, int zoom, int tileSize) {
    Set<(int, int)> tiles = {};
    
    for (int i = 0; i < subwayLine.points.length - 1; i++) {
      final point1 = subwayLine.points[i];
      final point2 = subwayLine.points[i + 1];
      
      // Convert to Web Mercator coordinates
      final (x1, y1) = renderer.latLongToWebMercator(point1.latitude, point1.longitude, zoom);
      final (x2, y2) = renderer.latLongToWebMercator(point2.latitude, point2.longitude, zoom);
      
      // Get tiles crossed by this line segment
      final segmentTiles = tilesCrossedByLine(x1, y1, x2, y2, tileSize);
      tiles.addAll(segmentTiles);
    }
    
    return tiles;
  }

  /// Determines which tiles a line segment crosses using DDA-like algorithm
  Set<(int, int)> tilesCrossedByLine(double x0, double y0, double x1, double y1, int tileSize) {
    Set<(int, int)> tiles = {};
    
    // Helper functions to convert pixel coordinates to tile coordinates
    int tX(double x) => (x / tileSize).floor();
    int tY(double y) => (y / tileSize).floor();
    
    double dx = x1 - x0;
    double dy = y1 - y0;
    
    // Calculate the number of steps needed
    int steps = max(dx.abs(), dy.abs()).ceil();
    
    // Handle case where start and end are the same point
    if (steps == 0) {
      tiles.add((tX(x0), tY(y0)));
      return tiles;
    }
    
    // Sample points along the line
    for (int i = 0; i <= steps; i++) {
      double t = i / steps;
      double x = x0 + dx * t;
      double y = y0 + dy * t;
      tiles.add((tX(x), tY(y)));
    }
    
    return tiles;
  }
}