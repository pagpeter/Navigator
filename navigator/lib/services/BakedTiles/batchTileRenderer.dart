import 'dart:io';
import 'package:navigator/models/subway_line.dart';
import 'package:path/path.dart';
import 'package:navigator/services/BakedTiles/tileRenderer.dart';
import 'dart:math';

class BatchTileRenderer {
  final TileRenderer renderer = TileRenderer();
  
  /// Renders subway lines to tiles for multiple zoom levels
  Future<void> renderSubwayLinesToTiles({
    required List<SubwayLine> subwayLines,
    required int zoom,
    required String outputDir,
    Function(int current, int total)? onProgress,
  }) async {
    print('Starting tile generation for zoom level $zoom...');
    
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
    
    print('Found ${tileMap.length} tiles to generate at zoom $zoom');
    
    // Create output directory
    final zoomDir = Directory('$outputDir/$zoom');
    if (!zoomDir.existsSync()) {
      zoomDir.createSync(recursive: true);
    }
    
    // Render each tile with its intersecting subway lines
    int current = 0;
    final total = tileMap.length;
    
    for (final entry in tileMap.entries) {
      final (tileX, tileY) = entry.key;
      final subwayLinesInTile = entry.value;
      
      final outputPath = '$outputDir/$zoom/$tileX/$tileY.png';
      
      // Create tile directory if it doesn't exist
      final tileDir = Directory(dirname(outputPath));
      if (!tileDir.existsSync()) {
        tileDir.createSync(recursive: true);
      }
      
      try {
        renderer.drawSubwayLinesToTile(
          subwayLines: subwayLinesInTile,
          tileX: tileX,
          tileY: tileY,
          zoom: zoom,
          outputPath: outputPath,
        );
        
        current++;
        onProgress?.call(current, total);
        
        // Add small delay to prevent overwhelming the system
        if (current % 10 == 0) {
          await Future.delayed(Duration(milliseconds: 1));
        }
        
      } catch (e) {
        print('Error generating tile $tileX/$tileY at zoom $zoom: $e');
      }
    }
    
    print('Completed tile generation for zoom level $zoom');
  }
  
  /// Renders tiles for multiple zoom levels
  Future<void> renderMultipleZoomLevels({
    required List<SubwayLine> subwayLines,
    required List<int> zoomLevels,
    required String outputDir,
    Function(int currentZoom, int totalZooms, int currentTile, int totalTiles)? onProgress,
  }) async {
    for (int i = 0; i < zoomLevels.length; i++) {
      final zoom = zoomLevels[i];
      await renderSubwayLinesToTiles(
        subwayLines: subwayLines,
        zoom: zoom,
        outputDir: outputDir,
        onProgress: (current, total) {
          onProgress?.call(i + 1, zoomLevels.length, current, total);
        },
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
      final segmentTiles = _tilesCrossedByLine(x1, y1, x2, y2, tileSize);
      tiles.addAll(segmentTiles);
    }
    
    return tiles;
  }
  
  /// Determines which tiles a line segment crosses using improved line traversal
  Set<(int, int)> _tilesCrossedByLine(double x0, double y0, double x1, double y1, int tileSize) {
    Set<(int, int)> tiles = {};
    
    // Helper functions to convert pixel coordinates to tile coordinates
    int tileX(double x) => (x / tileSize).floor();
    int tileY(double y) => (y / tileSize).floor();
    
    // Start and end tiles
    final startTileX = tileX(x0);
    final startTileY = tileY(y0);
    final endTileX = tileX(x1);
    final endTileY = tileY(y1);
    
    // If line is entirely within one tile
    if (startTileX == endTileX && startTileY == endTileY) {
      tiles.add((startTileX, startTileY));
      return tiles;
    }
    
    // Use DDA-like algorithm for line traversal
    double dx = x1 - x0;
    double dy = y1 - y0;
    
    // Calculate the number of steps needed (higher resolution)
    double distance = sqrt(dx * dx + dy * dy);
    int steps = (distance / (tileSize / 4)).ceil(); // Quarter-tile resolution
    
    if (steps == 0) {
      tiles.add((startTileX, startTileY));
      return tiles;
    }
    
    // Sample points along the line
    for (int i = 0; i <= steps; i++) {
      double t = i / steps;
      double x = x0 + dx * t;
      double y = y0 + dy * t;
      tiles.add((tileX(x), tileY(y)));
    }
    
    return tiles;
  }
  
  /// Clears cached tiles for a specific zoom level or all levels
  void clearCache({String? outputDir, int? zoom}) {
    if (outputDir == null) return;
    
    try {
      if (zoom != null) {
        final zoomDir = Directory('$outputDir/$zoom');
        if (zoomDir.existsSync()) {
          zoomDir.deleteSync(recursive: true);
          print('Cleared cache for zoom level $zoom');
        }
      } else {
        final cacheDir = Directory(outputDir);
        if (cacheDir.existsSync()) {
          cacheDir.deleteSync(recursive: true);
          print('Cleared entire tile cache');
        }
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
  
  /// Gets cache statistics
  Map<String, dynamic> getCacheStats(String outputDir) {
    final cacheDir = Directory(outputDir);
    if (!cacheDir.existsSync()) {
      return {
        'totalTiles': 0,
        'totalSize': 0,
        'zoomLevels': <int>[],
      };
    }
    
    int totalTiles = 0;
    int totalSize = 0;
    List<int> zoomLevels = [];
    
    try {
      for (final zoomDir in cacheDir.listSync().whereType<Directory>()) {
        final zoomLevel = int.tryParse(zoomDir.path.split('/').last);
        if (zoomLevel != null) {
          zoomLevels.add(zoomLevel);
          
          // Count tiles in this zoom level
          final tiles = zoomDir.listSync(recursive: true).whereType<File>()
              .where((file) => file.path.endsWith('.png'));
          
          totalTiles += tiles.length;
          
          for (final tile in tiles) {
            totalSize += tile.lengthSync();
          }
        }
      }
    } catch (e) {
      print('Error calculating cache stats: $e');
    }
    
    zoomLevels.sort();
    
    return {
      'totalTiles': totalTiles,
      'totalSize': totalSize,
      'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      'zoomLevels': zoomLevels,
    };
  }
}