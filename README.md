# Rover iOS SDK

The Rover SDK is a Cocoa Touch Framework written in Swift. The SDK is 100% open-source.

---

## Install the SDK

### SwiftPM

The recommended way to install the Rover SDK is via SwiftPM.

In Xcode, in your Project Settings, under Package Dependencies, add a new dependency with the URL of this repository: `https://github.com/roverplatform/rover-ios`.

Note that as of Xcode 13, you have to type the repository URL into the search box and press return.

Leave the dependency rule at the default, "Up To Next Major Version".  Rover follows the standard semver semantic versioning rules.

### Cocoapods

As an alternative, you can use [Cocoapods](http://cocoapods.org/).

Add the Rover dependency to your Podfile.

```ruby
pod 'Rover', '~> 3.91'
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
