# Security & Architecture Review
**Date:** February 17, 2026  
**Version:** 1.10.1 (Build 7)  
**Reviewer:** AI Code Review  

## Executive Summary

Overall security posture is **good** for a privacy-focused personal productivity app. No critical vulnerabilities identified. Primary concerns are crash prevention (force unwraps) and battery optimization.

**Risk Level:** Low  
**Recommended Action:** Address high-priority stability issues before next release

---

## ⚠️ High Priority Issues

### 1. No Input Validation on Address Data
- **File:** `InOfficeDaysTracker/Views/Components/AddressAutocompleteField.swift`
- **Issue:** User input from MapKit not sanitized before storage
- **Risk:** Medium - Malformed data could cause crashes or data corruption
- **Impact:** App could crash if MapKit returns unexpected coordinate values or malformed addresses
- **Recommendation:** 
  ```swift
  // Add validation before storage
  guard (-90...90).contains(coordinate.latitude),
        (-180...180).contains(coordinate.longitude),
        address.count < 500 else {
      return // or show error
  }
  ```
- **Effort:** Small (1-2 hours)
- **Priority:** High

### 2. AppData Singleton State Management
- **File:** `InOfficeDaysTracker/Models/AppData.swift` (1143 lines)
- **Issue:** God object with mixed responsibilities (state, business logic, persistence)
- **Risk:** Maintainability, testability, potential race conditions
- **Violations:**
  - Single Responsibility Principle
  - Difficult to unit test in isolation
  - State mutations not atomic
- **Recommendation:** Split into focused components:
  - `VisitRepository` (persistence layer)
  - `PaceCalculator` (business logic)
  - `AppState` (UI state only)
- **Effort:** Large (1-2 weeks)
- **Priority:** High (long-term maintainability)
- **Note:** Can be done incrementally; not blocking

### 3. Force Unwrapping in Location Services
- **Files:** 
  - `InOfficeDaysTracker/Services/LocationService.swift:267`
  - `InOfficeDaysTracker/Services/LocationVerificationService.swift:78`
- **Issue:** `settings.officeLocation!` and `officeLocations.first!` used without nil checks
- **Risk:** App crash if user hasn't configured office location
- **Impact:** High - Direct crash risk
- **Recommendation:**
  ```swift
  // Before
  let office = settings.officeLocation!
  
  // After
  guard let office = settings.officeLocation else {
      logger.warning("No office location configured")
      return
  }
  ```
- **Effort:** Small (30 minutes)
- **Priority:** High - **Start here**

### 4. Background Task Without Battery Optimization
- **File:** `InOfficeDaysTracker/Services/LocationVerificationService.swift:51-71`
- **Issue:** Timer fires every 5 minutes regardless of device state (screen on/off, battery level)
- **Risk:** Excessive battery drain, poor App Store reviews
- **Current Implementation:**
  ```swift
  Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
      // Runs every 5 min regardless of conditions
  }
  ```
- **Recommendation:** Use iOS 13+ BackgroundTasks framework with power-aware scheduling
- **Effort:** Medium (4-6 hours)
- **Priority:** High (user experience)

---

## 🟡 Medium Priority Issues

### 5. Widget Data Synchronization Races
- **Files:** `InOfficeDaysTracker/Models/AppData.swift`, `OfficeTrackerWidget/OfficeTrackerWidgetBundle.swift`
- **Issue:** Main app and widget extension both write to shared UserDefaults without coordination
- **Risk:** Data corruption if simultaneous writes occur
- **Likelihood:** Low (widgets update infrequently)
- **Recommendation:** Implement file-based locking or use `NSFileCoordinator`
- **Effort:** Medium (3-4 hours)
- **Priority:** Medium

### 6. Privacy - Location Data in Logs
- **Files:** Multiple LocationService files
- **Issue:** Coordinates logged at `.info` level: `logger.info("User entered: \(region.identifier)")`
- **Risk:** PII in crash logs sent to Apple
- **Recommendation:** 
  ```swift
  // Use .debug level for coordinates
  logger.debug("User entered: \(region.identifier)")
  
  // Or use os_log privacy
  logger.info("User entered: \(region.identifier, privacy: .private)")
  ```
- **Effort:** Small (30 minutes)
- **Priority:** Medium

### 7. Missing Error Boundaries
- **File:** `InOfficeDaysTracker/Services/CalendarEventManager.swift:38-84`
- **Issue:** Calendar operations can throw but errors swallowed silently
- **Impact:** User doesn't know calendar integration failed
- **Recommendation:** Surface errors to user or retry with exponential backoff
- **Effort:** Medium (2-3 hours)
- **Priority:** Medium

### 8. Hard-Coded Magic Numbers
- **Files:** Multiple files with `402`, `1609`, `250`, `1000` (radius values)
- **Issue:** Scattered throughout codebase without named constants
- **Impact:** Maintainability, consistency
- **Recommendation:**
  ```swift
  struct GeofenceDefaults {
      static let minRadiusMeters: Double = 250
      static let maxRadiusMeters: Double = 1000
      static let minRadiusMiles: Double = 402.335
      static let maxRadiusMiles: Double = 1609.34
  }
  ```
- **Effort:** Small (1 hour)
- **Priority:** Medium

---

## 🟢 Low Priority / Best Practices

