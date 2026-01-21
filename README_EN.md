# Desk Tidy

> 🪟 **Windows Desktop Organizer** — Keep your desktop clean and tidy

**[🇨🇳 中文](README.md)** | **🇬🇧 English**

<!-- Screenshot: Place in .github/screenshots/hero.png -->
![Preview](.github/screenshots/hero.png)

---

## ✨ Highlights

<table>
<tr>
<td width="50%">

### ⚡ Ultra Lightweight
- **CPU usage ≈ 0%** (idle state)
- **Memory ~280MB**
- **Installer only 11.8MB**, 58MB installed
- Runs silently in background

</td>
<td width="50%">

### 🎯 Instant Activation
- **Global hotkey** `Ctrl + Shift + Space`
- Alternate hotkey `Alt + Shift + Space`
- **System tray** right-click menu
- Hot corner (Ctrl + mouse to top-left)

</td>
</tr>
<tr>
<td>

### 🎨 Modern Visuals
- Frosted glass effect, blends with desktop
- Customizable transparency & blur
- Custom background image support
- Dark / Light / System theme

</td>
<td>

### 🔍 Smart Search
- **Pinyin initials** fuzzy matching
- Keyboard ↑↓←→ navigation, Enter to launch
- Auto-focus search on activation

</td>
</tr>
</table>

---

## 🖼️ Screenshots

<!-- Screenshots: Place in .github/screenshots/ folder -->
| App Launcher | File Manager | Settings |
|:---:|:---:|:---:|
| ![Apps](.github/screenshots/app_page.png) | ![All](.github/screenshots/all_page.png) | ![Settings](.github/screenshots/settings_page.png) |

---

## 🚀 Core Features

### 📱 Quick App Launch
- Auto-scan desktop shortcuts
- **Real icons** display, not generic placeholders
- Double-click / Enter to launch instantly
- Support **category organization**, custom app groups

<!-- Demo: Place GIF in .github/screenshots/demo.gif -->
![Demo](.github/screenshots/demo.gif)

### 📁 Unified File Management
- Desktop files/folders at a glance
- Context menu: Open, Move, Delete, Copy
- **Open with** app selection
- Real-time operation feedback

### 🧲 Magnetic Auto-Hide

Smart window docking for full-screen workflow:

| Feature | Description |
|---------|-------------|
| **Dock Trigger** | Drag window to **top-left corner** and release |
| **Dock Zone** | Approximately **200×150 pixels** (auto-adapts to screen) |
| **Auto Hide** | Hides to tray **~260ms** after mouse leaves |
| **Reactivate** | Use hotkey or tray menu to show again |

> 💡 **Tip**: Docking won't trigger while dragging — only when you release the mouse within the dock zone.

### 🔥 Hot Corner Activation (Optional)

> With global hotkeys available, hot corner serves as a **supplementary method** for mouse-oriented users.

| Hot Zone | Top-left corner, ~1/4 screen width, ~10px height |
|----------|--------------------------------------------------|
| Trigger | Hold `Ctrl` + move mouse into hot zone |
| Use Case | Quick activation when keyboard isn't convenient |

### 🎛️ Highly Customizable

| Setting | Description |
|---------|-------------|
| Window Opacity | 0% ~ 100% stepless adjustment |
| Blur Intensity | From clear to misty |
| Icon Size | 24px ~ 96px |
| Background | Custom wallpaper support |
| Theme | Dark / Light / Follow System |
| Auto Start | One-click setup |

### 🖥️ Desktop Icon Management
- **One-click hide/show** system desktop icons
- Keep native desktop clean
- Access everything through Desk Tidy

### 📦 Desktop Organizer Boxes

> Display desktop files and folders in separate floating windows, keeping your desktop clean while maintaining quick access.

| Feature | Description |
|---------|-------------|
| **Categorized Display** | Folders and files shown in separate windows |
| **Appearance Sync** | Auto-inherits transparency, blur and other settings from main app |
| **Smart Positioning** | Drag to position, auto-remembers location |
| **Launch with Main App** | One-click enable/disable in settings |

<!-- Box screenshot: Place in .github/screenshots/box_demo.png -->
![Desktop Organizer Boxes](.github/screenshots/box_demo.png)

> 📁 Organizer boxes are implemented by the companion project [desk_tidy_box](https://github.com/sqmw/desk_tidy_box), working alongside the main app.

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Function |
|----------|----------|
| `Ctrl + Shift + Space` | Activate window (Primary) |
| `Alt + Shift + Space` | Activate window (Alternate) |
| `↑` `↓` `←` `→` | Navigate selection |
| `Tab` / `Shift + Tab` | Linear navigation |
| `Enter` | Open selected item |
| `Esc` | Hide window |

---

## 📦 Installation

### Option 1: Download Installer (Recommended)

| Item | Size |
|------|------|
| Installer | **11.8 MB** |
| Installed | **58 MB** |

Download from [Releases](https://github.com/your-username/desk_tidy/releases).

### Option 2: Build from Source

```bash
# Clone repository
git clone https://github.com/your-repo/desk_tidy.git
cd desk_tidy

# Install dependencies
flutter pub get

# Run
flutter run -d windows

# Build release
flutter build windows --release
```

---

## 🔧 Tech Stack

- **Framework**: Flutter (Windows Desktop)
- **Languages**: Dart + C++ (Win32 native extensions)
- **Icon Extraction**: Windows Shell API
- **Window Management**: window_manager + native HWND operations

---

## 📋 System Requirements

| Item | Requirement |
|------|-------------|
| OS | Windows 11 (64-bit); Win10 theoretically compatible but not fully tested |
| Disk Space | ~58 MB |
| Memory | ~280 MB |

---

## 🗺️ Roadmap

- [x] Global hotkey activation
- [x] Pinyin fuzzy search
- [x] Category management
- [x] Magnetic auto-hide
- [x] Desktop organizer boxes
- [ ] Multi-monitor support
- [ ] Plugin system
- [ ] Cloud config sync

---

## 📄 License

MIT License

---

<p align="center">
  <b>⭐ If you find this useful, please give it a Star!</b>
</p>
