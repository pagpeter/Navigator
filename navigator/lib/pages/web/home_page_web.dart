import 'package:flutter/material.dart';
import 'package:navigator/pages/page_models/home_page.dart';


class HomePageWeb extends HomePage
{
  HomePageWeb(this.page, this.ongoingJourney,{super.key});

  HomePage page;
  bool ongoingJourney;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Web Version'
    );
  }
}

