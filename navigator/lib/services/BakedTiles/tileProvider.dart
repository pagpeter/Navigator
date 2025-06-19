import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:navigator/models/subway_line.dart';
import 'package:navigator/services/BakedTiles/batchTileRenderer.dart';

class SubwayTileProvider extends TileProvider {
  final String cacheDir;
  final BatchTileRenderer? batchRenderer;
  final List<SubwayLine>? subwayLines;
  final bool enableFallbackGeneration;
  
  SubwayTileProvider({
    required this.cacheDir,
    this.batchRenderer,
    this.subwayLines,
    this.enableFallbackGeneration = false,
  });

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final tilePath = _getTilePath(coordinates);
    final file = File(tilePath);
    
    // If tile exists in cache, return it
    if (file.existsSync()) {
      return FileImage(file);
    }
    
    // If fallback generation is enabled and we have the required data
    if (enableFallbackGeneration && 
        batchRenderer != null && 
        subwayLines != null) {
      return _FallbackTileProvider(
        coordinates: coordinates,
        batchRenderer: batchRenderer!,
        subwayLines: subwayLines!,
        cacheDir: cacheDir,
      );
    }
    
    // Return transparent tile if no tile found and no fallback
    return _createTransparentTile();
  }

  String _getTilePath(TileCoordinates coordinates) {
    return '$cacheDir/${coordinates.z}/${coordinates.x}/${coordinates.y}.png';
  }
  
  ImageProvider _createTransparentTile() {
    // Return a simple transparent image provider
    return const AssetImage('assets/images/transparent_tile.png');
  }
  
  /// Preload tiles for a specific area and zoom range
  Future<void> preloadArea({
    required double northLat,
    required double southLat,
    required double eastLng,
    required double westLng,
    required int minZoom,
    required int maxZoom,
    Function(int current, int total)? onProgress,
  }) async {
    if (batchRenderer == null || subwayLines == null) {
      throw Exception('BatchRenderer and SubwayLines required for preloading');
    }
    
    final zoomLevels = List.generate(maxZoom - minZoom + 1, (i) => minZoom + i);
    
    await batchRenderer!.renderMultipleZoomLevels(
      subwayLines: subwayLines!,
      zoomLevels: zoomLevels,
      outputDir: cacheDir,
      onProgress: (currentZoom, totalZooms, currentTile, totalTiles) {
        final overallProgress = ((currentZoom - 1) * 100 + 
            (currentTile * 100 / totalTiles)) / totalZooms;
        onProgress?.call(overallProgress.round(), 100);
      },
    );
  }
  
  /// Clear cached tiles
  Future<void> clearCache({int? zoom}) async {
    batchRenderer?.clearCache(outputDir: cacheDir, zoom: zoom);
  }
  
  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return batchRenderer?.getCacheStats(cacheDir) ?? {};
  }
}

class _FallbackTileProvider extends ImageProvider<_FallbackTileProvider> {
  final TileCoordinates coordinates;
  final BatchTileRenderer batchRenderer;
  final List<SubwayLine> subwayLines;
  final String cacheDir;
  
  const _FallbackTileProvider({
    required this.coordinates,
    required this.batchRenderer,
    required this.subwayLines,
    required this.cacheDir,
  });

  @override
  Future<_FallbackTileProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadBuffer(_FallbackTileProvider key, DecoderBufferCallback decode) {
    return OneFrameImageStreamCompleter(_loadTile(key, decode));
  }

  Future<ImageInfo> _loadTile(_FallbackTileProvider key, DecoderBufferCallback decode) async {
    try {
      // Generate the missing tile on-demand
      final tilePath = '$cacheDir/${coordinates.z}/${coordinates.x}/${coordinates.y}.png';
      
      // Create directory if it doesn't exist
      final directory = Directory(tilePath).parent;
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
      
      // Generate the tile
      batchRenderer.renderer.drawSubwayLinesToTile(
        subwayLines: subwayLines,
        tileX: coordinates.x,
        tileY: coordinates.y,
        zoom: coordinates.z,
        outputPath: tilePath,
      );
      
      // Load the generated tile
      final file = File(tilePath);
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        final buffer = await ImmutableBuffer.fromUint8List(bytes);
        final codec = await decode(buffer);
        final frame = await codec.getNextFrame();
        return ImageInfo(image: frame.image);
      }
    } catch (e) {
      print('Error generating fallback tile: $e');
    }
    
    // Return a transparent image if generation fails
    return _createTransparentImageInfo();
  }
  
  Future<ImageInfo> _createTransparentImageInfo() async {
    // Create a simple 1x1 transparent image
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    // Don't draw anything (transparent)
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(256, 256);
    return ImageInfo(image: image);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is _FallbackTileProvider &&
           other.coordinates == coordinates;
  }

  @override
  int get hashCode => coordinates.hashCode;
}

class SubwayTileLayer {
  final SubwayTileProvider tileProvider;
  
  SubwayTileLayer({required this.tileProvider});
  
  TileLayer getTileLayer() {
    return TileLayer(
      tileProvider: tileProvider,
      tileSize: 256,
      maxZoom: 16,
      minZoom: 10,
      // Use custom URL template that won't be used since we override the provider
      urlTemplate: '',
    );
  }
  
  /// Create a tile layer with caching enabled
  static SubwayTileLayer withCaching({
    required String cacheDir,
    required List<SubwayLine> subwayLines,
    bool enableFallbackGeneration = true,
  }) {
    final batchRenderer = BatchTileRenderer();
    final tileProvider = SubwayTileProvider(
      cacheDir: cacheDir,
      batchRenderer: batchRenderer,
      subwayLines: subwayLines,
      enableFallbackGeneration: enableFallbackGeneration,
    );
    
    return SubwayTileLayer(tileProvider: tileProvider);
  }
  
  /// Create a tile layer that only serves from cache (no fallback generation)
  static SubwayTileLayer cacheOnly({
    required String cacheDir,
  }) {
    final tileProvider = SubwayTileProvider(
      cacheDir: cacheDir,
      enableFallbackGeneration: false,
    );
    
    return SubwayTileLayer(tileProvider: tileProvider);
  }
}