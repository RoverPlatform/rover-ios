# Rover iOS SDK

If you are currently using Rover SDK 1.x, please see the latest [1.x release
README](https://github.com/RoverPlatform/rover-ios/tree/f7b585f1bc3019da162522c5244a86fd93b2d8e9).

<hr />

## Rover iOS SDK 2.0

The Rover SDK is a collection of Cocoa Touch Frameworks written in Swift. Instead of a single monolithic framework, the Rover SDK takes a modular approach, allowing you to include only the functionality relevant to your application. The SDK is 100% open-source and available on [GitHub](https://github.com/RoverPlatform/rover-ios).

---

## Install the SDK

The recommended way to install the Rover SDK is via [Cocoapods](http://cocoapods.org/).

The Rover [Podspec](https://guides.cocoapods.org/syntax/podspec.html) breaks each of the Rover frameworks out into a separate [Subspec](https://guides.cocoapods.org/syntax/podspec.html#group_subspecs).

The simplest approach is to specify `Rover` as a dependency of your app's target which will add all required and optional subspecs to your project.

```ruby
target 'MyAppTarget' do
  pod 'Rover', '~> 2.0.0'
end
```

Alternatively you can specify the exact set of subspecs you want to include.

```ruby
target 'MyAppTarget' do
    pod 'Rover/Foundation',    '~> 2.0.0'
    pod 'Rover/Data',          '~> 2.0.0'
    pod 'Rover/UI',            '~> 2.0.0'
    pod 'Rover/Experiences',   '~> 2.0.0'
    pod 'Rover/Notifications', '~> 2.0.0'
    pod 'Rover/Location',      '~> 2.0.0'
    pod 'Rover/Bluetooth',     '~> 2.0.0'
    pod 'Rover/Debug',         '~> 2.0.0'
end
```

Please continue onwards from https://www.rover.io/docs/ios/.
