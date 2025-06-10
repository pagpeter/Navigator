import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:navigator/pages/page_models/home_page.dart'; // Your UI is here
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final _defaultLightColorScheme =
    ColorScheme.fromSwatch(primarySwatch: Colors.blue);

  static final _defaultDarkColorScheme = ColorScheme.fromSwatch(
    primarySwatch: Colors.blue, brightness: Brightness.dark);


  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (ColorScheme? lightColorScheme,ColorScheme? darkColorScheme){
      return MaterialApp(
        title: 'Navigator',
        home: HomePage(), // This is a custom widget in another file...
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: lightColorScheme ?? _defaultLightColorScheme,
          brightness: Brightness.light,
          textTheme: TextTheme(
        displayLarge: const TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.bold,
        ),
        // ···
        titleLarge: GoogleFonts.roboto(
          fontSize: 30,
          fontStyle: FontStyle.italic,
        ),
        titleMedium: GoogleFonts.roboto(
          fontSize: 18,
          
        ),
        bodyMedium: GoogleFonts.roboto(),
        displaySmall: GoogleFonts.roboto(),
      ),
        ),
        
      );
  });
  }
}
