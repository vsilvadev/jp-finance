import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'router.dart';

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class JapanTripApp extends StatelessWidget {
  const JapanTripApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AppScope(
    controller: controller,
    child: MaterialApp.router(
      title: 'Japão',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB9363E),
          surface: const Color(0xFFFCFBF8),
        ),
        scaffoldBackgroundColor: const Color(0xFFFCFBF8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFCFBF8),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFECE9E3)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          filled: true,
          fillColor: const Color(0xFFFAF9F6),
        ),
      ),
      routerConfig: appRouter,
    ),
  );
}
