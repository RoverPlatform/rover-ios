# Support

We use GitHub issues for developer support. If you're stuck for any reason, we encourage you to [review the outstanding issues](https://github.com/RoverPlatform/rover-ios/issues) and submit a new issue if you can't find your answer. The following are all valid reasons to submit an issue:

- You found a bug in the SDK code
- You want to propose a new feature
- You have a general question about the SDK
- You are having trouble getting the SDK setup

We monitor these issues regularly and usually respond within an hour.

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
   use_frameworks!
   
   target 'My App' do
       pod 'Rover', :git => 'https://github.com/RoverPlatform/rover-ios.git'
   end
   ```
   
   Note: The path to the GitHub repository is required while the Rover SDK is in beta. 
4. Run `pod install` from your Xcode project directory. CocoaPods should download and install the Rover library, and create a new Xcode workspace. Open up this workspace in Xcode.

### Carthage

Coming soon...

### Manual Installation

You can also get the library by downloading the [latest version from Github](https://github.com/RoverPlatform/rover-ios/tree/0.2.0) and copying it into your project. Just copy all files from [this directory](https://github.com/RoverPlatform/rover-ios/tree/master/Pod/Classes)

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

Detecting beacons and geofences while your app is in the background requires `requestAlwaysAuthorization`. If your app has previously been granted `requestWhenInUseAuthorization` you will need to guide your users to your apps settings page where they can select the `Always` permission under location access.

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
  
  func didEnterBeaconRegion(config config: BeaconConfiguration, place: Place?) {
    
  }
    
  func didExitBeaconRegion(config config: BeaconConfiguration, place: Place?) {
  
  }
    
  func didEnterGeofence(place place: Place) {
  
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

In order to have notification working, Rover needs your apps APNS certificates. Use [this guide](https://github.com/RoverPlatform/rover-ios/wiki/APNS-Setup) to upload your certificate to Rover.

Call the `Rover.registerForNotifications` method to enable your app to deliver notifications. Similar to the `Rover.startMonitoring` method this will also trigger an alert asking for permission the first time it is called. You can call this as part of your initialization logic or you may wish to call this at a later time.

```swift
Rover.registerForNotifications()
```

The Rover SDK needs a few more hooks in your AppDelegate to fully enable notifications, so make sure the following delegate methods are passed onto Rover.

```swift
  func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
      Rover.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
  }
    
  func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
      Rover.didRegisterForRemoteNotification(deviceToken: deviceToken)
  }
```

### Message Observers

Rover implements callbacks you can implement in your RoverObservers to handle the receiving and opening of messages.

#### Receiving Messages

Messages are delivered from the Rover server to your app. A message is received by your app if it is delivered while your app is in the foreground or if your app opens as a result of the user swiping a message's notification. This functionality mirrors the behaviour of the `UIApplicationDidReceiveRemoteNotification` method.

In both of these cases the `didReceiveMessage` callback will be invoked on your Rover observers.

```swift
didReceiveMessage(message: Message)
```

#### Opening Messages

After a message is received the Rover SDK can automatically open the message. The behaviour for opening a message depends on the content type of the message. Landing pages and websites will be presented modally in a special view controller that includes a close button to automatically dismiss itself. Messages with a content type of deep link will call the `UIApplication.openURL` method. Messages with a content type of custom will not trigger any behaviour. For all messages, regardless of content type, the act of opening the message will track a event on the Rover cloud.

Before Rover opens the message it will call the `shouldOpenMessage` callback on your observers. If all of your observers return `true`, Rover will open the message. If one or more of your observers return `false`, Rover will _not_ open the message. If none of your observers implement this method Rover will determine whether the message should be opened. The default behaviour is to open the message _only_ if the message was received from a notification swipe and not if the message was recieved while your app is in the foreground.

```swift
shouldOpenMessage(message: Message) -> Bool
```

#### Customizing the Default Behaviour

In some cases you may want to handle opening messages yourself. To do this you should implement the `shouldOpenMessage` method in one of your observers and return false. You should also implement the `didReceiveMessage` method and implement your custom behaviour.

```swift
shouldOpenMessage(message: Message) {
  return false
}

