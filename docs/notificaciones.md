# Notifications — native setup

The Dart side is done. Each app package needs these platform edits once. They
are per-app, not shared, because they live in `android/` and `ios/`.

## Android

### `android/app/src/main/AndroidManifest.xml`

Inside `<manifest>`, above `<application>`:

```xml
<!-- Android 13+ runtime permission. Requested from the settings switch. -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<!-- Reminders survive a reboot. Without this the schedule is silently lost. -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

Deliberately **not** requested: `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`.
Google requires a justification form for those and rejects apps that aren't
alarm clocks or calendars. The scheduler uses
`AndroidScheduleMode.inexactAllowWhileIdle`, so a 09:00 reminder may arrive up
to about fifteen minutes late. For a poem, that is fine.

Inside `<application>`:

```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED" />
    <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
    <action android:name="android.intent.action.QUICKBOOT_POWERON" />
    <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
  </intent-filter>
</receiver>
```

### `android/app/build.gradle`

`flutter_local_notifications` needs desugaring:

```gradle
android {
  compileOptions {
    coreLibraryDesugaringEnabled true
    sourceCompatibility JavaVersion.VERSION_11
    targetCompatibility JavaVersion.VERSION_11
  }
}

dependencies {
  coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
```

### Icon

`ServicioAvisos.iniciar()` uses `@mipmap/ic_launcher` as the small icon. Android
renders the small icon as a silhouette, so a detailed launcher icon becomes a
white blob. Add a flat, single-colour `android/app/src/main/res/drawable/ic_notification.png`
(or a vector) and change the string in `servicio_avisos.dart` to
`AndroidInitializationSettings('ic_notification')`.

## iOS

### `ios/Runner/AppDelegate.swift`

Before `GeneratedPluginRegistrant.register`:

```swift
if #available(iOS 10.0, *) {
  UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
}
```

### Notes

* Permission is requested from the settings switch, not at launch — see
  `NotificacionesProvider.activar`.
* iOS caps pending notifications at 64. The plan uses 15 (14 named days plus
  the repeating fallback).
* No background modes or capabilities are needed: everything is scheduled
  locally while the app is in the foreground.

## Verifying

1. Turn the reminder on and set the time two minutes out. One notification
   should arrive naming a poem; tapping it opens that poem in the Today tab.
2. Call `ServicioAvisos.pendientes()` from a debug build: expect 15 entries
   (fewer if today's slot has passed).
3. Change the author filter and check the pending list changed — the plan
   depends on the pool.
4. Reboot the device and re-check the pending list. If it's empty, the boot
   receiver isn't registered.
5. Revoke notification permission in system settings, reopen the app, and open
   settings: the "turn it on in Settings" note should appear.
