import 'package:navigator/models/location.dart';
import 'package:navigator/services/geoLocator.dart';
import 'package:navigator/services/servicesMiddle.dart';

class ConnectionsPage 
{
  Location to;
  Location from;
  ServicesMiddle services;

  ConnectionsPage({required this.from,required this.to, required this.services});
}