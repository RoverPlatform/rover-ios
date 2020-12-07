# Rover iOS SDK

The Rover SDK is a Cocoa Touch Framework written in Swift. The SDK is 100% open-source.

---

## Install the SDK

The recommended way to install the Rover SDK is via [Cocoapods](http://cocoapods.org/).

Add the Rover dependency to your Podfile.

```ruby
pod 'Rover', '~> 3.8.1'
```

### Carthage

CocoaPods is the simplest approach to installing the Rover SDK but you can also use Carthage.

Add the following entry to your Cartfile:

```ruby
github "RoverPlatform/rover-ios" == 3.8.1
```

## Initialization

You must initialize the Rover SDK with your account token. You can find your account token in the Rover [Settings app](https://app.rover.io/settings). Find the token labelled "SDK Token" and click the icon next to it to copy it to your clipboard.

Import Rover in your app delegate and set the `accountToken` variable from within your `application(_:didFinishLaunchingWithOptions:)` method.

```swift
import Rover

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // ...
    Rover.accountToken = "<YOUR_SDK_TOKEN>"
    // ...
}
```

## Next Steps

The rest of the Rover integration process is described in detail on the Rover developer portal: https://developer.rover.io/v3/ios/.
