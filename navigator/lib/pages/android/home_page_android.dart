import 'package:flutter/material.dart';
import 'package:navigator/pages/page_models/home_page.dart';

class HomePageAndroid extends StatelessWidget {
  HomePageAndroid({super.key});

  final HomePage page = HomePage();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: 
      [
        Center(child: Text(page.searchButtonText)),
      ]
    );
  }
}