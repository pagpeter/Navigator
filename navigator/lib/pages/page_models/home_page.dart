import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navigator/pages/android/home_page_android.dart';
import 'package:navigator/pages/ios/home_page_ios.dart';
import 'package:navigator/pages/linux/home_page_linux.dart';
import 'package:navigator/pages/macos/home_page_macos.dart';
import 'package:navigator/pages/web/home_page_web.dart';
import 'package:navigator/pages/windows/home_page_windows.dart';
import 'package:navigator/services/servicesMiddle.dart';
import 'package:navigator/models/station.dart';

class HomePage extends StatelessWidget
{
  HomePage({super.key});

  //search Button
  bool ongoingJourney = false;
  ServicesMiddle service = new ServicesMiddle();

  final int design = 0; //0 = Android, 1 = ios, 2 = linux, 3 = macos, 4 = web, 5 = windows
  
  Future<List<Station>> getLocations(String query) async
  {
    return await service.getLocations(query);
  }



  //bottom Bar home and saved
  //map
  @override
  Widget build(BuildContext context) {
    switch(design)
    {
      case 1:
      return MaterialApp(
      title: 'Navigator',
      home: HomePageIos(this, ongoingJourney), // This is a custom widget in another file
    );

      case 2:
      return MaterialApp(
      title: 'Navigator',
      home: HomePageLinux(this, ongoingJourney), // This is a custom widget in another file
    );

      case 3:
      return MaterialApp(
      title: 'Navigator',
      home: HomePageMacos(this, ongoingJourney), // This is a custom widget in another file
    );

      case 4:
      return MaterialApp(
      title: 'Navigator',
      home: HomePageWeb(this, ongoingJourney), // This is a custom widget in another file
    );

      case 5:
      return MaterialApp(
      title: 'Navigator',
      home: HomePageWindows(this, ongoingJourney), // This is a custom widget in another file
    );


      default:
      return MaterialApp(
      title: 'Navigator',
      home: HomePageAndroid(this, ongoingJourney), // This is a custom widget in another file
    );
    }
    
  }
}