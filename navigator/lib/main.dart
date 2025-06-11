import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:navigator/pages/page_models/home_page.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Fallbacks if dynamic color isn’t available
  static final _defaultLight = ColorScheme.fromSwatch(primarySwatch: Colors.blue);
  static final _defaultDark  = ColorScheme.fromSwatch(
    primarySwatch: Colors.blue,
    brightness: Brightness.dark,
  );

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightScheme = lightDynamic ?? _defaultLight;
        final darkScheme  = darkDynamic  ?? _defaultDark;

        return MaterialApp(
          title: 'Navigator',
          themeMode: ThemeMode.system,               // ← follow system setting
          theme: ThemeData(                          // ← light theme
            useMaterial3: true,
            colorScheme: lightScheme,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(                      // ← dark theme
            useMaterial3: true,
            colorScheme: darkScheme,
            brightness: Brightness.dark,
            
          ),
          home: HomePage(),
        );
      },
    );
  }
}
