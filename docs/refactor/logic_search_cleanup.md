# Refactor Plan: Clean up logic_search.dart

## Goal
Reduce the size and complexity of `logic_search.dart` (currently ~450 lines) by extracting unrelated responsibilities. This aligns with the "Single Responsibility Principle" and keeps file sizes well below the 500-line limit.

## Current State
`lib/screens/desk_tidy_home/logic_search.dart` currently contains:
- **Search Logic**: Indexing, filtering, keyboard navigation for search results.
- **Window Controls**: `_toggleMaximize`, `_minimizeWindow`, `_closeWindow`.
- **Navigation Logic**: `_onNavigationRailItemSelected`, `_onNavigationRailPointer`.
- **Auto Refresh Logic**: `_setupAutoRefresh`, `_autoRefreshTick`.

## Proposed Changes
We will split `logic_search.dart` into focusing solely on search, and move other logic to new dedicated `part` files.

### 1. [NEW] `lib/screens/desk_tidy_home/logic_window_controls.dart`
Move the following methods here:
- `_toggleMaximize`
- `_minimizeWindow`
- `_closeWindow`

### 2. [NEW] `lib/screens/desk_tidy_home/logic_refresh.dart`
Move the following methods here:
- `_setupAutoRefresh`
- `_onMainWindowPresented`
- `_autoRefreshTick`
- `_autoRefreshProbeInFlight` (logic only)

### 3. [NEW] `lib/screens/desk_tidy_home/logic_navigation.dart`
Move the following methods here:
- `_onNavigationRailItemSelected`
- `_onNavigationRailPointer`
- `_showHiddenMenu`
- `_cancelShortcutLoad` (related to nav switch)

### 4. [MODIFY] `lib/screens/desk_tidy_home/logic_search.dart`
Will only contain:
- `_buildSearchIndex`
- `_getSearchIndex`
- `_handleSearchNavigation`
- `_ensureSearchSelectionVisible`
- `_openSelectedSearchResult`
- `_updateSearchQuery`
- `_clearSearch`
- `_calculateLayoutMetrics`

## Implementation Steps
1. Create the new files.
2. Update `lib/screens/desk_tidy_home_page.dart` to include the new parts.
3. Move the code.
4. Verify compilation and functionality.
