import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../utils/desktop_helper.dart';
import '../models/icon_beautify_style.dart';
import '../widgets/entity_detail_bar.dart';
import '../widgets/beautified_icon.dart';
import '../widgets/floating_rename_overlay.dart';
import '../widgets/folder_picker_dialog.dart';
import '../widgets/glass.dart';
import '../widgets/middle_ellipsis_text.dart';
import '../widgets/operation_progress_bar.dart';
import '../models/file_item.dart';

/// 实体筛选模式

part 'all_page/constants.dart';
part 'all_page/models.dart';
part 'all_page/state.dart';
part 'all_page/filter_sort.dart';
part 'all_page/data_loading.dart';
part 'all_page/navigation.dart';
part 'all_page/menus.dart';
part 'all_page/actions.dart';
part 'all_page/ui_build.dart';
part 'all_page/entity_icon.dart';
