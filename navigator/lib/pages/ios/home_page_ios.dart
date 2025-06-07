import 'package:flutter/material.dart';
import 'package:navigator/pages/page_models/home_page.dart';

class HomePageIos extends StatelessWidget
{
  HomePageIos(this.page, this.ongoingJourney, {super.key});

  HomePage page;
  bool ongoingJourney;
  
  @override
  Widget build(BuildContext context) {
    return Text(
      'Ios'
    );
  }
}

