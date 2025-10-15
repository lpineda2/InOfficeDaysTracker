# ⚠️ CRITICAL: Script Execution Order Guidelines

## 🚨 What I Did Wrong Today

I ran the scripts in the wrong order and caused the build number collision issue:

1. ❌ Ran `🧪 Run Tests` → Exit code 1 (failed)
2. ❌ Ran `🔨 Build Archive` → Exit code 0 (succeeded) 
3. ❌ Ran `☁️ Upload to TestFlight` → Exit code 1 (failed due to build 31 collision)

**This caused the build number collision because build 31 was already uploaded previously.**

## ✅ Correct Approach for Future Interactions

### Option 1: Use Smart Upload (Recommended)
```bash
./scripts/smart_upload.sh
# OR use VS Code task: "🤖 Smart Upload (Auto-retry)"
```

### Option 2: Use Full Release Pipeline
```bash
./scripts/release.sh --increment
# OR use VS Code task: "📈 Release with Version Increment" 
```

### Option 3: Manual Increment First (If using individual scripts)
```bash
./scripts/update_version.sh --increment-build  # ← MUST do this first!
./scripts/test.sh
./scripts/build.sh  
./scripts/upload.sh
```

## 📋 Rules to Remember

1. **NEVER run individual upload scripts without checking build number first**
2. **ALWAYS use automated pipelines that handle version management**
3. **If tests fail (exit code 1), fix them before proceeding**
4. **When in doubt, use the smart upload script - it handles everything**

## 🎯 For AI Assistant (Me)

When user asks to "build, test and upload":

✅ **DO:** Use `🤖 Smart Upload (Auto-retry)` or `📈 Release with Version Increment`
❌ **DON'T:** Run individual tasks in sequence without version management

This prevents build number collisions and ensures proper workflow.

---
*Created: October 15, 2025 - After learning from build 31 collision incident*