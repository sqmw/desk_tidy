import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../models/shortcut_item.dart';
import '../models/icon_beautify_style.dart';
import '../utils/desktop_helper.dart';
import '../widgets/beautified_icon.dart';
import '../models/system_items.dart';

part 'shortcut_card/state.dart';
part 'shortcut_card/selection_overlay.dart';
part 'shortcut_card/menu.dart';
part 'shortcut_card/label_overlay.dart';
part 'shortcut_card/ui_build.dart';
