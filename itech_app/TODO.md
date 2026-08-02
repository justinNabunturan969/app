# Fix KGP Warning - speech_to_text Built-in Kotlin Migration

## Result: Cannot fully migrate yet — plugin authors need to update

## Analysis
- `speech_to_text: ^7.0.0` (7.4.0) and `shared_preferences_android` (2.4.26) internally apply KGP
- Setting `builtInKotlin=true` causes **build failure** because AGP 9.0.1 rejects plugins that explicitly apply KGP
- Plugin authors haven't released versions compatible with Built-in Kotlin yet
- The warning is expected and safe — it does NOT cause slow USB debugging

## What was done (reverted to original working state)
- All 3 Android build files restored to original configuration
- `builtInKotlin=false` (AGP 9.0 backward-compatible mode)
- Build works with the warning

## Recommended future action
- Watch for updates: `speech_to_text` plugin v7.5+ or v8.0 may support Built-in Kotlin
- Run `flutter pub outdated` periodically
- Migrate when all plugins support it

