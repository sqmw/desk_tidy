# Refactor Log: Architecture & Performance Optimization

**Date:** 2026-02-04
**Status:** Completed

## 1. Architecture Decoupling
Addressed the "God Object" issue in `DeskTidyHomePage` by extracting specific logic into dedicated services.

### Changes
- **New Service:** `HotCornerService` (`lib/services/hot_corner_service.dart`)
    - Encapsulates hot corner detection loop and coordinate logic.
    - Removes timer management from UI state.
- **New Service:** `DesktopVisibilityService` (`lib/services/desktop_visibility_service.dart`)
    - Manages desktop icon visibility polling and persistence.
    - Provides a centralized API for visibility checks.
- **Refactor:** `DeskTidyHomePage` now consumes these services instead of implementing the logic directly.

## 2. WindowDockManager Encapsulation
Reduced coupling between UI and window management logic.

### Changes
- **Callbacks Removed:** Removed `getWindowHandle`, `isCursorInsideWindow`, `dismissToTray` callbacks from `WindowDockManager` constructor.
- **Event Driven:** Introduced `DockEvent` stream. UI now listens for `DockEventDismissRequested` instead of passing a callback.
- **Internal Logic:** Moved `isCursorInsideWindow` logic inside `WindowDockManager` class.

## 3. Rendering Performance
Optimized heavy rendering operations involving `GlassContainer` and animations.

### Changes
- **RepaintBoundary:** Added `RepaintBoundary` to:
    - Main `Stack` in `Desk Tidy Home Page` (wraps `AnimatedSlide`/`AnimatedOpacity`).
    - `GridView` in `ApplicationContent` logic.
    - `ListView` in `AllPage` (Merge View).
    - `GridView` in `FolderPage`.
- **Benefit:** Isolates the scrollable grid and animation layers from triggering expensive `BackdropFilter` repaints on the parent/background layers.
