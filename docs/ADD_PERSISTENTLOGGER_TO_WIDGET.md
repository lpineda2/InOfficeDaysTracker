# How to Add PersistentLogger to Widget Target

## Quick Fix (2 minutes)

This will make PersistentLogger available to both the main app and widget extension, fixing the compilation error.

### Steps:

1. **Open Xcode**
   - Double-click `InOfficeDaysTracker.xcodeproj` in Finder
   - OR: `open InOfficeDaysTracker.xcodeproj` in Terminal

2. **Locate PersistentLogger.swift**
   - In the **Project Navigator** (left sidebar)
   - Navigate to: `InOfficeDaysTracker` → `Services` → `PersistentLogger.swift`
   - Click on `PersistentLogger.swift` to select it

3. **Open File Inspector**
   - In the **right sidebar**, click the **File Inspector** icon (📄 document icon)
   - OR: Press `⌘⌥1` (Cmd+Option+1)

4. **Add to Widget Target**
   - Scroll down to the **"Target Membership"** section
   - You'll see checkboxes for:
     - ☑️ InOfficeDaysTracker (already checked)
     - ☐ OfficeTrackerWidgetExtension (currently unchecked)
   - **Check the box** next to `OfficeTrackerWidgetExtension`

5. **Verify**
   - Both targets should now be checked:
     - ☑️ InOfficeDaysTracker
     - ☑️ OfficeTrackerWidgetExtension

6. **Save**
   - Press `⌘S` to save
   - Close Xcode (or keep it open)

### Visual Guide:

```
Project Navigator          File Inspector (Right Sidebar)
├── InOfficeDaysTracker   ┌─────────────────────────────┐
│   ├── Services           │ PersistentLogger.swift      │
│   │   └── PersistentLogger.swift ← SELECT THIS
│   │                       │                             │
│   └── ...                │ Target Membership:          │
└── ...                    │ ☑️ InOfficeDaysTracker      │
                           │ ☑️ OfficeTrackerWidgetExt   │← CHECK THIS
                           └─────────────────────────────┘
```

### After This Fix:

Run the release script:
```bash
./scripts/release.sh --increment
```

This will:
1. ✅ Increment build number to 28
2. ✅ Run tests (should pass now)
3. ✅ Build archive
4. ✅ Upload to TestFlight

### Why This Works:

- The widget extension is a separate binary that needs its own copy of PersistentLogger
- By adding it to both targets, both can compile and use the logging service
- The widget won't actually use persistent logging (it just needs to compile)
- Only the main app will write to log files

### Troubleshooting:

**If you don't see "Target Membership" section:**
- Make sure you selected the **file** (PersistentLogger.swift), not a folder
- Make sure the **File Inspector** is open (not Identity Inspector or Attributes Inspector)

**If the checkbox is grayed out:**
- The file might already be in the target
- Try unchecking and rechecking it

**If tests still fail:**
- Clean build folder: `⌘⇧K` (Cmd+Shift+K) in Xcode
- OR: `./scripts/test.sh` to run tests manually

### Alternative: Command Line (Advanced)

If you prefer command line, you can modify the project file directly, but it's more error-prone:

```bash
# This is NOT recommended - use Xcode GUI instead
# But if you must, you'd need to edit InOfficeDaysTracker.xcodeproj/project.pbxproj
# and add PersistentLogger.swift to the OfficeTrackerWidgetExtension target's
# PBXSourcesBuildPhase section
```

## Next Steps

After adding to widget target:
1. Run `./scripts/release.sh --increment`
2. Wait for TestFlight upload to complete
3. Install new build on your iPhone
4. Test tomorrow: Go to office, leave office, export logs
5. Share logs with me if issue persists

The persistent logging will help us definitively identify where your visits are being lost!
