# InOfficeDaysTracker - Automation Setup

This project includes a complete automation pipeline for testing, building, and deploying to TestFlight without external dependencies.

## 🚀 Quick Start

### Option 1: VS Code Tasks (Recommended)
Press `Cmd+Shift+P` and search for "Tasks: Run Task", then choose:

- **🧪 Run Tests** - Run unit tests and validate build
- **🔨 Build Archive** - Create production archive and IPA
- **☁️ Upload to TestFlight** - Upload existing archive to TestFlight
- **🚀 Full Release Pipeline** - Complete automation: test → build → upload
- **📈 Release with Version Increment** - Increment build number + full pipeline

### Option 2: Command Line

```bash
# Run individual steps
./scripts/test.sh           # Run tests only
./scripts/build.sh          # Build and create archive
./scripts/upload.sh         # Upload to TestFlight

# Full pipeline
./scripts/release.sh        # Complete pipeline with current build number
./scripts/release.sh -i     # Increment build number + full pipeline
./scripts/release.sh -s     # Skip tests (not recommended)
```

## 📋 Prerequisites

### 1. App-Specific Password (Required for TestFlight upload)

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in and go to "App-Specific Passwords"
3. Generate a new password with label "InOfficeDaysTracker"
4. Add it to your Keychain:

```bash
xcrun altool --store-password-in-keychain-item "ALT_PASSWORD" 
             -u "your-apple-id@email.com" 
             -p "your-app-specific-password"
```

### 2. Update Upload Script

Edit `scripts/upload.sh` and replace `your-apple-id@email.com` with your Apple ID.

## 📁 File Structure

```
scripts/
├── test.sh           # Run unit tests and validation
├── build.sh          # Create archive and export IPA
├── upload.sh         # Upload to TestFlight
├── release.sh        # Full pipeline automation
└── update_version.sh # Version synchronization (prevents ITMS-90473 errors)
.vscode/
└── tasks.json        # VS Code tasks for easy access
exportOptions.plist   # Export configuration for IPA
```

## 🔄 Version Management & Synchronization

### Preventing Apple's ITMS-90473 Version Mismatch Errors

This project includes automatic version synchronization to prevent the common Apple error:
> ITMS-90473: CFBundleShortVersionString Mismatch - The CFBundleShortVersionString value of extension does not match its containing iOS application.

### Using the Version Update Script

```bash
# Validate version consistency (run before any build)
./scripts/update_version.sh --validate

# Increment build number while keeping marketing version
./scripts/update_version.sh --increment-build

# Set specific version and build numbers
./scripts/update_version.sh 1.8.0 5

# Show help
./scripts/update_version.sh --help
```

### Automatic Version Validation

- **Build script** automatically validates version consistency before building
- **Release script** validates versions and optionally increments build number
- **All targets synchronized**: Main app and widget extension versions are kept in sync

### What Gets Synchronized

1. **Project file settings** (`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`)
2. **Main app Info.plist** (`CFBundleShortVersionString` and `CFBundleVersion`)
3. **Widget extension Info.plist** (`CFBundleShortVersionString` and `CFBundleVersion`)

All targets must have matching versions to pass Apple's validation.

## 🛡️ Code Quality & CI

