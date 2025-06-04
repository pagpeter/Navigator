import 'package:flutter/material.dart';

class HomePageAndroid extends StatelessWidget {
  const HomePageAndroid({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(child: Text('Hello from HomePage')),
    );
  }
}