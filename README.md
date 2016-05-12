
## Requirements
  - XCode 7 or higher
  - iOS 8.0 or higher
  - iPhone 4S or higher

## Installation

Rover is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "Rover", :git => "https://github.com/RoverPlatform/rover-ios-beta.git"
```
While Rover 4 is in Beta you **MUST** provide the git url in your Podfile.

## Usage

### Getting Started

In your AppDelegate's `application(_:didFinishLaunchingWithOptions:)` setup Rover using your application token.

```swift
Rover.setup(applicationToken: "<YOUR APPLICATION TOKEN>")
```

To start Rover you must call the `startMonitoring` method at some point. You can do this in the same AppDelegate method as above or you may choose to do this after the user has logged in. Note that this method only needs to be called once from your app. Subsequent app launches do not need to call this method, however doing so would not be a problem.

```swift
Rover.startMonitoring()
```

The first time this method is called, iOS presents the user with an alert asking them for permission to use their location in the background. This is required by Apple to monitor for geofences and iBeacons. Make sure to create an entry of type String in your app's `.plist` file with the key `NSLocationAlwaysUsageDescription`. It's value can be used to customize the body of the alert.

### Notifications

Rover's messaging system uses notifications to alert the user when their device is asleep or when your app isn't running. To enable this feature your app must register for notifications, which can be done via the following mehod call:

```swift
Rover.registerForNotifications()
```

This method also triggers an alert asking for permission the first time it is called. Again you can do this right after your setup code in AppDelegate or you may choose to do it at a later point. The Rover SDK needs a few more hooks in your AppDelegate to fully enable notifications, so make sure the following delegate methods are passed onto Rover.

```swift
  func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
      Rover.didReceiveLocalNotification(notification)
  }
  
  func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
      Rover.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
  }
    
  func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
      Rover.didRegisterForRemoteNotification(deviceToken: deviceToken)
  }
```

### Observers

Rover uses the observer pattern to notify the developer of proximity and messaging events. Just call the `Rover.addObserver(_:)` method and pass in any class of your choice that conforms to the [`RoverObserver`](https://github.com/RoverPlatform/rover-ios-beta/blob/master/Pod/Classes/RoverObserver.swift) protocol.

Here's an example of a `UIViewController` listening for proximity callbacks.

```swift
class ViewController: UIViewController, RoverObserver {
  override func viewDidLoad() {
    super.viewDidLoad()
    
    Rover.addObserver(self)
  }
  
  deinit {
    Rover.removeObserver(self)
  }
  
  // MARK: RoverObserver
  
  func didEnterGeofence(location: Location) {
    print("User has entered \(location.name)")
  }
}
```

Note that you **MUST** balance it with a call to `Rover.removeObserver(_:)` in `deinit` or any other unloading method of your choice.

You may choose to do all of this in your AppDelegate for more centralized control.

## License

Rover is available under the MIT license. See the LICENSE file for more info.
