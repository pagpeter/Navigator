import 'package:navigator/models/dateAndTime.dart';
import 'package:navigator/services/dbApiService.dart';
import 'package:navigator/models/station.dart';
import 'package:navigator/models/journey.dart';
import 'package:navigator/models/location.dart' as myApp;
import 'package:geocoding/geocoding.dart' as geo;

class ServicesMiddle 
{
  dbApiService dbRest = new dbApiService();

  Future<List<myApp.Location>> getLocations(String query) async
  {
    final results = await dbRest.fetchLocations(query);
    return results;
  }

  Future<String> getAddressFromLatLng(double latitude, double longitude) async {
  try {
    List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(latitude, longitude);

    if (placemarks.isNotEmpty) {
      final geo.Placemark place = placemarks.first;

      String address = [
        if (place.street != null && place.street!.isNotEmpty) place.street,
        if (place.postalCode != null && place.postalCode!.isNotEmpty) place.postalCode,
        if (place.locality != null && place.locality!.isNotEmpty) place.locality,
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) place.administrativeArea,
        if (place.country != null && place.country!.isNotEmpty) place.country,
      ].whereType<String>().join(', ');

      return address;
    } else {
      return 'No address available';
    }
  } catch (e) {
    print('Error in reverse geocoding: $e');
    return 'Failed to get address';
  }
}

  Future<List<Journey>> getJourneys(myApp.Location from, myApp.Location to, DateAndTime when, bool departure) async
  {
    final results = await dbRest.fetchJourneysByLocation(from, to, when, departure);
    print("Journeys fetched: " + results.length.toString());
    return results;
  }

}