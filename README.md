# iOS SDK Integration

## Requirements
  - XCode 7 or higher
  - iOS 8.0 or higher
  - iPhone 4S or higher

## Installing the library

### CocoaPods

The easiest way to get Rover into your iOS project is to use [CocoaPods](http://cocoapods.org/). If you've never used CocoaPods before you can follow their [Getting Started](https://guides.cocoapods.org/using/getting-started.html) guide to get it setup on your machine. After you've installed CocoaPods the following steps will add the Rover SDK to your project.

1. Run `pod init` from your Xcode project directory to create a Podfile.
2. The Rover SDK is a dynamic framework written in Swift. Add `use_frameworks!` to the top of your Podfile to enable [framework and Swift support](https://blog.cocoapods.org/CocoaPods-0.36/).
3. Add the Rover pod within the main target of your Podfile:
   
   ```ruby
   target 'My App' do
       pod 'Rover', :git => 'https://github.com/RoverPlatform/rover-ios.git'
   end
   ```
   
   Note: The path to the GitHub repository is required while the Rover SDK is in beta. 
4. Run `pod install` from your Xcode project directory. CocoaPods should download and install the Rover library, and create a new Xcode workspace. Open up this workspace in Xcode.

### Carthage

Coming soon...

### Manual Installation

You can also get the library by downloading the [latest version from Github](https://github.com/RoverPlatform/rover-ios/tree/0.2.0) and copying it into your project.

## Initializing the SDK

_The following instructions assume your app is written in Swift. The steps required are the same if your app is written in Objective-C. We will be providing an Objective-C version in the future. In the meantime if you are having trouble translating the Swift instructions or run into an issue please submit a GitHub issue for support._

To connect your app to the Rover cloud, you must first initialize it with your account token. You can find your account token on the main page of the [Rover Settings App](https://app.rover.io/settings/).

To initialize the Rover SDK, `import Rover` and call `setup(applicationToken:)` with your account token as its argument. 

```swift
import Rover

Rover.setup(applicationToken: "YOUR_ACCOUNT_TOKEN");
```

In most cases, it makes sense to do this in your AppDelegate's `application(_:didFinishLaunchingWithOptions:)` method.

## Monitoring for Beacons and Geofences

Call the `startMonitoring` method to begin monitoring for beacons and geofences. You can do this immediately after initializing the Rover SDK or you may choose to do this at a later time. 

```swift
Rover.startMonitoring()
```

When this method is called Rover will invoke the [` requestAlwaysAuthorization`](https://developer.apple.com/library/ios/documentation/CoreLocation/Reference/CLLocationManager_Class/#//apple_ref/occ/instm/CLLocationManager/requestAlwaysAuthorization) method of CoreLocation. The first time this method is called the operating system will prompt the user to give your app access to their location. This is required in order to detect beacons and geofences. 

![](https://images-rover-io.imgix.net/wiki/iso-location-prompt.png)

__IMPORTANT__
The user prompt contains the text from the `NSLocationAlwaysUsageDescription` key in your app’s `Info.plist` file, and the presence of that key is required when calling this method. If you don't set this key, the prompt will not be displayed and your app will not be granted access to your users' location. 

```xml
<key>NSLocationAlwaysUsageDescription</key>
<string>Your Description Goes Here</string>
```

### Controlling The Prompt

Often you will want more control over when your users are presented with the location permission prompt. For example, you may wish to display a screen explaining all the benefits of allowing your app to track their location. In this case you can delay the `startMonitoring` call until you are ready for the prompt to be displayed. 

You can also call the `requestAlwaysAuthorization` method yourself. If the user has given permission prior to the `Rover.startMonitoring` call the prompt will not be displayed again.

### requestAlwaysAuthorization vs requestWhenInUseAuthorization

Detecting beacons and geofences while your app is in the background requires `requestAlwaysAuthorization`. If your app has previously been granted `requestWhenInUseAuthorization` you will need to.... <INSERT STEPS TO FIX HERE>.

### Proximity Events

Rover uses the observer pattern to notify the developer of proximity events. The `Rover.addObserver(_:)` method accepts a object that conforms to the [`RoverObserver`](https://github.com/RoverPlatform/rover-ios/blob/0.2.0/Pod/Classes/RoverObserver.swift) protocol as its argument. Any object in your application that conforms to this protocal can observe proximity events.

Here's an example of a `UIViewController` that adds itself as an observer and implements proximity callbacks.

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
  
  optional func didEnterBeaconRegion(config config: BeaconConfiguration, place: Place?) {
    
  }
    
  optional func didExitBeaconRegion(config config: BeaconConfiguration, place: Place?) {
  
  }
    
  optional func didEnterGeofence(place place: Place) {
  
  }
    
  func didExitGeofence(place place: Place) {
  
  }
}
```

__IMPORTANT__ Notice that the example removes itself as an observer in the `deinit` method. This is required in order for the class to properly deallocate itself. Any call to `Rover.addObserver(_:)` _must_ be balanced with a corresponding call to `Rover.removeObserver(_:)`.

### Beacons and Places

Using the [Rover Proximity App](https://app.rover.io/proximity/) you can add beacons and places you would like the Rover SDK to monitor for. When Rover detects that the user has entered or exited a beacon or place the appropriate observer method will be called with the corresponding [`BeaconConfiguration`](https://github.com/RoverPlatform/rover-ios/blob/0.2.0/Pod/Classes/Model/BeaconConfiguration.swift) and/or [`Place`](https://github.com/RoverPlatform/rover-ios/blob/0.2.0/Pod/Classes/Model/Location.swift) objects.

You can use these observer callbacks in your app to (for example) adapt your app's user interface when the user is in a specific place.

## Messages

Using the [Rover Messages App](https://app.rover.io/messages/) you can create messages that are delivered to your users when a proximity event is triggered or on a specific date and time. You can attach push notifications to your messages that will be delivered along with your messages. Additionally you can attach content to your messages. The content can be a landing page authored in the [Rover Messages App](https://app.rover.io/messages/) or it can simply link to a website. A message can also trigger functionality within your app through a deep link and can have custom data attached.

### Notifications

Call the `Rover.registerForNotifications` method to enable your app to deliver notifications. Similar to the `Rover.startMonitoring` method you can call this as part of your initialization logic or you may wish to call this at a later time.

```swift
Rover.registerForNotifications()
```
In order for Rover to deliver notifications your app to deliver notifications the user must accept a permission dialog similar to location monitoring.

Rover's messaging system uses notifications to alert the user when their device is asleep or when your app isn't running. To enable this feature your app must register for notifications, which can be done via the following mehod call:



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

### Inbox

Most applications provide means for users to recall messages. You can use the `didDeliverMessage(_:)` callback on a [`RoverObserver`](https://github.com/RoverPlatform/rover-ios-beta/blob/master/Pod/Classes/RoverObserver.swift) to map and add Rover messages to your application's inbox as they are delivered. You may also rely solely on Rover for a simple implementation of such inbox if your application doesn't already have one:

```swift
Rover.reloadInbox { messages in
  // store messages array in memory
  // reload tableview
}
```

Note that the `reloadInbox` method will only return messages that have been marked to be saved in the Rover Messages app.

See the [InboxViewController](https://github.com/RoverPlatform/rover-ios-beta/blob/master/Example/Rover/InboxTableViewController.swift) for a quick implementation of both strategies.

### Landing Pages

Some messages can carry with them rich content in the form of landing pages. A landing page is a [Screen](https://github.com/RoverPlatform/rover-ios-beta/blob/master/Pod/Classes/Model/Screen.swift) that is an optional property of a [Message](https://github.com/RoverPlatform/rover-ios-beta/blob/master/Pod/Classes/Model/Message.swift). The Rover SDK provides means to render this screen natively as a UIViewController, which you can present modally or push onto a stack of view controllers inside a UINavigationController.

```swift
if let screen = message.screen {
  let viewController = RVScreenViewController(screen: screen)
  viewController.delegate = self
  
  self.presentViewController(viewController, animated: true, completion: nil)
}
```

If you are to implement in this manner it is crucial to define a [RVScreenViewControllerDelegate](https://github.com/RoverPlatform/rover-ios-beta/blob/master/Pod/Classes/UI/RVScreenViewController.swift) to handle cases where the landing page links off to a website or a deeplink within the app. This usecase is also demonstrated in the [InboxViewController](https://github.com/RoverPlatform/rover-ios-beta/blob/master/Example/Rover/InboxTableViewController.swift).

### Customer Identity

By default the Rover platform will assign a unique identifier to each customer who installs your application. However you may choose to assign your own identifiers. This is particularly useful for mapping data from the Rover Analytics app or if a customer is using your application on multiple platforms. To accomodate this Rover saves customer info to device storage so that it persists across sessions. The following snippet demonstrates assigning your own customer identifier:

```swift
let customer = Rover.customer
customer.identifier = "1234abcdef"
customer.save()
```

In addition to identifiers, you may provide other user attributes for more personlized and segmented messaging via the Rover Messages app. For a full list attributes check [here](https://github.com/RoverPlatform/rover-ios-beta/blob/master/Pod/Classes/Model/Customer.swift).

## License

Rover is available under the MIT license. See the LICENSE file for more info.
