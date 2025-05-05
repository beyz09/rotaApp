import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = Color(0xFFDCF0D8); // Figma'daki yeşil tonu

    return Scaffold(
      backgroundColor: backgroundColor,
      body: const Center(
        child: Text(
          'Ana Sayfa',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
