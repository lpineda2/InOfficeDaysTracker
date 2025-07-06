# 🏢 In Office Days Tracker

A privacy-first iOS app that automatically tracks your office presence using geofencing technology to help you meet hybrid work requirements.

![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0+-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## 📱 Overview

In Office Days Tracker is a privacy-first iOS application designed for hybrid workers who need to track their in-office presence. Using Apple's Core Location framework with geofencing, the app automatically detects when you arrive at and leave your office, providing seamless tracking without manual input.

Perfect for companies with flexible work policies that require employees to be in the office a certain number of days per month. All data stays local on your device - no cloud sync, no accounts, no external servers.

**Built following Apple's official guidelines for iOS development and location services.**

## 🍎 Apple Guidelines Compliance

This app is built following Apple's official development guidelines and best practices:

### Design Guidelines
- **[Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)**: Follows Apple's design principles for intuitive, accessible user experiences
- **[Designing for iOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios)**: Implements iOS-specific design patterns and conventions
- **Progressive Disclosure**: Setup flow reveals information gradually to avoid overwhelming users
- **Accessibility**: Full VoiceOver support and proper contrast ratios
- **Familiar Patterns**: Uses standard iOS navigation and interaction patterns

### Location Services Best Practices
- **[Location Services Authorization](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services)**: Implements Apple's recommended authorization flow
- **Progressive Permission Requests**: Follows Apple's guidance for requesting "When in Use" before "Always" access
- **Clear Purpose Descriptions**: Provides transparent explanations for location access requirements
- **Contextual Permissions**: Requests permissions when users understand the value
- **Graceful Degradation**: App remains functional even with limited permissions

### Swift Development Standards
- **[Swift Documentation](https://developer.apple.com/documentation/swift)**: Uses modern Swift patterns and conventions
- **Swift 6 Concurrency**: Implements the latest concurrency model for thread safety
- **SwiftUI Best Practices**: Follows Apple's recommended SwiftUI architecture patterns
- **Modern iOS APIs**: Uses iOS 17+ features and deprecation-safe implementations

## ✨ Features

### 🎯 **Automatic Tracking**
- **Geofencing Technology**: Uses GPS to automatically detect office visits
- **Background Monitoring**: Tracks your presence even when the app is closed
- **Smart Validation**: Only counts visits longer than 1 hour as valid office days
- **Flexible Detection**: Configurable radius from 500m to 5km around your office

### 📊 **Progress Visualization**
- **Monthly Dashboard**: Beautiful circular progress indicator
- **Goal Tracking**: Set and monitor monthly in-office day targets
- **Real-time Updates**: Live progress updates as you complete office visits
- **Historical Data**: View past months' performance and trends

### ⚙️ **Customizable Settings**
- **Office Location**: Set address or use current location
- **Tracking Days**: Choose which days of the week to monitor (default: weekdays)
- **Office Hours**: Define your typical work schedule for validation
- **Detection Radius**: Adjust sensitivity based on your office building size
- **Monthly Goals**: Set realistic targets (default: 12 days/month)

### 🔔 **Smart Notifications**
- **Visit Alerts**: Get notified when office visits are logged
- **Goal Reminders**: Stay on track with progress notifications
- **Privacy Focused**: All notifications are local to your device

### 🔒 **Privacy First**
- **Local Storage**: All data stays on your device
- **No Cloud Sync**: No external servers or accounts required
- **Transparent Permissions**: Clear explanations for location access
- **User Control**: Easy to modify or disable tracking anytime

## 🚀 Getting Started

### Prerequisites
- iOS 17.0 or later
- Xcode 15.0+ (for development)
- Physical device (location services don't work properly in simulator)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/lpineda2/InOfficeDaysTracker.git
   cd InOfficeDaysTracker
   ```

2. **Open in Xcode**
   ```bash
   open InOfficeDaysTracker.xcodeproj
   ```

3. **Configure the project**
   - Set your development team in project settings
   - Ensure location permissions are configured in Info.plist (see below)
   - Build and run on a physical device

### Required Info.plist Configuration

Add these entries to your Info.plist file as per Apple's location services guidelines:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to detect when you arrive at your office.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs always-on location access to automatically track your office visits in the background.</string>
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

### First-Time Setup

The app guides you through a 6-step setup process following Apple's progressive disclosure principles:

1. **Welcome**: Overview of features and privacy policy
2. **Office Location**: Enter your office address or use current location
3. **Tracking Days**: Select which days to monitor (Mon-Fri recommended)
4. **Office Hours**: Set your typical work schedule
5. **Monthly Goal**: Choose your target in-office days per month
6. **Permissions**: Grant location and notification access following Apple's authorization guidelines

## 🏗️ Architecture

The app follows modern iOS development patterns with SwiftUI and the MVVM architecture:

```
InOfficeDaysTracker/
├── 📱 App/
│   ├── InOfficeDaysTrackerApp.swift     # App entry point
│   └── ContentView.swift                # Root view controller
├── 📊 Models/
│   ├── AppData.swift                    # Main data model (ObservableObject)
│   ├── AppSettings.swift               # User preferences
│   └── OfficeVisit.swift               # Visit data structure
├── 🔧 Services/
│   ├── LocationService.swift           # Core Location & geofencing
│   └── NotificationService.swift       # Local notifications
├── 🎨 Views/
│   ├── SetupView.swift                 # Onboarding flow
│   ├── MainProgressView.swift          # Dashboard
│   ├── HistoryView.swift               # Visit history
│   └── SettingsView.swift              # Configuration
└── 📋 Resources/
    ├── Info.plist                      # App configuration
    └── Assets.xcassets                  # Images and colors
```

## 🔧 Technical Implementation

### Location Services - Following Apple's Best Practices
Following Apple's [Location Services Authorization Guide](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services):

- **Progressive Permissions**: Implements Apple's recommended authorization flow
- **"When in Use" First**: Initially requests basic location access for setup
- **"Always" Permission**: Contextually requests background access with clear rationale
- **Geofencing**: Uses `CLCircularRegion` for office boundary detection
- **Background Updates**: Maintains tracking when app is backgrounded
- **Battery Optimization**: Efficient location accuracy and update frequency
- **Error Handling**: Comprehensive error handling for various location scenarios

### Data Management
- **Codable Models**: JSON serialization for local persistence
- **UserDefaults Storage**: Secure local storage without external dependencies
- **Visit Validation**: Smart filtering based on duration, time, and working days
- **Thread Safety**: Modern Swift concurrency for safe data access
- **NaN Protection**: Robust calculations that prevent division by zero and invalid values

### User Interface
Following Apple's [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/):

- **SwiftUI**: Native iOS 17+ design patterns
- **Accessibility**: Full VoiceOver support and proper contrast
- **Responsive Design**: Optimized for all iPhone and iPad screen sizes
- **Animations**: Smooth transitions and delightful micro-interactions
- **Real-time Updates**: Live permission status and progress updates
- **iOS Design Language**: Uses system fonts, colors, and spacing

## 📱 Screenshots

*Add your app screenshots here*

## 🛡️ Privacy & Security

This app is built with privacy as a fundamental principle, following Apple's privacy guidelines:

- **📍 Location Data**: Only used for geofencing, never transmitted anywhere
- **💾 Local Storage**: All data remains on your device using iOS secure storage
- **🚫 No Tracking**: No analytics, crash reporting, or user behavior tracking
- **🔒 No Accounts**: No sign-up, login, or personal information required
- **⚡ Minimal Permissions**: Only requests essential location and notification access
- **🎛️ Full Control**: Easy to disable tracking or delete all data anytime
- **🍎 Apple Guidelines**: Follows Apple's Human Interface Guidelines for location services
- **Progressive Permissions**: Transparent, step-by-step permission requests with clear explanations

## 🐛 Known Issues & Solutions

This app has been thoroughly tested and debugged. Key fixes include:

- **Location Authorization**: Proper implementation of Apple's progressive permission model
- **CoreGraphics NaN Errors**: Fixed division by zero in progress calculations
- **Background Monitoring**: Robust geofencing that works when app is closed
- **Permission Flow**: Real-time permission status updates and proper error handling

For detailed technical information about bug fixes and Apple guidelines compliance, see:
- [`BUG_FIXES_SUMMARY.md`](BUG_FIXES_SUMMARY.md)
- [`APPLE_GUIDELINES_IMPLEMENTATION.md`](APPLE_GUIDELINES_IMPLEMENTATION.md)
- [`PRD.md`](PRD.md) - Complete Product Requirements Document

## 🧪 Testing

### Device Testing Required
- Location services require a physical device
- Simulator cannot test geofencing functionality
- Background app refresh must be enabled

### Testing Checklist
1. **Location Permissions**: Verify progressive permission flow
2. **Geofencing**: Test office entry/exit detection
3. **Background Tracking**: Confirm visits are logged when app is closed
4. **Data Persistence**: Verify settings and visits are saved
5. **UI Responsiveness**: Check for NaN values in progress displays

## 📋 Requirements

- **iOS**: 17.0 or later
- **Xcode**: 15.0+ (for development)
- **Device**: Physical device required for location services
- **Background App Refresh**: Must be enabled for automatic tracking

## 🤝 Contributing

This is a personal productivity app designed to be simple and reliable. If you'd like to contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## � Additional Resources

### Apple Documentation References
- **[Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)**: Official Apple design guidelines
- **[Designing for iOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios)**: iOS-specific design patterns
- **[Location Services Authorization](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services)**: Core Location authorization guide
- **[Swift Documentation](https://developer.apple.com/documentation/swift)**: Swift language reference

### Development Resources
- **Xcode**: Latest version available on the Mac App Store
- **iOS Developer Documentation**: Apple's comprehensive development guides
- **WWDC Sessions**: Apple's developer conference sessions on location services and privacy

## �📄 License

Copyright (c) 2025 Luis Pineda. All rights reserved.

## 🆘 Support

For questions, issues, or feature requests:
- Open an issue on GitHub
- Check the documentation files in the repository
- Review the Apple Guidelines Implementation document

---

*Built with ❤️ using SwiftUI and following Apple's best practices for location services*
