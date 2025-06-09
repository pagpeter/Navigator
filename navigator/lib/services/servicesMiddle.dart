import 'package:navigator/services/dbApiService.dart';
import 'package:navigator/models/station.dart';

class ServicesMiddle 
{
  dbApiService dbRest = new dbApiService();

  Future<List<Station>> getLocations(String query) async
  {
    final results = await dbRest.fetchLocations(query);
    return results;
  }

}