import 'dart:math';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlng/latlng.dart';


class Tilerenderer 
{

  final tileSize = 256;

  void PolylinesToRaster(List<Polyline> lines)
  {

  }

  (double, double) latLongToWebMercartor(double lat, double lon, int zoom)
  {
    final scale = tileSize * pow(2, zoom);
    lat = lat.clamp(-85.05112878, 85.05112878);
    double x = (lon + 180) / 360 * scale;
    double sinLat = sin(radians(lat));
    double y = (0.5 - log((1 + sinLat) / (1 - sinLat)) / (4*pi)) * scale;
    return (x,y);
  }

  double radians(double deg)
  {
    return deg * (pi/180);
  }


}