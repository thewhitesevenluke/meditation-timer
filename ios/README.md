# Golden Meditation iOS

Golden Meditation is currently an iOS-first app. The iPhone experience is implemented in native SwiftUI inside `ios/App/App/AppDelegate.swift`.

## Install on iPhone

```sh
npm install
npm run ios:install
npm run ios:open
```

`npm run ios:install` builds, installs, and tries to launch the app on the first connected iPhone. On the iPhone, trust the developer profile if iOS asks.

## Architecture

- `ios/App/App/AppDelegate.swift` is the native app entry point and contains the SwiftUI timer UI.
- `ios/App/App/Info.plist` enables the iOS `audio` background mode.
- `web/public/` contains shared static assets used by the iOS bundle.
- `web/` contains the React + Vite web layer.

The iOS app does not run the React app in a WebView. The main iPhone UI is native SwiftUI.

## Background Timer

The alarm-like behavior is achieved with background audio, not local notifications.

When a timer starts, the app:

- configures `AVAudioSession` with the `.playback` category;
- declares `UIBackgroundModes` with `audio` in `Info.plist`;
- starts a silent looping `AVAudioPlayer` to keep the audio session active;
- runs a `DispatchSourceTimer` and calculates elapsed time from `Date`, so the timer stays accurate across foreground/background transitions.

This lets the gong continue while the screen is locked or the app is backgrounded. If the user force-quits the app from the app switcher, do not treat the timer as reliable.

## Battery Notes

This approach uses extra battery because the app keeps an audio session alive and ticks once per second while running. The cost should usually be modest for meditation-length sessions, but it is not zero.

If the app later needs a lower-power end-of-session alert, consider scheduling local notifications with `UNUserNotificationCenter`. Local notifications are delivered by iOS even when the app is not running, but they are less suitable for precise in-session interval gongs and custom audio behavior.

Apple references:

- [AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession)
- [AVAudioSession playback category](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback)
- [UIBackgroundModes](https://developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes)
- [Scheduling local notifications](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
