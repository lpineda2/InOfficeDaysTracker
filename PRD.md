# 📋 Product Requirements Document

## In Office Days Tracker - PRD

### Project Overview
An iOS app that tracks when you're physically in the office to help meet configurable in-office day goals using geofencing technology.

### Target Audience
- **Primary**: Hybrid workers with flexible work policies
- **Secondary**: Companies tracking employee office presence
- **Use Case**: Meeting monthly in-office day requirements

### Core Features & Requirements

#### 1. **Geofencing Detection**
- **Requirement**: Automatically detect office presence using GPS
- **Implementation**: Core Location with CLCircularRegion
- **Validation**: Minimum 1-hour duration to count as valid visit
- **Status**: ✅ **Implemented**

#### 2. **Progress Tracking**
- **Requirement**: Visual progress indicator for monthly goals
- **Implementation**: SwiftUI circular progress view
- **Data**: Real-time calculation of completed vs. target days
- **Status**: ✅ **Implemented**

#### 3. **Configurable Settings**
- **Requirement**: User-customizable office location, radius, and goals
- **Implementation**: Setup flow with 6-step progressive disclosure
- **Options**: Address input, radius selection, goal setting
- **Status**: ✅ **Implemented**

#### 4. **Local Notifications**
- **Requirement**: Notifications for visit logging and goal reminders
- **Implementation**: UserNotifications framework
- **Privacy**: All notifications processed locally
- **Status**: ✅ **Implemented**

#### 5. **Background Tracking**
- **Requirement**: Monitor office presence when app is closed
- **Implementation**: Background app refresh with location services
- **Permissions**: "Always" location access following Apple guidelines
- **Status**: ✅ **Implemented**

### Technical Specifications

#### Platform Requirements
- **iOS Version**: 17.0+
- **Framework**: SwiftUI
- **Architecture**: MVVM with ObservableObject
- **Storage**: Local UserDefaults (no cloud sync)
- **Permissions**: Location (Always), Notifications (Optional)

