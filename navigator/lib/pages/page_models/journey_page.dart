import 'package:navigator/models/journey.dart';

class JourneyPage 
{
  Journey journey;

  JourneyPage({required this.journey})
  {
    // Initialize line colors for all legs in the journey
    journey.initializeLineColors();
  }
}