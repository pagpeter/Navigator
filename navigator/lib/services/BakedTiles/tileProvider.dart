import 'package:flutter_map/flutter_map.dart';

class SubwayTileProvider {
  TileLayer getTileLayer() {
    return TileLayer(
      tileProvider: AssetTileProvider(),
      tileSize: 256,
      maxZoom: 16,
      minZoom: 10,
      urlTemplate: 'assets/tiles/{z}/{x}/{y}.png',
    );
  }
}