#### Apple Guidelines Compliance
- **[Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)**: ✅ Followed
- **[Location Services Authorization](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services)**: ✅ Implemented
- **[Swift Documentation](https://developer.apple.com/documentation/swift)**: ✅ Modern patterns used
- **[Designing for iOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios)**: ✅ iOS-specific design

### Privacy & Security Requirements

#### Data Privacy
- **Local Storage Only**: No external servers or cloud sync
- **Minimal Data Collection**: Only location for geofencing
- **User Control**: Easy to disable or delete data
- **Status**: ✅ **Implemented**

#### Security
- **No Accounts Required**: No sign-up or login
- **No Analytics**: No user behavior tracking
- **No Data Transmission**: All processing happens on-device
- **Status**: ✅ **Implemented**

### User Experience Requirements

#### Setup Flow
- **Progressive Disclosure**: 6-step setup process
- **Clear Explanations**: Transparent permission requests
- **Contextual Permissions**: Request access when value is understood
- **Status**: ✅ **Implemented**

#### Daily Use
- **Automatic Operation**: No manual input required
- **Visual Progress**: Clear monthly progress display
- **History Access**: View past office visits
- **Settings Control**: Easy to modify preferences
- **Status**: ✅ **Implemented**

### Success Metrics

#### Core Functionality
- ✅ **Geofencing Accuracy**: Reliably detects office entry/exit
- ✅ **Battery Efficiency**: Minimal impact on device battery
- ✅ **Permission Compliance**: Follows Apple's authorization guidelines
- ✅ **Background Reliability**: Tracks visits when app is closed

#### User Experience
- ✅ **Setup Completion**: Intuitive 6-step onboarding
- ✅ **Daily Engagement**: Clear progress visualization
- ✅ **Privacy Assurance**: Transparent data handling
- ✅ **Accessibility**: VoiceOver support and proper contrast

### Development Status

#### Version 1.0 (MVP) - ✅ **COMPLETED**
- [x] Core geofencing functionality
- [x] Progress tracking dashboard
- [x] Configurable settings
- [x] Local notifications
- [x] Background monitoring
- [x] Privacy-first design
- [x] Apple guidelines compliance
- [x] Clean build with no errors

#### Version 1.1 (In Development) - 🔄 **IN PROGRESS**
- [ ] Address autocomplete functionality
- [ ] Enhanced address input with real-time suggestions
- [ ] Improved user experience for location setup

#### Future Enhancements (Planned)
- [ ] Multiple office locations
- [ ] Export data functionality
- [ ] Advanced analytics
- [ ] Calendar integration
- [ ] Apple Watch companion app

### Implementation Notes

#### Technical Decisions
- **SwiftUI over UIKit**: Modern declarative UI framework
- **UserDefaults over Core Data**: Simpler persistence for small data set
- **Local-only storage**: Privacy-first approach, no external dependencies
- **Progressive permissions**: Better user experience following Apple guidelines

#### Architecture Choices
- **MVVM Pattern**: Clean separation of concerns
- **ObservableObject**: Reactive data binding
- **Environment Objects**: Shared state management
- **Codable Models**: Type-safe data persistence

### Risk Mitigation

#### Technical Risks - ✅ **Addressed**
- **Location Permission Denial**: Graceful degradation with clear messaging
- **Background Limitations**: Proper background modes and error handling
- **Battery Impact**: Efficient location accuracy and update frequency
- **NaN Calculations**: Robust mathematical operations with validation

#### User Experience Risks - ✅ **Addressed**
- **Setup Complexity**: Progressive disclosure with clear explanations
- **Permission Confusion**: Contextual requests following Apple guidelines
- **Privacy Concerns**: Transparent data handling and local storage
- **Accessibility Issues**: VoiceOver support and proper contrast ratios

### Feature Specifications

#### 1. Setup Flow (6 Steps)
1. **Welcome Screen**
   - App overview and privacy statement
   - Continue to location setup
   
2. **Office Location**
   - Address input field
   - "Use Current Location" button
   - Map preview of selected location
   
3. **Tracking Days**
   - Day-of-week selector (Mon-Sun)
   - Default: Monday through Friday
   - Visual calendar representation
   
4. **Office Hours**
   - Start time picker
   - End time picker
   - Default: 9:00 AM - 5:00 PM
   
5. **Monthly Goal**
   - Number picker (1-31 days)
   - Default: 12 days per month
   - Visual progress preview
   
6. **Permissions**
   - Location access explanation
   - Notification access explanation
   - System permission prompts

#### 2. Main Dashboard
- **Progress Circle**: Visual representation of monthly progress
- **Current Status**: In office / Not in office
- **Days Completed**: X of Y days this month
- **Time Remaining**: Days left in current month
- **Quick Actions**: Settings, History buttons

#### 3. History View
- **Monthly View**: List of all office visits
- **Visit Details**: Date, arrival time, departure time, duration
- **Filter Options**: By month, by week
- **Export**: Share visit data

#### 4. Settings View
- **Office Location**: Modify address or coordinates
- **Detection Radius**: 500m - 5km slider
- **Tracking Days**: Toggle weekdays
- **Office Hours**: Time range picker
- **Monthly Goal**: Target days input
- **Notifications**: Toggle visit alerts
- **Privacy**: Clear data option

### Data Models

#### AppData (Main Observable Object)
```swift
class AppData: ObservableObject {
    @Published var settings: AppSettings
    @Published var visits: [OfficeVisit]
    @Published var isSetupComplete: Bool
}
```

#### AppSettings (User Preferences)
```swift
struct AppSettings: Codable {
    var officeLocation: CLLocationCoordinate2D
    var officeAddress: String
    var trackingRadius: Double
    var workingDays: Set<Int>
    var workingHours: (start: Date, end: Date)
    var monthlyGoal: Int
    var notificationsEnabled: Bool
}
```

#### OfficeVisit (Visit Record)
```swift
struct OfficeVisit: Codable, Identifiable {
    let id: UUID
    let date: Date
    let arrivalTime: Date
    let departureTime: Date?
    let duration: TimeInterval
    let isValid: Bool
}
```

### Quality Assurance

#### Testing Requirements
- **Unit Tests**: Core logic and calculations
- **UI Tests**: Setup flow and main screens
- **Integration Tests**: Location services and notifications
- **Device Testing**: Physical device required for location features

#### Performance Requirements
- **App Launch**: < 2 seconds cold start
- **Location Updates**: < 5 seconds detection accuracy
- **Battery Usage**: < 5% per day background usage
- **Memory Usage**: < 50MB typical usage

### Deployment & Distribution

#### App Store Submission
- **Privacy Policy**: Required for location services
- **App Store Description**: Clear feature explanation
- **Screenshots**: All key screens documented
- **Keywords**: Hybrid work, office tracking, geofencing

#### Version Control
- **Git Repository**: https://github.com/lpineda2/InOfficeDaysTracker
- **Branch Strategy**: Main branch for releases, feature branches for development
- **Documentation**: README, PRD, and implementation guides

---

*This PRD serves as the foundation for the In Office Days Tracker iOS app, ensuring all requirements are met while following Apple's best practices for location services and user experience.*