### 1. SwiftLint
Code style is enforced using [SwiftLint](https://github.com/realm/SwiftLint).

**Prerequisite:**
You need **SwiftLint** installed.

**Option 1: Homebrew (Recommended)**
```bash
brew install swiftlint
```

**Option 2: Manual Installation**
1. Download `SwiftLint.pkg` from [GitHub Releases](https://github.com/realm/SwiftLint/releases/latest)
2. Open the package (Right-click > Open if blocked by Gatekeeper) and install.

**VS Code Setup:**
Do not install the deprecated "SwiftLint" extension. Instead, install the **Official Swift Extension**:
- **Name:** Swift
- **Publisher:** Swift Server Work Group
- **ID:** `sswg.swift-lang`

This extension automatically detects your installed `swiftlint` and provides real-time feedback.

### 2. Pre-commit Hook
To prevent bad commits, use the pre-commit script locally:

```bash
# Run manually before committing
./scripts/pre-commit.sh

# Install as git hook (optional but recommended)
ln -s ../../scripts/pre-commit.sh .git/hooks/pre-commit
```

### 3. GitHub Actions CI
A continuous integration pipeline (`.github/workflows/ci.yml`) is configured to run on every:
- Push to `main`
- Pull Request to `main`

**What it checks:**
- Runs `swiftlint` to check code style
- Runs `./scripts/test.sh` to execute all unit tests

## 🔧 Configuration Files

### App Export Compliance
The app includes `ITSAppUsesNonExemptEncryption` set to `false` in both main app and widget Info.plist files. This automatically answers Apple's encryption export compliance question as "None of the algorithms mentioned above" since the app only uses:
- Standard iOS location services encryption
- Standard UserDefaults/Keychain encryption 
- No custom or proprietary encryption algorithms

### exportOptionsTestFlight.plist
- Configured for App Store distribution
- Automatic signing with Team ID: 5G586TFR2Y
- Symbols uploaded, bitcode disabled (iOS 14+ requirement)

### VS Code Tasks
- Integrated with Command Palette
- Color-coded output with emojis
- Problem matcher for Swift compiler errors

## 🎯 Workflow

### Development Workflow
1. Make changes to your code
2. Run **🧪 Run Tests** to validate
3. When ready to release: **🚀 Full Release Pipeline**

### Release Workflow
1. **📈 Release with Version Increment** - Automatically:
   - Increments build number
   - Commits version change to git
   - Runs all unit tests
   - Creates production archive
   - Exports IPA for TestFlight
   - Uploads to App Store Connect
   - **Tags the release in git** (e.g., v1.10.0-82)
   - Shows processing status

## � Release Best Practices

### ✅ Always Release from Main Branch

To avoid version mismatches and maintain a clean git history, **always release from the main branch**.

#### Standard Release Process:

```bash
# 1. Merge your feature branch to main first
git checkout main
git pull origin main
git merge feature/your-feature-name

# 2. Increment build number on main (or let release.sh do it)
git add -A
git commit -m "Merge feature branch"

# 3. Release from main with version increment
./scripts/release.sh -i
# Or use VS Code task: "📈 Release with Version Increment"
# (The script automatically creates and pushes the git tag)

# 4. Continue development from a new branch
git checkout -b feature/next-feature
```

### ⚠️ Why This Matters

- **Main reflects production** - No confusion about deployed versions
- **Clean history** - Easy to track releases
- **Proper tagging** - Tags on main point to exact App Store releases
- **No divergence** - Avoid branches getting ahead of main

### 🚫 Don't Release from Feature Branches

❌ **Wrong:**
```bash
git checkout feature/my-feature
./scripts/release.sh  # Released but main is now behind!
```

✅ **Correct:**
```bash
git checkout main
git merge feature/my-feature
./scripts/release.sh -i  # Main stays in sync with production
```

## �📊 What Each Script Does

### test.sh
- ✅ Runs unit tests on iPhone 16 Pro simulator
- ✅ Validates release build configuration
- ✅ Shows current version and build numbers
- ⏱️ Takes ~30 seconds

### build.sh
- 🧹 Cleans previous builds
- 📦 Creates signed archive for App Store distribution
- 📤 Exports IPA with proper entitlements
- 📊 Shows file size and location
- ⏱️ Takes ~2-3 minutes

### upload.sh
- 📤 Exports specifically for TestFlight distribution
- ☁️ Uploads to App Store Connect using altool
- 📱 Shows upload progress and status
- ⏱️ Takes ~5-10 minutes (depends on file size and internet)

### release.sh
- 🔄 Orchestrates the complete pipeline
- 📈 Optional build number increment
- 🔐 Git commit for version changes
- 🎯 Runs test → build → upload in sequence
- ❌ Stops on first error to prevent bad builds

## 🐛 Troubleshooting

### "Archive not found" Error
Run `./scripts/build.sh` first to create the archive.

### "Upload failed" Error
1. Verify App-Specific Password is set in Keychain
2. Check your Apple ID in `upload.sh`
3. Ensure your Apple ID has access to the app

### SSL Certificate Issues
The scripts use only Xcode command-line tools, so no external network dependencies.

### Build Errors
- Check Team ID (5G586TFR2Y) is correct in scripts
- Verify certificates are installed and valid
- Run `./scripts/test.sh` first to validate the build

## 🚀 Next Steps

1. **Set up App-Specific Password** (see prerequisites)
2. **Test the pipeline**: Run `./scripts/test.sh`
3. **Try a full release**: Use VS Code task "🚀 Full Release Pipeline"
4. **Automate version increments**: Use "📈 Release with Version Increment"

## 💡 Tips

- Use **🧪 Run Tests** frequently during development
- The **🚀 Full Release Pipeline** is your one-click deployment
- Build archives are saved in `./build/` for backup
- Check App Store Connect after upload for processing status
- Processing usually takes 5-15 minutes on Apple's servers

---

*This automation replaces the manual Xcode Organizer workflow and provides consistent, reliable deployments to TestFlight.*

# ⚠️ IMPORTANT: AI ASSISTANT INSTRUCTIONS
When asked about TestFlight deployment, always:
1. Reference this AUTOMATION.md file first
2. Use VS Code tasks or ./scripts/release.sh workflows
3. Follow the documented troubleshooting steps
4. Check prerequisites before starting