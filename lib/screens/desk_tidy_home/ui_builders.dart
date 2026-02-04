part of '../desk_tidy_home_page.dart';

extension _DeskTidyHomeUiBuilders on _DeskTidyHomePageState {
  Widget _buildTitleBar() {
    final theme = Theme.of(context);
    final scale = _uiScale(context);
    final titleBarHeight = 34.0 * scale;
    final titleButtonSize = 32.0 * scale;
    return MouseRegion(
      onEnter: (_) {},
      child: GestureDetector(
        onPanStart: (_) => windowManager.startDragging(),
        child: GlassContainer(
          opacity: _chromeOpacity,
          blurSigma: _chromeBlur,
          borderRadius: BorderRadius.zero,
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.16),
              width: 0.8,
            ),
          ),
          child: SizedBox(
            height: titleBarHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10 * scale),
              child: Row(
                children: [
                  const Spacer(),
                  Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints.tightFor(
                          width: titleButtonSize,
                          height: titleButtonSize,
                        ),
                        icon: const Icon(Icons.remove),
                        onPressed: _minimizeWindow,
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints.tightFor(
                          width: titleButtonSize,
                          height: titleButtonSize,
                        ),
                        icon: Icon(
                          _isMaximized ? Icons.filter_none : Icons.crop_square,
                        ),
                        onPressed: _toggleMaximize,
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints.tightFor(
                          width: titleButtonSize,
                          height: titleButtonSize,
                        ),
                        icon: const Icon(Icons.close),
                        onPressed: _closeWindow,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final effectiveShowHidden = _showHidden;
    switch (_selectedIndex) {
      case 0:
        return _buildApplicationContent();
      case 1:
        return AllPage(
          desktopPath: _desktopPath,
          showHidden: effectiveShowHidden,
          beautifyIcons: _beautifyDesktopIcons,
          beautifyStyle: _beautifyStyle,
        );
      case 2:
        return SettingsPage(
          transparency: (1.0 - _backgroundOpacity).clamp(0.0, 1.0),
          frostStrength: _frostStrength,
          iconSize: _iconSize,
          showHidden: _showHidden,
          autoRefresh: _autoRefresh,
          autoLaunch: _autoLaunch,
          hideDesktopItems: _hideDesktopItems,
          enableDesktopBoxes: _enableDesktopBoxes,
          showRecycleBin: _showRecycleBin,
          showThisPC: _showThisPC,
          showControlPanel: _showControlPanel,
          showNetwork: _showNetwork,
          showUserFiles: _showUserFiles,
          iconIsolatesEnabled: _iconIsolatesEnabled,
          themeModeOption: _themeModeOption,
          backgroundPath: _backgroundImagePath,
          beautifyAppIcons: _beautifyAppIcons,
          beautifyDesktopIcons: _beautifyDesktopIcons,
          beautifyStyle: _beautifyStyle,
          onTransparencyChanged: (v) {
            _setState(() => _backgroundOpacity = (1.0 - v).clamp(0.0, 1.0));
            AppPreferences.saveTransparency(v);
          },
          onFrostStrengthChanged: (v) {
            _setState(() => _frostStrength = v);
            appFrostStrengthNotifier.value = v;
            AppPreferences.saveFrostStrength(v);
          },
          onIconSizeChanged: (v) {
            _setState(() => _iconSize = v);
            AppPreferences.saveIconSize(v);
          },
          onShowHiddenChanged: (v) {
            _setState(() => _showHidden = v);
            AppPreferences.saveShowHidden(v);
            _loadShortcuts();
          },
          onAutoRefreshChanged: (v) {
            _setState(() => _autoRefresh = v);
            AppPreferences.saveAutoRefresh(v);
            _setupAutoRefresh();
          },
          onAutoLaunchChanged: (v) async {
            final previous = _autoLaunch;
            _setState(() => _autoLaunch = v);
            final ok = await setAutoLaunchEnabled(v);
            if (!mounted) return;
            if (!ok) {
              _setState(() => _autoLaunch = previous);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('开机启动设置失败')));
              return;
            }
            await AppPreferences.saveAutoLaunch(v);
          },
          onHideDesktopItemsChanged: _handleHideDesktopItemsChanged,
          onEnableDesktopBoxesChanged: (v) async {
            _setState(() => _enableDesktopBoxes = v);
            await AppPreferences.saveEnableDesktopBoxes(v);
            await BoxLauncher.instance.updateBoxes(
              enabled: v,
              desktopPath: _desktopPath,
            );
          },
          onIconIsolatesChanged: (v) {
            setIconIsolatesEnabled(v);
            _setState(() => _iconIsolatesEnabled = iconIsolatesEnabled);
            AppPreferences.saveIconIsolatesEnabled(v);
          },
          onShowRecycleBinChanged: (v) {
            _setState(() => _showRecycleBin = v);
            AppPreferences.saveShowRecycleBin(v);
            _loadShortcuts();
          },
          onShowThisPCChanged: (v) {
            _setState(() => _showThisPC = v);
            AppPreferences.saveShowThisPC(v);
            _loadShortcuts();
          },
          onShowControlPanelChanged: (v) {
            _setState(() => _showControlPanel = v);
            AppPreferences.saveShowControlPanel(v);
            _loadShortcuts();
          },
          onShowNetworkChanged: (v) {
            _setState(() => _showNetwork = v);
            AppPreferences.saveShowNetwork(v);
            _loadShortcuts();
          },
          onShowUserFilesChanged: (v) {
            _setState(() => _showUserFiles = v);
            AppPreferences.saveShowUserFiles(v);
            _loadShortcuts();
          },
          onThemeModeChanged: (v) {
            _handleThemeChange(v);
            if (v != null) {
              AppPreferences.saveThemeMode(v);
            }
          },
          onBackgroundPathChanged: (path) async {
            final previous = _backgroundImagePath;
            final saved = await AppPreferences.backupAndSaveBackgroundPath(
              path,
            );
            if (!mounted) return;
            if (saved != null && saved.isNotEmpty) {
              unawaited(FileImage(File(saved)).evict());
            } else if (previous != null && previous.isNotEmpty) {
              unawaited(FileImage(File(previous)).evict());
            }
            _setState(() => _backgroundImagePath = saved);
          },
          onBeautifyAllChanged: (v) {
            _setState(() {
              _beautifyAppIcons = v;
              _beautifyDesktopIcons = v;
            });
            AppPreferences.saveBeautifyAppIcons(v);
            AppPreferences.saveBeautifyDesktopIcons(v);
          },
          onBeautifyStyleChanged: (style) {
            _setState(() => _beautifyStyle = style);
            AppPreferences.saveBeautifyStyle(style);
          },
          onBeautifyAppIconsChanged: (v) {
            _setState(() => _beautifyAppIcons = v);
            AppPreferences.saveBeautifyAppIcons(v);
          },
          onBeautifyDesktopIconsChanged: (v) {
            _setState(() => _beautifyDesktopIcons = v);
            AppPreferences.saveBeautifyDesktopIcons(v);
          },
        );
      default:
        return _buildApplicationContent();
    }
  }
}
