part of '../desk_tidy_home_page.dart';

ThemeModeOption _themeModeOption = ThemeModeOption.dark;
bool _showHidden = false;
bool _autoRefresh = false;
bool _autoLaunch = true;
double _iconSize = 24;

/// 窗口唤醒模式
enum _ActivationMode { hotkey, hotCorner, tray }
