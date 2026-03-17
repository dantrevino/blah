import 'package:flutter/material.dart';
import 'ui/home/home_screen.dart';

class BlahApp extends StatelessWidget {
  const BlahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'blah',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
