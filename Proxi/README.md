# Proxi iOS App

A SwiftUI-based iOS application for Ultra-Wideband (UWB) device management and social networking.

## 📁 Project Structure

### 🏗️ Core Architecture

```
Proxi/
├── Managers/           # Business logic and data management
├── Views/             # SwiftUI views and UI components
│   ├── Screens/       # Main app screens
│   ├── Components/    # Reusable UI components
│   └── Navigation/    # Navigation-related views
├── Extensions/        # Swift extensions and utilities
├── Models/           # Data models and 3D assets
├── Utilities/        # Helper classes and custom utilities
├── Base.lproj/       # Localization and storyboards
└── Assets.xcassets/  # App icons and image assets
```

## 📋 Detailed Directory Structure

### 🎯 Managers/
Core business logic and data management classes.

- **BLEManager.swift** - Bluetooth Low Energy device management
- **UserManager.swift** - User profile and authentication management
- **FriendsManager.swift** - Social networking and friend management
- **LocationManager.swift** - Location services and permissions
- **NISessionManager.swift** - Nearby Interaction session management
- **BluetoothLECentral.swift** - BLE central manager implementation

### 🖥️ Views/

#### Screens/
Main application screens and primary user interfaces.

- **HomeView.swift** - Main dashboard and home screen
- **SettingsView.swift** - App settings and device management
- **FriendsView.swift** - Social networking and friend discovery
- **DiscoverView.swift** - Device discovery interface

#### Components/
Reusable UI components and custom views.

- **AccessoriesTable.swift** - Device accessories table view
- **ArrowView.swift** - Directional arrow indicators
- **DeviceRowView.swift** - Individual device row display
- **QorvoDeviceRowView.swift** - Qorvo-specific device rows
- **DebugLogView.swift** - Debug information display
- **CompassView_Backup.swift** - Compass interface (backup)
- **QorvoViewController.swift** - Qorvo UWB controller integration
- **DeviceView.swift** - Device detail views
- **LocationFields.swift** - Location data display fields
- **SeparatorView.swift** - UI separators and dividers
- **WorldView.swift** - 3D world view for AR features

#### Navigation/
Navigation-related components and top-level UI.

- **TopBarView.swift** - Main navigation bar with profile
- **SideBarMenuView.swift** - Sidebar navigation menu

### 🔧 Extensions/
Swift extensions and utility functions.

- **Extensions.swift** - General Swift extensions

### 📊 Models/
Data models and 3D assets.

- **3d_arrow.usdz** - 3D arrow model for AR

### 🛠️ Utilities/
Helper classes, custom utilities, and assets.

- **QorvoColors.swift** - Custom color definitions
- **QorvoFonts.swift** - Typography and font management
- **DesignConstraints.swift** - UI design constants
- **CustomActivityIndicator.swift** - Custom loading indicators
- **Feedback.swift** - Haptic feedback utilities
- **SVG Assets/** - Vector graphics and icons

## 🚀 Key Features

### 🔗 UWB Device Management
- Real-time device scanning and discovery
- BLE connection management
- UWB ranging and direction detection
- Device status monitoring

### 👥 Social Networking
- Friend discovery and management
- Profile customization
- Social interactions

### ⚙️ Settings & Configuration
- Developer mode with debug features
- Device management interface
- Profile editing capabilities
- App preferences

### 🎨 Modern UI/UX
- Dark theme design
- SwiftUI-based interface
- Responsive layouts
- Custom components

## 🔧 Development

### Prerequisites
- Xcode 14.0+
- iOS 16.0+
- Swift 5.7+

### Key Dependencies
- **SwiftUI** - Modern UI framework
- **CoreBluetooth** - Bluetooth functionality
- **NearbyInteraction** - UWB capabilities
- **PhotosUI** - Image picker integration

### Architecture Patterns
- **MVVM** - Model-View-ViewModel pattern
- **Environment Objects** - SwiftUI state management
- **Manager Classes** - Centralized business logic
- **Component-Based** - Reusable UI components

## 📱 App Flow

1. **Launch** → HomeView (Dashboard)
2. **Navigation** → Sidebar menu for different sections
3. **Device Management** → SettingsView for UWB devices
4. **Social Features** → FriendsView for networking
5. **Profile** → SettingsView for user customization

## 🎯 Key Components

### BLEManager
Manages Bluetooth Low Energy connections and device discovery.

### UserManager
Handles user profile data, authentication, and preferences.

### FriendsManager
Manages social networking features and friend relationships.

### SettingsView
Central hub for device management and app configuration.

## 🔍 Debug Features

When developer mode is enabled (tap version 5 times):
- Debug log access
- Device ID display
- Enhanced debugging information

## 📄 License

© 2024 Proxi Team. All rights reserved. 