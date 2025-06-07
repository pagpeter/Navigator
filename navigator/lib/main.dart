import 'package:flutter/material.dart';
import 'package:navigator/pages/page_models/home_page.dart'; // Your UI is here

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navigator',
      home: HomePage(), // This is a custom widget in another file
    );
  }
}