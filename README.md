# Proxi - UWB Social Networking App

A modern SwiftUI-based iOS application for Ultra-Wideband (UWB) device management and social networking, featuring real-time ranging, device discovery, and social interactions.

## 🏗️ Project Architecture

### 📁 Reorganized File Structure

```
Proxi-APP/
├── 📱 Proxi/                          # Main iOS Application
│   ├── 🎯 Core/                       # Core application files
│   │   ├── AppDelegate.swift          # Application lifecycle management
│   │   ├── ProxiApp.swift             # Main app entry point
│   │   ├── ContentView.swift          # Root SwiftUI view
│   │   ├── Info.plist                 # App configuration
│   │   └── Proxi.entitlements         # App capabilities
│   │
│   ├── 🎮 Controllers/                # View controllers and main logic
│   │   ├── QorvoViewController.swift  # UWB compass and ranging display
│   │   ├── QorvoDemoViewController.swift # Demo UWB functionality
│   │   └── SettingsViewController.swift # Settings and device management
│   │
│   ├── 🧩 Components/                 # Reusable UI components
│   │   ├── 📡 UWB/                    # UWB-specific components
│   │   │   ├── ArrowView.swift        # Directional arrow indicators
│   │   │   ├── WorldView.swift        # 3D world visualization
│   │   │   └── CompassSupView.swift   # Compass support views
│   │   │
│   │   ├── 📱 Device/                 # Device management components
│   │   │   ├── DeviceView.swift       # Device detail views
│   │   │   ├── DeviceRowView.swift    # Device list rows
│   │   │   ├── QorvoDeviceRowView.swift # Qorvo-specific device rows
│   │   │   ├── AccessoriesTable.swift # Device accessories table
│   │   │   └── SingleCell.swift       # Individual device cells
│   │   │
│   │   ├── 🎨 UI/                     # General UI components
│   │   │   ├── SeparatorView.swift    # Visual separators
│   │   │   └── DebugLogView.swift     # Debug information display
│   │   │
│   │   └── 📝 Forms/                  # Form and input components
│   │       ├── Field.swift            # Reusable form fields
│   │       └── LocationFields.swift   # Location data input fields
│   │
│   ├── 🖥️ Views/                      # Main app screens
│   │   ├── Screens/                   # Primary app screens
│   │   │   ├── HomeView.swift         # Main dashboard
│   │   │   ├── SettingsView.swift     # App settings and configuration
│   │   │   ├── FriendsView.swift      # Social networking features
│   │   │   └── DiscoverView.swift     # Device and user discovery
│   │   │
│   │   └── Navigation/                # Navigation components
│   │       ├── TopBarView.swift       # Main navigation bar
│   │       └── SideBarMenuView.swift  # Sidebar navigation menu
│   │
│   ├── ⚙️ Managers/                   # Business logic and data management
│   │   ├── BLEManager.swift           # Bluetooth Low Energy management
│   │   ├── UserManager.swift          # User profile and authentication
│   │   ├── FriendsManager.swift       # Social networking management
│   │   ├── LocationManager.swift      # Location services
│   │   ├── NISessionManager.swift     # Nearby Interaction sessions
│   │   └── (BluetoothLECentral consolidated into BLEManager.swift)
│   │
│   ├── 🔧 Utilities/                  # Helper classes and utilities
│   │   ├── QorvoColors.swift          # Custom color definitions
│   │   ├── QorvoFonts.swift           # Typography management
│   │   ├── DesignConstraints.swift    # UI design constants
│   │   ├── CustomActivityIndicator.swift # Loading indicators
│   │   ├── Feedback.swift             # Haptic feedback utilities
│   │   └── SVG Assets/                # Vector graphics and icons
│   │
│   ├── 📚 Extensions/                 # Swift extensions
│   │   └── Extensions.swift           # General Swift extensions
│   │
│   ├── 📊 Models/                     # Data models and assets
│   │   └── 3d_arrow.usdz              # 3D arrow model for AR
│   │
│   ├── 🔗 Shared/                     # Shared protocols and interfaces
│   │   └── QorvoProtocol.swift        # UWB communication protocol
│   │
│   ├── 📦 Resources/                  # App resources
│   │   └── Localizable.strings        # Localization strings
│   │
│   ├── 🎨 Assets.xcassets/            # App icons and images
│   ├── 📱 Base.lproj/                 # Localization and storyboards
│   └── 🗂️ Legacy/                     # Legacy and backup files
│       └── CompassView_Backup.swift   # Backup compass implementation
│
├── 🔌 Arduino/                        # Arduino UWB firmware
│   ├── code.ino                       # Main Arduino sketch (Multi-device enhanced)
│   ├── config.h                       # Configuration constants
│   └── MULTI_DEVICE_README.md         # Arduino documentation
│
├── 🧪 ProxiTests/                     # Unit tests
├── 🎯 ProxiUITests/                   # UI tests
└── 📋 Proxi.xcodeproj/                # Xcode project file
```

