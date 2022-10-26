# Rover iOS SDK

This is the Rover SDK, which includes our core Rover Experiences product and marketing campaigns automation.  The Rover SDK allows for the creation of mobile experiences, with added engagement and monetization for better mobile campaigns.

<hr />

The Rover SDK is a collection of Cocoa Touch Frameworks written in Swift. Instead of a single monolithic framework, the Rover SDK takes a modular approach, allowing you to include only the functionality relevant to your application. The SDK is 100% open-source and available on [GitHub](https://github.com/RoverPlatform/rover-ios).

---

## Install the SDK

### SwiftPM

Rover SDK is installed via SwiftPM.

In Xcode, in your Project Settings, under Package Dependencies, add a new dependency with the URL of this repository: `https://github.com/RoverPlatform/rover-ios`.

Note that as of Xcode 13, you have to type the repository URL into the search box and press return.

![SwiftPM Repo Dialog Box](readme-images/swiftpm-select-repo.png)

Leave the dependency rule at the default, "Up To Next Major Version".  Rover follows the standard semver semantic versioning rules.

Then, in the subsequent dialog box, choose the Package Products (frameworks) you wish to use.

![SwiftPM Target Dialog Box](readme-images/swiftpm-select-targets.png)


## Next Steps

Please continue onwards from https://github.com/RoverPlatform/rover-ios/wiki.