didReceiveMessage(message: Message) {
  // Implement custom behaviour
}
```

##### Checking for Swipes

Your custom implementation will likely differ depending on whether the message was received while your app is in the foreground or as a result of the user swiping the message's notification. The following example shows how you can make this distinction.

```swift
didReceiveMessage(message: Message) {
  if UIApplication.sharedApplication().applicationState == .Active {
    // Message received will app is in the foreground
  } else {
    // Message received as a result of swiping the notification
  }
}
```

##### The Screen View Controller

If the message contains a landing page you probably want to instantiate a view controller for it. The `landingPage` property of a [`Message`](https://github.com/RoverPlatform/rover-ios/blob/0.2.0/Pod/Classes/Model/Message.swift) object is of type [`Screen`](https://github.com/RoverPlatform/rover-ios/blob/0.2.0/Pod/Classes/Model/Screen.swift). You can use the `Rover.viewController` method which takes a [`Message`](https://github.com/RoverPlatform/rover-ios/blob/0.2.0/Pod/Classes/Model/Message.swift) object and returns a [`ScreenViewController`](https://github.com/RoverPlatform/rover-ios/blob/0.2.0/Pod/Classes/UI/RVScreenViewController.swift).

```swift
didReceiveMessage(message: Message) {
  if message.action == .LandingPage {
    let screenViewController = Rover.viewController(message: message) as? RVScreenViewController
  }
}
```

There is a little magic happening behind the scenes that makes this method especially valuable. 

Often you will have a [`Message`](https://github.com/RoverPlatform/rover-ios/blob/0.2.0/Pod/Classes/Model/Message.swift) object with its content type set to `.LandingPage` but the `message.landingPage` property is null. This is because the SDK has received the message but has not yet loaded the landing page. A typical landing page amounts for 5-6 Kb and is loaded on demand to optimize bandwidth effeciency. 

The `Rover.viewController` method accepts a [`Message`](https://github.com/RoverPlatform/rover-ios/blob/0.2.0/Pod/Classes/Model/Message.swift) object and returns a [`ScreenViewController`](https://github.com/RoverPlatform/rover-ios/blob/0.2.0/Pod/Classes/UI/RVScreenViewController.swift) that knows how to load its contents.

##### The Modal View Controller

Rover provides another view controller called [`ModalViewController`](https://github.com/RoverPlatform/rover-ios/blob/7173352fb18d79f8f440b00eb00b7af95f5cb72f/Pod/Classes/UI/NavigationController.swift) which is useful for opening messages. The [`ModalViewController`](https://github.com/RoverPlatform/rover-ios/blob/7173352fb18d79f8f440b00eb00b7af95f5cb72f/Pod/Classes/UI/NavigationController.swift) _wraps_ another view controller, adding a titlebar with a close button that will automatically dismiss itself. This can be useful when presenting a landing page or website after the user swipes a message's notification.

```swift
didReceiveMessage(message: Message) {
  if message.action == .Website {
    let url = message.url
    let safariViewController = SFSafariViewController(URL: url)
    let modalViewController = ModalViewController(safariViewController)
    this.presentViewController(modalViewController, true)
  }
}
```

##### Accessing Custom Properties

Messages authored in the [Rover Messages App](https://app.rover.io/messages/) can have custom properties attached to them. You can access those properties on the message object in the `didReceiveMessage` method.

```swift
didReceiveMessage(message: Message) {
  // message.properties
}
```

##### Tracking Message Open Events

The Rover SDK will automatically track message open events on notificaiton swipes. However if you have implemented an Inbox style view controller where users can relaunch message content, you will need to user the following method to accurately track message open events.

```swift
Rover.trackMessageOpenEvent(message: Message)
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