## 🚀 Key Features

### 🔗 **UWB Device Management**
- **Real-time Ranging**: Precise distance and direction measurement
- **Multi-Device Support**: Connect to multiple Arduino boards simultaneously
- **BLE Integration**: Seamless Bluetooth Low Energy connectivity
- **Session Management**: Robust UWB session handling and recovery

### 👥 **Social Networking**
- **Friend Discovery**: Find and connect with nearby users
- **Profile Management**: Customizable user profiles and preferences
- **Real-time Status**: Live updates on friend locations and activities
- **Social Interactions**: Built-in social features for networking

### ⚙️ **Advanced Settings**
- **Developer Mode**: Enhanced debugging and testing features
- **Device Configuration**: Comprehensive device management interface
- **Performance Tuning**: Optimizable ranging and connection settings
- **Debug Tools**: Real-time monitoring and logging capabilities

### 🎨 **Modern UI/UX**
- **Dark Theme**: Elegant dark mode design
- **SwiftUI Framework**: Modern, responsive interface
- **Custom Components**: Reusable, well-designed UI elements
- **Accessibility**: Full accessibility support

## 🔧 Technical Stack

### **iOS Development**
- **Swift 5.7+** - Modern Swift programming
- **SwiftUI** - Declarative UI framework
- **iOS 16.0+** - Latest iOS features and APIs
- **Xcode 14.0+** - Development environment

### **Core Frameworks**
- **CoreBluetooth** - Bluetooth Low Energy functionality
- **NearbyInteraction** - UWB capabilities and ranging
- **CoreLocation** - Location services and permissions
- **PhotosUI** - Image picker and media handling

### **Arduino Integration**
- **StellaUWB Library** - UWB communication
- **ArduinoBLE** - Bluetooth Low Energy
- **Multi-Device Support** - Enhanced for multiple connections

## 🏛️ Architecture Patterns

### **MVVM (Model-View-ViewModel)**
- **Models**: Data structures and business logic
- **Views**: SwiftUI user interfaces
- **ViewModels**: State management and data binding

### **Manager Pattern**
- **Centralized Logic**: Business logic in dedicated manager classes
- **Environment Objects**: SwiftUI state management across views
- **Separation of Concerns**: Clear separation between UI and business logic

### **Component-Based Architecture**
- **Reusable Components**: Modular UI components
- **Composition**: Building complex views from simple components
- **Maintainability**: Easy to maintain and extend

## 📱 App Flow

### **1. Launch & Initialization**
```
App Launch → ProxiApp.swift → ContentView.swift → HomeView
```

### **2. Device Discovery & Connection**
```
SettingsView → BLE Scanning → Device Selection → UWB Session
```

### **3. Social Features**
```
FriendsView → Friend Discovery → Profile Management → Social Interactions
```

### **4. UWB Ranging**
```
QorvoViewController → Real-time Ranging → Compass Display → Distance/Azimuth
```

## 🔍 Development Features

