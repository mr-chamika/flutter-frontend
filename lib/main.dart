import 'package:chat_app/pages/login.dart';
import 'package:flutter/material.dart';
import 'package:chat_app/pages/change_location.dart';
import 'package:chat_app/pages/bottom_nav.dart';
import 'package:chat_app/pages/loading.dart';
import 'package:chat_app/pages/profile.dart';
import 'package:chat_app/pages/signup.dart';
import 'package:chat_app/pages/chat_screen.dart';

void main() {
  runApp(
    MaterialApp(
      initialRoute: '/',
      routes: {
        '/login': (context) => (Login()),
        '/': (context) => (Loading()),
        '/home': (context) => (BottomNav()),
        '/location': (context) => (ChangeLocation()),
        '/signup': (context) => (SignupPage()),
        '/profile': (context) => (ProfilePage()),
        '/chat': (context) => ChatScreen(),
      },
    ),
  );
}