### 9. Visit History Storage *(Deferred per user)*
- **Current:** Visit history stored in UserDefaults
- **Concern:** Behavioral patterns (when user is at office) accessible in device backups
- **User Decision:** Not considered a concern at this time
- **Status:** Deferred - monitor for future privacy requirements
- **Note:** If app becomes enterprise/compliance-focused, revisit this decision

### 10. Async/Await Migration Incomplete
- **Issue:** Mix of completion handlers and async/await patterns
- **Files:** LocationService (delegates) vs CalendarEventManager (async)
- **Impact:** Code consistency
- **Recommendation:** Modernize to async/await when touching related code
- **Priority:** Low (opportunistic refactoring)

### 11. Testing Gaps
- **Present:** LocationServiceTests (22 tests), AppDataTests
- **Missing:**
  - CalendarEventManager tests
  - LocationVerificationService tests
  - Widget timeline tests
- **Recommendation:** Aim for 70%+ coverage on critical paths
- **Effort:** Large (ongoing)
- **Priority:** Low (but valuable)

### 12. SwiftLint Warnings
- **Current:** 93 warnings (sorted imports, trailing newlines, identifier names)
- **Risk:** Code quality drift
- **Recommendation:** Fix in batches, enable as CI errors incrementally
- **Priority:** Low

### 13. Deep Dependency Injection
- **Issue:** Views directly access `@EnvironmentObject` AppData throughout
- **Impact:** Testing complexity
- **Recommendation:** Consider view models for complex views
- **Priority:** Low (architectural preference)

---

## Architecture Assessment

### Current Pattern
```
Views → AppData (Singleton ObservableObject) → Services → UserDefaults/iOS APIs
```

**Strengths:**
- ✅ Simple mental model for small app
- ✅ Reactive updates via `@Published`
- ✅ Services properly separated
- ✅ Clear ownership of state

**Weaknesses:**
- ❌ AppData too large (1143 lines)
- ❌ No dependency injection (difficult testing)
- ❌ Mixed concerns (state + logic + persistence)
- ❌ Direct UserDefaults coupling

### Recommended Evolution
```
Views → ViewModels (protocol-oriented) → Repositories (protocols) → Storage/Services
```

**Benefits:**
- Better testability (mockable interfaces)
- Clearer separation of concerns
- Easier to add features without bloating AppData

**Migration Path:** Incremental - extract one feature at a time

---

## Prioritized Action Plan

### Phase 1: Stability & Crash Prevention (Week 1)
**Goal:** Eliminate crash risks before next release

1. ✅ **Fix force unwraps** (#3) - 30 min
   - LocationService.swift
   - LocationVerificationService.swift
2. ✅ **Add input validation** (#1) - 2 hours
   - AddressAutocompleteField.swift
3. ✅ **Battery optimization** (#4) - 6 hours
   - LocationVerificationService background tasks

**Deliverable:** Stable build with no known crash vectors

### Phase 2: Data Integrity (Week 2)
**Goal:** Prevent data corruption and improve error handling

4. ✅ **Widget synchronization** (#5) - 4 hours
5. ✅ **Error boundaries** (#7) - 3 hours
6. ✅ **Privacy logging** (#6) - 30 min

**Deliverable:** Better error handling and data consistency

### Phase 3: Code Quality (Week 3-4)
**Goal:** Improve maintainability

7. ✅ **Extract magic numbers** (#8) - 1 hour
8. ✅ **Add test coverage** (#11) - ongoing
9. ✅ **Fix SwiftLint warnings** (#12) - 2-3 hours

**Deliverable:** Cleaner, more maintainable codebase

### Phase 4: Architecture (Future - 2-3 weeks)
**Goal:** Long-term maintainability

10. ⏸️ **Refactor AppData** (#2) - 1-2 weeks
11. ⏸️ **Async/await migration** (#10) - ongoing
12. ⏸️ **View models** (#13) - opportunistic

**Deliverable:** Better architecture for future features

---

## Verification Strategy

### For Each Fix
- [ ] Unit tests added/updated
- [ ] Manual testing on device
- [ ] SwiftLint passes
- [ ] All 181 existing tests still pass
- [ ] Build succeeds in Release mode

### Regression Prevention
- Add test for each bug fixed
- Enable SwiftLint rules incrementally
- Document architectural decisions

---

## Notes

- **Date Conducted:** February 17, 2026
- **Build 7 Status:** Submitted to App Store, awaiting review (submitted Feb 6)
- **Recent Fixes:** Multi-location geofencing, calendar office address
- **Next Review:** After Phase 1 completion or 3 months (whichever comes first)

---

## Appendix: File Inventory

### Critical Files Reviewed
- `InOfficeDaysTracker/Models/AppData.swift` (1143 lines)
- `InOfficeDaysTracker/Models/AppSettings.swift`
- `InOfficeDaysTracker/Services/LocationService.swift`
- `InOfficeDaysTracker/Services/LocationVerificationService.swift`
- `InOfficeDaysTracker/Services/CalendarEventManager.swift`
- `InOfficeDaysTracker/Views/Components/AddressAutocompleteField.swift`
- `OfficeTrackerWidget/*`

### Test Coverage
- `InOfficeDaysTrackerTests/LocationServiceTests.swift` (22 tests)
- `InOfficeDaysTrackerTests/AppDataTests.swift`
- Total: 181 tests passing

---

**Review Status:** Complete  
**Next Action:** Begin Phase 1 - Fix force unwraps (#3)
