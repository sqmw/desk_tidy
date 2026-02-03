import 'dart:async';
import 'dart:io';
import 'dart:collection';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../utils/desktop_helper.dart';
import '../models/icon_beautify_style.dart';
import '../widgets/folder_picker_dialog.dart';
import '../widgets/glass.dart';
import '../widgets/beautified_icon.dart';
import '../widgets/operation_progress_bar.dart';

part 'folder_page/state.dart';
part 'folder_page/data_loading.dart';
part 'folder_page/navigation.dart';
part 'folder_page/menus.dart';
part 'folder_page/actions.dart';
part 'folder_page/ui_build.dart';
part 'folder_page/entity_icon.dart';
