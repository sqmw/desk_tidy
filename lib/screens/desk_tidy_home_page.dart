import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:async';
import 'dart:ffi' hide Size; // For COM in Isolate
import 'package:win32/win32.dart'; // For CoInitialize/CoUninitialize

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../models/shortcut_item.dart';
import '../models/app_category.dart';
import '../models/icon_beautify_style.dart';
import '../setting/settings_page.dart';
import '../providers/frost_strength_notifier.dart';
import '../providers/theme_notifier.dart';
import '../utils/app_preferences.dart';
import '../utils/app_search_index.dart';
import '../utils/fuzzy_matcher.dart';
import '../utils/desktop_helper.dart';
import '../utils/tray_helper.dart';
import '../widgets/glass.dart';
import '../widgets/shortcut_card.dart';
import '../widgets/category_strip.dart';
import '../widgets/selectable_shortcut_tile.dart';
import 'all_page.dart';
import '../services/window_dock_manager.dart';
import '../services/box_launcher.dart';
import '../widgets/operation_progress_bar.dart';
import '../services/hotkey_service.dart';
import '../models/system_items.dart';
import '../services/hot_corner_service.dart';
import '../services/desktop_visibility_service.dart';

part 'desk_tidy_home/constants.dart';
part 'desk_tidy_home/state.dart';
part 'desk_tidy_home/logic_bootstrap.dart';
part 'desk_tidy_home/categories/persistence.dart';
part 'desk_tidy_home/categories/shortcut_loading.dart';
part 'desk_tidy_home/categories/icon_hydration.dart';
part 'desk_tidy_home/categories/category_crud.dart';
part 'desk_tidy_home/categories/category_menu.dart';
part 'desk_tidy_home/categories/utils.dart';
part 'desk_tidy_home/logic_search.dart';
part 'desk_tidy_home/logic_runtime.dart';
part 'desk_tidy_home/logic_window_controls.dart';
part 'desk_tidy_home/logic_refresh.dart';
part 'desk_tidy_home/logic_navigation.dart';
part 'desk_tidy_home/ui_builders.dart';
part 'desk_tidy_home/handlers/system_and_theme.dart';
part 'desk_tidy_home/handlers/search_widgets.dart';
part 'desk_tidy_home/handlers/application_content.dart';
part 'desk_tidy_home/handlers/shortcut_launch.dart';
part 'desk_tidy_home/scan_isolate.dart';
