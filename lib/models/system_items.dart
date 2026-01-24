/// 系统项目定义
///
/// 定义可在应用列表中显示的 Windows 系统项目。
library;

import 'dart:io';
import 'package:flutter/material.dart';

/// 系统项目类型
enum SystemItemType { thisPC, recycleBin, controlPanel, network, userFiles }

/// 系统项目信息
class SystemItemInfo {
  final SystemItemType type;
  final String name;
  final String shellCommand;
  final String clsid;
  final String iconResource;
  final IconData fallbackIcon;

  const SystemItemInfo({
    required this.type,
    required this.name,
    required this.shellCommand,
    required this.clsid,
    required this.iconResource,
    required this.fallbackIcon,
  });

  /// 所有系统项目定义
  static const Map<SystemItemType, SystemItemInfo> all = {
    SystemItemType.thisPC: SystemItemInfo(
      type: SystemItemType.thisPC,
      name: '此电脑',
      shellCommand: 'shell:MyComputerFolder',
      clsid: 'shell:::{20D04FE0-3AEA-1069-A2D8-08002B30309D}',
      iconResource: r'C:\Windows\System32\imageres.dll,-109',
      fallbackIcon: Icons.computer,
    ),
    SystemItemType.recycleBin: SystemItemInfo(
      type: SystemItemType.recycleBin,
      name: '回收站',
      shellCommand: 'shell:RecycleBinFolder',
      clsid: 'shell:::{645FF040-5081-101B-9F08-00AA002F954E}',
      iconResource: r'C:\Windows\System32\imageres.dll,-55',
      fallbackIcon: Icons.delete_outline,
    ),
    SystemItemType.controlPanel: SystemItemInfo(
      type: SystemItemType.controlPanel,
      name: '控制面板',
      shellCommand: 'shell:ControlPanelFolder',
      clsid: 'shell:::{21EC2020-3AEA-1069-A2DD-08002B30309D}',
      iconResource: r'C:\Windows\System32\imageres.dll,-27',
      fallbackIcon: Icons.settings_applications,
    ),
    SystemItemType.network: SystemItemInfo(
      type: SystemItemType.network,
      name: '网络',
      shellCommand: 'shell:NetworkPlacesFolder',
      clsid: 'shell:::{208D2C60-3AEA-1069-A2D7-08002B30309D}',
      iconResource: r'C:\Windows\System32\imageres.dll,-25',
      fallbackIcon: Icons.network_check,
    ),
    SystemItemType.userFiles: SystemItemInfo(
      type: SystemItemType.userFiles,
      name: '个人文件夹',
      shellCommand: 'shell:UsersFilesFolder',
      clsid: 'shell:::{59031A47-3F72-44A7-89C5-5595FE6B30EE}',
      iconResource: r'C:\Windows\System32\imageres.dll,-123',
      fallbackIcon: Icons.folder_shared,
    ),
  };

  /// 打开系统项目
  static Future<void> open(SystemItemType type) async {
    final info = all[type];
    if (info == null) return;
    await Process.run('explorer.exe', [info.shellCommand]);
  }

  /// 生成虚拟路径（用于唯一标识）
  static String virtualPath(SystemItemType type) {
    return 'system://${type.name}';
  }
}
