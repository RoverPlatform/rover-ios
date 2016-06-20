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

### Initializing the SDK

_The following instructions assume your app is written in Swift. The steps required are the same if your app is written in Objective-C. We will be providing an Objective-C translation in the future. In the meantime if you are having trouble translating the Swift instructions or run into an issue please submit a GitHub issue for support._

To connect your app to the Rover cloud, you must first initialize it with your account token. You can find your account token on the main page of the [Rover Settings App](https://app.rover.io/settings/).

To initialize the Rover SDK, `import Rover` and call `setup(applicationToken:)` with your account token as its argument. 

```swift
import Rover

Rover.setup(applicationToken: 'YOUR_ACCOUNT_TOKEN');
```

In most cases, it makes sense to do this in your AppDelegate's `application(_:didFinishLaunchingWithOptions:)` method.

### Monitoring for beacons and geofences

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
  
  func didDeliverMessage(message: Message) {
    print("User has received message: \(message.text)")
  }
}
```

Note that you **MUST** balance it with a call to `Rover.removeObserver(_:)` in `deinit` or any other unloading method of your choice.

You may choose to do all of this in your AppDelegate for more centralized control.

### Customer Identity

By default the Rover platform will assign a unique identifier to each customer who installs your application. However you may choose to assign your own identifiers. This is particularly useful for mapping data from the Rover Analytics app or if a customer is using your application on multiple platforms. To accomodate this Rover saves customer info to device storage so that it persists across sessions. The following snippet demonstrates assigning your own customer identifier:

```swift
let customer = Rover.customer
customer.identifier = "1234abcdef"
customer.save()
```

In addition to identifiers, you may provide other user attributes for more personlized and segmented messaging via the Rover Messages app. For a full list attributes check [here](https://github.com/RoverPlatform/rover-ios-beta/blob/master/Pod/Classes/Model/Customer.swift).

### Messages

Using the Rover Messages App, one can author rich messages to be delivered on proximity events. A [Message](https://github.com/RoverPlatform/rover-ios-beta/blob/master/Pod/Classes/Model/Message.swift) can have different types of content:
 - A link to a website
 - Deeplink within your app or another app
 - A landing page
 - Custom data defined at the time of message creation (```message.properties```)

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

## License

Rover is available under the MIT license. See the LICENSE file for more info.
