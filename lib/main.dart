import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: BettaniWeatherScreen(),
  ));
}

class BettaniWeatherScreen extends StatelessWidget {
  const BettaniWeatherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bettani Weather'),
        backgroundColor: Colors.blueAccent,
      ),
      body: const Center(
        child: Text(
          'Bettani Weather App is ready for Mobile (APK)!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}