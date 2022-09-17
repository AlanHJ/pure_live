import 'package:flutter/material.dart';

class MyTheme {
  Color primaryColor;

  MyTheme(this.primaryColor);

  get lightThemeData => ThemeData.from(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: primaryColor,
        background: Colors.grey[50],
      ),
      useMaterial3: true,
      textTheme: TextTheme(
        headline1: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
        headline2: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
        headline3: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: primaryColor,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ));

  get darkThemeData => ThemeData.from(
      colorScheme: ColorScheme.fromSeed(
        error: const Color.fromARGB(255, 255, 99, 71),
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        secondary: primaryColor,
        background: const Color.fromARGB(255, 24, 24, 24),
      ),
      useMaterial3: true,
      textTheme: TextTheme(
        headline1: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
        headline2: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
        headline3: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w500,
          color: primaryColor,
        ),
      ));
}
