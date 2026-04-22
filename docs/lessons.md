# Lessons Learned

## Backward Compatibility: Codable struct migrations (April 22, 2026)

### What Happened
Adding a new property (`roundingMode`) to `CompanyPolicy` struct caused all existing user data to fail decoding during app update from TestFlight. Users saw setup screens again as if the app was freshly installed, losing their settings.

### Root Cause
- `CompanyPolicy` uses Swift's synthesized `Codable` implementation
- Synthesized decoder requires ALL non-optional properties to exist in JSON
- Old saved data (build 4) had JSON without `roundingMode` field
- New code (build 5) tried to decode and failed completely
- `AppSettings.init(from decoder:)` failed → fell back to default settings with `isSetupComplete = false`

**Code location:** `InOfficeDaysTracker/Models/CompanyPolicy.swift:41-44`

```swift
struct CompanyPolicy: Codable, Equatable {
    var policyType: PolicyType = .hybrid50
    var customPercentage: Int = 50
    var roundingMode: RoundingMode = .up  // ← NEW property added without migration
}
```

### Why Tests Didn't Catch It
**Test that exists:** `AutoCalculateGoalTests.testCompanyPolicyCodable()` (line 544)

**What it tests:**
- Creates fresh `CompanyPolicy` object (with ALL properties including new ones)
- Encodes to JSON
- Decodes back
- Compares values

**What it doesn't test:**
- Decoding **old JSON** that's missing the new property
- Backward compatibility with data from previous app versions
- Migration scenarios

**The gap:** Round-trip encoding/decoding tests don't validate backward compatibility. They test "can I encode what I just decoded" but not "can I decode data created by older versions."

### The Fix
Implement custom `init(from decoder:)` using `decodeIfPresent` for new properties:

```swift
struct CompanyPolicy: Codable, Equatable {
    var policyType: PolicyType = .hybrid50
    var customPercentage: Int = 50
    var roundingMode: RoundingMode = .up
    
    enum CodingKeys: String, CodingKey {
        case policyType, customPercentage, roundingMode
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        policyType = try container.decode(PolicyType.self, forKey: .policyType)
        customPercentage = try container.decode(Int.self, forKey: .customPercentage)
        // Use decodeIfPresent with default for new properties
        roundingMode = try container.decodeIfPresent(RoundingMode.self, forKey: .roundingMode) ?? .up
    }
}
```

### Prevention Rules

#### When adding properties to Codable structs:
1. **Always use `decodeIfPresent`** for new non-optional properties with sensible defaults
2. **Never rely on synthesized Codable** for structs that persist user data long-term
3. **Write backward compatibility tests** for every Codable data migration

#### Test template for backward compatibility:
```swift
func testCompanyPolicyBackwardCompatibility() throws {
    // Simulate old JSON format (missing new properties)
    let oldJSON = """
    {
        "policyType": "hybrid_50",
        "customPercentage": 50
    }
    """
    
    let data = oldJSON.data(using: .utf8)!
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(CompanyPolicy.self, from: data)
    
    // Verify new properties get sensible defaults
    XCTAssertEqual(decoded.roundingMode, .up)
    XCTAssertEqual(decoded.policyType, .hybrid50)
}
```

#### For TestFlight/Production releases:
1. Test with actual saved data from previous version
2. Include migration tests in CI before releasing
3. Consider versioning in persisted JSON for explicit migration logic

### Detection Signal
- User reports seeing setup screens after updating from TestFlight
- Settings lost after app update
- `loadSettings()` falls back to default `AppSettings()`
- Log message: "Failed to decode settings JSON!"

### Impact
- **Severity:** Critical (data loss for all upgrading users)
- **Scope:** All users upgrading from build 4 to build 5
- **User experience:** Complete loss of settings, must reconfigure app

### Related Files
- `InOfficeDaysTracker/Models/CompanyPolicy.swift` - The struct that broke compatibility
- `InOfficeDaysTracker/Models/AppSettings.swift` - Contains CompanyPolicy, cascades failure
- `InOfficeDaysTracker/Models/AppData.swift:162` - Where decoding failure is caught
- `InOfficeDaysTrackerTests/AutoCalculateGoalTests.swift:544` - Insufficient test coverage

### Tags
`#backward-compatibility` `#data-migration` `#codable` `#critical-bug` `#testflight` `#user-data-loss`
