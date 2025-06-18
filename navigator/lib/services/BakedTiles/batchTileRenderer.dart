import 'dart:io';
import 'package:path/path.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:navigator/services/BakedTiles/tileRenderer.dart';
import 'dart:math';


class Batchtilerenderer 
{

  final TileRenderer renderer = TileRenderer();

  void renderPolyLinesToTiles({
    required List<Polyline> polylines,
    required int zoom,
    required String outputDir
  })
  {
    final tileMap = <(int, int), List<List<(double, double)>>>{};
    final convertedPolyLines = renderer.polylinesToWebMercator(polylines, zoom);
    final tileSize = renderer.tileSize;

  for(final polyline in convertedPolyLines)
  {
    for(int i = 0; i < polyline.length; i++)
    {
      final (x1, y1) = polyline[i];
      final (x2, y2) = polyline[i+1];

      final tiles = tilesCrossedByLine(x1, y1, x2, y2, tileSize);

      for(final(tileX, tileY) in tiles)
      {
        tileMap.putIfAbsent((tileX, tileY), () => []).add([(x1, y1), (x2, y2)]);
      }
    }
  }

  for(final entry in tileMap.entries)
  {
    final (tileX, tileY) = entry.key;
    final segments = entry.value;
    final outputPath = '$outputDir/$zoom/$tileX/$tileY.png';
    Directory(dirname(outputPath)).createSync(recursive: true);

    renderer.drawPolylinesToTile(polylines: segments, tileX: tileX, tileY: tileY, zoom: zoom, outputPath: outputPath);
  }

  }


  Set<(int, int)> tilesCrossedByLine(double x0, double y0, double x1, double y1, int tileSize)
  {
    Set<(int, int)> tiles = {};

    int tX(double x) => (x / tileSize).floor();
    int tY(double y) => (y / tileSize).floor();

    double dx = x1 - x0;
    double dy = y1 - y0;

    int steps = max(dx.abs(), dy.abs()).ceil();

    for(int i = 0; i <= steps; i++)
    {
      double t = i/steps;
      double x = x0 + dx * t;
      double y = y0 + dy * t;
      tiles.add((tX(x), tY(y)));
    }

    return tiles;
    
  }

}