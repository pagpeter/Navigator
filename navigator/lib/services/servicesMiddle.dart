import 'package:navigator/services/dbApiService.dart';
import 'package:navigator/models/station.dart';
import 'package:navigator/models/journey.dart';
import 'package:navigator/models/location.dart';

class ServicesMiddle 
{
  dbApiService dbRest = new dbApiService();

  Future<List<Location>> getLocations(String query) async
  {
    final results = await dbRest.fetchLocations(query);
    return results;
  }

  // Future<List<Journey>> getJourneys(Location from, Location to)
  // {
  //   return Future<List<Journey>>(() => ,;
  // }

}