### **Debug Mode**
Enable by tapping version number 5 times:
- **Debug Logs**: Real-time system information
- **Device IDs**: Unique device identification
- **Performance Metrics**: Ranging accuracy and timing
- **Connection Status**: Detailed BLE/UWB status

### **Multi-Device Testing**
- **Multiple Arduino Boards**: Test with several UWB devices
- **Simultaneous Connections**: Verify multi-device stability
- **Session Management**: Test UWB session handling
- **Performance Monitoring**: Track system performance

## 🚀 Getting Started

### **Prerequisites**
```bash
# Required Software
- Xcode 14.0 or later
- iOS 16.0 or later
- Arduino IDE (for firmware development)
- macOS 12.0 or later
```

### **Installation**
1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/Proxi-APP.git
   cd Proxi-APP
   ```

2. **Open in Xcode**
   ```bash
   open Proxi.xcodeproj
   ```

3. **Configure Arduino**
   - Upload `Arduino/code.ino` to your Arduino board
   - Ensure StellaUWB library is installed
   - Configure device name in `config.h`

4. **Build and Run**
   - Select your target device
   - Build the project (⌘+B)
   - Run on device (⌘+R)

### **Configuration**
- **BLE Device Name**: Modify in `Arduino/config.h`
- **Maximum Devices**: Adjust `MAX_CONNECTED_DEVICES`
- **Timeouts**: Configure connection and session timeouts
- **Debug Level**: Set appropriate debug verbosity

## 🧪 Testing

### **Unit Tests**
```bash
# Run unit tests
xcodebuild test -scheme Proxi -destination 'platform=iOS Simulator,name=iPhone 14'
```

### **UI Tests**
```bash
# Run UI tests
xcodebuild test -scheme Proxi -destination 'platform=iOS Simulator,name=iPhone 14' -only-testing:ProxiUITests
```

### **Manual Testing**
- **Device Connection**: Test BLE connectivity
- **UWB Ranging**: Verify distance and direction accuracy
- **Multi-Device**: Test simultaneous connections
- **Social Features**: Test friend discovery and management

## 🔧 Troubleshooting

### **Common Issues**

1. **BLE Connection Problems**
   - Check device permissions
   - Verify Arduino firmware
   - Reset BLE stack if needed

2. **UWB Ranging Issues**
   - Ensure devices are within range
   - Check UWB session status
   - Verify firmware compatibility

3. **Multi-Device Conflicts**
   - Check device limits in Arduino config
   - Monitor connection timeouts
   - Verify session management

### **Debug Commands**
```swift
// Enable debug mode
// Tap version number 5 times in Settings

// Check device status
print("Connected devices: \(bleManager.connectedPeripherals.count)")

// Monitor UWB sessions
print("Active sessions: \(sessionManager.activeSessions)")
```

## 📈 Performance Optimization

### **Memory Management**
- **Efficient Data Structures**: Optimized for mobile performance
- **Lazy Loading**: Load components on demand
- **Image Caching**: Efficient asset management

### **Battery Optimization**
- **Smart Polling**: Adaptive BLE polling frequency
- **Session Management**: Efficient UWB session handling
- **Background Processing**: Optimized background operations

## 🤝 Contributing

### **Development Guidelines**
1. **Code Style**: Follow Swift style guidelines
2. **Documentation**: Add comprehensive comments
3. **Testing**: Include unit and UI tests
4. **Architecture**: Maintain clean architecture patterns

### **Pull Request Process**
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests and documentation
5. Submit a pull request

## 📄 License

© 2024 Proxi Team. All rights reserved.

This project is proprietary software. Unauthorized copying, distribution, or use is strictly prohibited.

## 🙏 Acknowledgments

- **Qorvo** - UWB technology and libraries
- **Apple** - NearbyInteraction framework
- **Arduino** - Hardware platform and tools
- **SwiftUI Community** - UI framework and best practices

---

**Proxi** - Connecting people through precise proximity.