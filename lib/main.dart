import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/desk_tidy_home_page.dart';
import 'providers/theme_notifier.dart';
import 'utils/single_instance.dart';
import 'utils/app_preferences.dart';
import 'widgets/operation_progress_bar.dart';

Future<void> main() async {
  // Guard as early as possible to prevent extra processes from fully spinning up.
  final windowReady = Completer<void>();
  final isPrimary = await SingleInstance.ensure(
    onActivate: () async {
      await windowReady.future;
      await windowManager.show();
      await windowManager.restore();

      // [Fix] Force a tiny resize to trigger WM_SIZE and sync child HWND in Release mode
      final currentSize = await windowManager.getSize();
      await windowManager.setSize(
        Size(currentSize.width + 1, currentSize.height),
      );
      await windowManager.setSize(currentSize);

      await windowManager.setAlignment(Alignment.center);
      await windowManager.focus();
    },
  );
  if (!isPrimary) return;

  WidgetsFlutterBinding.ensureInitialized();

  // Keep decoded image cache bounded. Desktop icon grids can decode many images
  // when scrolling; without a cap, process memory may grow and stay high.
  PaintingBinding.instance.imageCache.maximumSize = 300;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 80 << 20; // 80MB

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
            fontFamilyFallback: const ['Microsoft YaHei'],
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            fontFamily: 'Segoe UI',
            fontFamilyFallback: const ['Microsoft YaHei'],
            useMaterial3: true,
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
          themeMode: themeMode,
          home: const Stack(
            children: [DeskTidyHomePage(), OperationProgressBar()],
          ),
        );
      },
    );
  }
}
