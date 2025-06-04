import 'package:flutter/material.dart';
import 'package:core/pages/home_page_android.dart'; // Your UI is here

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      home: const HomePageAndroid(), // This is a custom widget in another file
    );
  }
}