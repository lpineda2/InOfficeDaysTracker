# iPhone Lock Screen Widgets - v1.7.0

## 🔒 Lock Screen Widget Support

InOfficeDaysTracker now supports **iPhone Lock Screen widgets** (iOS 16+), giving you instant access to your office visit progress without unlocking your device.

## 📱 Available Widget Types

### 🔵 **Circular Widget** (accessoryCircular)
- **Progress ring** showing completion percentage
- **Current/Goal count** (e.g., "8/12")
- **Visual progress** with animated ring
- Perfect for **at-a-glance** progress tracking

```
┌─────────┐
│    8    │  ← Current days
│ ●●●●○○○ │  ← Progress ring  
│   /12   │  ← Goal days
└─────────┘
```

### 📊 **Rectangular Widget** (accessoryRectangular)
- **Detailed progress** with building icon
- **Smart status** based on current state:
  - 📍 "Currently in office" (when in office radius)
  - ✅ "Goal achieved!" (when goal met)
  - ⏳ "X days to go" (remaining days)
- **Progress percentage** on right side

```
┌──────────────────┐
│ 🏢 Office: 8/12  67% │
│ 📍 Currently in office │
└──────────────────┘
```

### 📝 **Inline Widget** (accessoryInline)
- **Single line** format for minimal space
- **Emoji indicators** for quick status:
  - 🏢 Building icon
  - 📍 Currently in office
  - ✅ Goal achieved  
  - ⏳ In progress
- **Progress summary** with percentage

```
🏢 8/12 days (67%) 📍
```

## 🎯 Benefits

### **Instant Visibility**
- See office progress **without unlocking** your iPhone
- Quick status check throughout the day
- No app launching required

### **Battery Efficient**
- Minimal **battery impact** with smart updates
- Only refreshes when office status changes
- Optimized for lock screen performance

### **Professional Integration**
- **Native iOS design** that matches system widgets
- Adapts to **Dark/Light mode** automatically  
- **Monochrome-friendly** for Always-On Display

## 🛠️ How to Add Lock Screen Widgets

### **Setup Instructions:**

1. **Lock your iPhone** (press power button)

2. **Touch and hold** the lock screen until customization options appear

3. **Tap "Customize"** button

4. **Tap the widget area** (below the time)

5. **Search for "Office"** or scroll to find **"InOfficeDaysTracker"**

6. **Select widget type:**
   - **Circular** - for progress ring
   - **Rectangular** - for detailed status  
   - **Inline** - for minimal text

7. **Tap "Done"** to save

### **Widget Updates:**
- **🚀 NEW: Location-Triggered Refresh** - Instant updates when entering/exiting office
- **Real-time status changes** - No more delays when leaving for lunch or returning
- **Automatic refresh** when you enter/exit office radius
- **Hourly updates** to ensure fresh data
- **Instant sync** with main app changes

## 🎨 Design Features

### **Smart Status Indicators:**
- **🏢 Building icon** - Always visible for app identification
- **📍 Location pin** - Currently detected in office
- **✅ Checkmark** - Monthly goal achieved
- **⏳ Hourglass** - Progress toward goal

### **Progress Visualization:**
- **Circular ring** - Animated progress completion
- **Percentage display** - Exact progress numbers
- **Color coding** - Visual status differentiation

### **Responsive Text:**
- **Dynamic status** based on current office detection
- **Goal tracking** with remaining days calculation
- **Achievement celebration** when goals are met

## 🔄 Data Synchronization

Lock screen widgets share the same data as your main app:
- **Office visit tracking** syncs instantly
- **Location detection** updates widgets immediately  
- **Settings changes** reflect across all widgets
- **Monthly progress** calculation stays consistent

## 💡 Best Practices

### **Widget Selection:**
- **Circular** - Best for quick progress overview
- **Rectangular** - Ideal for detailed daily tracking
- **Inline** - Perfect for minimal lock screen setups

### **Multiple Widgets:**
You can add **multiple widget types** to create a comprehensive office tracking dashboard on your lock screen.

## 🔧 Technical Details

- **iOS 16.0+** required for lock screen widgets
- **Automatic updates** via WidgetKit TimelineProvider
- **Shared data** using App Groups for instant sync
- **Memory efficient** with optimized rendering
- **Accessibility support** with proper labels and hints

---

*Lock screen widgets provide the fastest way to check your office visit progress throughout your workday, keeping you motivated and on track with your goals.*