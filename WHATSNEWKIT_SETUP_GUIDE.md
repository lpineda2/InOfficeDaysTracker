# 🎉 WhatsNewKit Integration Guide

## 📱 Overview
This integration adds a polished "What's New" screen to showcase the new lock screen widgets feature in InOfficeDaysTracker v1.7.0.

## 🔧 Setup Steps

### 1. Add WhatsNewKit Package Dependency

**In Xcode:**
1. Open `InOfficeDaysTracker.xcodeproj`
2. Go to **File** → **Add Package Dependencies**
3. Enter URL: `https://github.com/SvenTiigi/WhatsNewKit.git`
4. Select **Up to Next Major Version** with `2.0.0`
5. Click **Add Package**
6. Select **WhatsNewKit** for the main app target
7. Click **Add Package**

### 2. Uncomment Import Statements
After adding the package, uncomment these lines:

**In `InOfficeDaysTrackerApp.swift`:**
```swift
// import WhatsNewKit  // ← Remove comment
```

**In `WhatsNewConfiguration.swift`:**
```swift
// import WhatsNewKit  // ← Remove comment  
```

**In `WhatsNewStyling.swift`:**
```swift
// import WhatsNewKit  // ← Remove comment
```

### 3. Add Widget Screenshot Assets

Replace the placeholder files in `InOfficeDaysTracker/Assets/WhatsNew/` with actual screenshots:

#### Required Screenshots:
1. **`lock-screen-circular.png`** - Circular lock screen widget
2. **`lock-screen-rectangular.png`** - Rectangular lock screen widget  
3. **`home-screen-medium.png`** - Medium home screen widget

#### Screenshot Instructions:
- Use **iPhone 16 Pro simulator** for consistency
- Show realistic data (e.g., "8 of 12 days")
- Ensure new SF Symbols are visible (`building.2.fill`, `clock.badge.fill`)
- Capture in **light mode** for better visibility
- Export as **PNG** format

#### Adding to Xcode:
1. Right-click `Assets.xcassets` in Xcode
2. Select **Import**  
3. Add the three PNG files
4. Ensure they're added to the main app target

### 4. Update Info.plist Version

Ensure your `Info.plist` has version `1.7.0`:
```xml
<key>CFBundleShortVersionString</key>
<string>1.7.0</string>
```

## 🚀 How It Works

### Automatic Presentation
- Shows automatically on first launch of v1.7.0
- Uses `UserDefaultsWhatsNewVersionStore` to track shown versions
- Won't show again once dismissed

### Manual Testing
You can test the WhatsNew screen by:
1. Deleting the app from simulator
2. Running a fresh install
3. Or clearing UserDefaults: `UserDefaults.standard.removeObject(forKey: "WhatsNewKit.PresentedVersions")`

### Features Showcased
1. **Lock Screen Progress** - Circular widget with progress ring
2. **Detailed Status View** - Rectangular widget with building icon
3. **Enhanced Home Widgets** - Medium widget with full interface

## 🎨 Customization

### Layout Adjustments
Modify `WhatsNew.Layout.inOfficeDaysStyle` in `WhatsNewStyling.swift`:
```swift
static var inOfficeDaysStyle: WhatsNew.Layout {
    WhatsNew.Layout(
        contentPadding: EdgeInsets(...),
        featureListSpacing: 24,
        // ... other properties
    )
}
```

### Color Scheme
Update colors in `WhatsNewStyling.swift` to match your app's theme.

## 🧪 Testing Checklist

- [ ] WhatsNewKit package added successfully
- [ ] Import statements uncommented
- [ ] Widget screenshots added to Assets.xcassets
- [ ] App builds without errors
- [ ] WhatsNew screen appears on fresh install
- [ ] Secondary action opens iOS Settings
- [ ] Primary action dismisses correctly
- [ ] Screen doesn't show again after dismissal

## 📋 Integration with Release Pipeline

The WhatsNewKit integration works with your existing release scripts:
- Version tracking automatically uses `CFBundleShortVersionString`
- No changes needed to `build.sh`, `upload.sh`, or `release.sh`
- Will automatically show for users upgrading to v1.7.0+