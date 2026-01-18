import 'dart:async';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/desk_tidy_home_page.dart';
import 'providers/theme_notifier.dart';
import 'utils/single_instance.dart';
import 'utils/app_preferences.dart';

Future<void> main() async {
  // Guard as early as possible to prevent extra processes from fully spinning up.
  final windowReady = Completer<void>();
  final isPrimary = await SingleInstance.ensure(
    onActivate: () async {
      await windowReady.future;
      await windowManager.show();
      await windowManager.restore();
      await windowManager.setAlignment(Alignment.center);
      await windowManager.focus();
    },
  );
  if (!isPrimary) return;

  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final bounds = await AppPreferences.loadWindowBounds();

  try {
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        title: 'desk_tidy',
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: true,
        size: bounds == null
            ? null
            : Size(bounds.width.toDouble(), bounds.height.toDouble()),
        center: bounds == null,
      ),
      () async {
        // Prevent Windows Aero Snap when dragging
        await windowManager.setMaximizable(false);
        if (bounds != null) {
          await windowManager.setPosition(
            Offset(bounds.x.toDouble(), bounds.y.toDouble()),
          );
        }
        await windowManager.hide();
      },
    );
  } finally {
    if (!windowReady.isCompleted) {
      windowReady.complete();
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Desk Tidy',
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            fontFamily: 'Segoe UI',
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            fontFamily: 'Segoe UI',
          ),
          themeMode: themeMode,
          home: const DeskTidyHomePage(),
        );
      },
    );
  }
}
