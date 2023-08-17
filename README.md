# Using `@Native` in an FFI plugin on Android

This uses `@Native external` functions in `flutter create --template=plugin_ffi`.

Using `dlopen` with `RTLD_GLOBAL` makes symbols available in
`DynamicLibrary.process()` and for `@Native external` functions.

Apparently, the trick with `dlopen` and `RTLD_GLOBAL` does _not_ work on simulators.

```
dacoharkes-macbookpro2:example dacoharkes$ flutter run -d Nexus
Downloading android-arm-profile/darwin-x64 tools...              1,247ms
Downloading android-arm-release/darwin-x64 tools...                900ms
Downloading android-arm64-profile/darwin-x64 tools...              768ms
Downloading android-arm64-release/darwin-x64 tools...              959ms
Downloading android-x64-profile/darwin-x64 tools...                976ms
Downloading android-x64-release/darwin-x64 tools...                874ms
Resolving dependencies... 
  material_color_utilities 0.5.0 (0.8.0 available)
Got dependencies!
Launching lib/main.dart on Nexus 5X in debug mode...
Running Gradle task 'assembleDebug'...                             30.1s
✓  Built build/app/outputs/flutter-apk/app-debug.apk.
Installing build/app/outputs/flutter-apk/app-debug.apk...          37.4s
I/flutter ( 6781): [sumHandleInDefault1, Pointer: address=0x0]
I/flutter ( 6781): [providesSum1, false]
I/flutter ( 6781): Globally opening libmy_plugin.so.
I/flutter ( 6781): [dylibHandle, Pointer: address=0x7f9a2c4ba8]
I/flutter ( 6781): [sumHandleInDefault2, Pointer: address=0x7fa1019640]
Syncing files to device Nexus 5X...                                 57ms

Flutter run key commands.
r Hot reload. 🔥🔥🔥
R Hot restart.
h List all available interactive commands.
d Detach (terminate "flutter run" but leave application running).
c Clear the screen
q Quit (terminate the application on the device).

A Dart VM Service on Nexus 5X is available at: http://127.0.0.1:53356/1EzmGBwiagQ=/
The Flutter DevTools debugger and profiler on Nexus 5X is available at: http://127.0.0.1:9102?uri=http://127.0.0.1:53356/1EzmGBwiagQ=/

Application finished.






dacoharkes-macbookpro2:example dacoharkes$ flutter run -d emu
Launching lib/main.dart on sdk gphone64 arm64 in debug mode...
Running Gradle task 'assembleDebug'...                           1,991ms
✓  Built build/app/outputs/flutter-apk/app-debug.apk.
Installing build/app/outputs/flutter-apk/app-debug.apk...          728ms
Syncing files to device sdk gphone64 arm64...                       46ms

Flutter run key commands.
r Hot reload. 🔥🔥🔥
R Hot restart.
h List all available interactive commands.
d Detach (terminate "flutter run" but leave application running).
c Clear the screen
q Quit (terminate the application on the device).

A Dart VM Service on sdk gphone64 arm64 is available at: http://127.0.0.1:53514/rZ0DPUXFHCM=/
I/flutter (18321): [sumHandleInDefault1, Pointer: address=0x0]
I/flutter (18321): [providesSum1, false]
I/flutter (18321): Globally opening libmy_plugin.so.
I/flutter (18321): [dylibHandle, Pointer: address=0x603cdea9cf7faf73]
I/flutter (18321): [sumHandleInDefault2, Pointer: address=0x7baa5d7640]

══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞═══════════════════════════════════════════════════════════
The following _Exception was thrown building MediaQuery(MediaQueryData(size: Size(392.7, 791.3),
devicePixelRatio: 2.8, textScaler: no scaling, platformBrightness: Brightness.light, padding:
EdgeInsets(0.0, 24.0, 0.0, 0.0), viewPadding: EdgeInsets(0.0, 24.0, 0.0, 0.0), viewInsets:
EdgeInsets.zero, systemGestureInsets: EdgeInsets(29.8, 24.0, 29.8, 16.0), alwaysUse24HourFormat:
false, accessibleNavigation: false, highContrast: false, onOffSwitchLabels: false,
disableAnimations: false, invertColors: false, boldText: false, navigationMode: traditional,
gestureSettings: DeviceGestureSettings(touchSlop: 8.0), displayFeatures: [])):
Exception: "sum" is not available in the Process

When the exception was thrown, this was the stack:
#0      ensureDylibGloballyOpened.<anonymous closure> (package:my_plugin/my_plugin.dart:98:7)
...
```