import 'package:flutter/material.dart';

import 'main_navigation.dart';

// This file starts the app and loads the main navigation scaffold.
void main() {
  runApp(const PosturerApp());
}

class PosturerApp extends StatelessWidget {
  const PosturerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Posturer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MainNavigation(),
    );
  }
}
