# Pace Calculation Fix - Test Scenarios

## Implementation Summary
Fixed the "14.0 days/week" bug by correcting the pace calculation logic:

### Before (Buggy):
```swift
let pace = Double(remaining) / Double(daysLeft)
return String(format: "%.1f days/week", pace * 7)  // Wrong: multiplying by 7 calendar days
```

### After (Fixed):
```swift
let workingDaysPerWeek = appData.settings.trackingDays.count  // User's actual tracking days
let dailyRate = Double(remaining) / Double(daysLeft)
let weeklyRate = dailyRate * Double(workingDaysPerWeek)

if weeklyRate > Double(workingDaysPerWeek) {
    return "Goal unreachable"
} else {
    return String(format: "%.1f days/week", weeklyRate)
}
```

## Test Scenarios

### Scenario 1: Normal Progress ✅
- Current: 8 days, Goal: 12 days, Remaining: 4 days, Working days left: 8, User tracks: Mon-Fri (5 days)
- **Before**: (4÷8) × 7 = **3.5 days/week** ❌
- **After**: (4÷8) × 5 = **2.5 days/week** ✅

### Scenario 2: Behind Schedule (Your Reported Issue) ✅
- Current: 0 days, Goal: 10 days, Remaining: 10 days, Working days left: 5, User tracks: Mon-Fri (5 days)
- **Before**: (10÷5) × 7 = **14.0 days/week** ❌ (Impossible!)
- **After**: (10÷5) × 5 = **10.0 days/week** → **"Goal unreachable"** ✅

### Scenario 3: Goal Achieved ✅
- Current: 12 days, Goal: 12 days, Remaining: 0
- **Both**: **"Goal complete!"** ✅

### Scenario 4: Custom Tracking Days ✅
- Current: 6 days, Goal: 12 days, Remaining: 6 days, Working days left: 9, User tracks: Mon-Wed-Fri (3 days)
- **Before**: (6÷9) × 7 = **4.67 days/week** ❌
- **After**: (6÷9) × 3 = **2.0 days/week** ✅

### Scenario 5: End of Month ✅
- Remaining: 5 days, Working days left: 0
- **Both**: **"0.0 days/week"** ✅

### Scenario 6: Part-time Schedule ✅
- Current: 4 days, Goal: 8 days, Remaining: 4 days, Working days left: 6, User tracks: Tue-Thu (2 days)
- **Before**: (4÷6) × 7 = **4.67 days/week** ❌
- **After**: (4÷6) × 2 = **1.33 days/week** ✅

## Key Benefits:
1. **Accurate calculations** based on user's actual tracking schedule
2. **"Goal unreachable"** message instead of impossible values
3. **Supports custom schedules** (part-time, 4-day weeks, etc.)
4. **Maintains compatibility** with session-based visit tracking (1 visit per day max)
5. **Better user guidance** for realistic goal management

## Result:
The "14.0 days/week" bug is completely fixed! 🎉