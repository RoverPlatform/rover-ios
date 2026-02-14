// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import CoreLocation
import RoverData
import RoverDebug
import RoverExperiences
import RoverFoundation
import RoverLocation
import RoverNotifications
import RoverTelephony
import RoverUI
import UIKit
import UserNotifications
import os.log

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  var locationManager = CLLocationManager()
  var window: UIWindow?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize the Rover SDK with all modules.
    Rover.initialize(assemblers: [
      FoundationAssembler(),
      DataAssembler(accountToken: "<YOUR_SDK_TOKEN>", appGroup: "group.io.rover.Example"),
      UIAssembler(associatedDomains: ["example.rover.io"], urlSchemes: ["rv-example"]),
      ExperiencesAssembler(),
      NotificationsAssembler(appGroup: "group.io.rover.Example"),  // Used to share `UserDefaults` data between the main app target and the notification service extension.
      LocationAssembler(),
      DebugAssembler(),
      TelephonyAssembler(),

      // ⚠️ The debug assembler provides customizations useful during development and debugging. It can be safely
      // ignored and is not useful as a learning resource.
      DebugAssembler(),
    ])

    // Sync notifications, beacons and geofences when the app is opened from a terminated state.
    Rover.shared.syncCoordinator.sync {
      // After the first sync call the updateLocation method on the RegionManager to start monitoring for the nearest beacons and geofences.
      Rover.shared.regionManager.updateLocation(manager: self.locationManager)
    }

    // Setting the minimum background fetch interval is required for background fetch to work properly.
    application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

    // Request access to the user's location, even when the app is in the background. This will present the standard iOS permission prompt to the user.
    locationManager.requestAlwaysAuthorization()

    // Assign the app delegate as the location manager’s delegate and start monitoring for significant location changes.
    locationManager.delegate = self
    locationManager.startMonitoringSignificantLocationChanges()

    // Register to receive remote notifications via Apple Push Notification service. Make sure this is called EVERY time the application finishes launching.
    application.registerForRemoteNotifications()

    // Request permission to display alerts, badge your app's icon and play sounds.
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {
      _, _ in
    }

    // Assign the app delegate as the notification manager’s delegate so we can respond when the user taps a notification.
    UNUserNotificationCenter.current().delegate = self

    // Set custom info about the current user
    Rover.shared.userInfoManager.updateUserInfo { attributes in
      attributes["foo"] = "bar"
    }

    // Add a custom action handler:
    Rover.shared.registerCustomActionCallback { actionEvent in
      // a recommended pattern for having multiple behaviors for different custom actions
      // in your experiences to fire is to use a metadata property called `behaviour` on your
      // experience layer with the action, and then handle it here. Here is an example:
      switch actionEvent.nodeProperties["behavior"] {
      case "openWebsite":
        UIApplication.shared.open(URL(string: "https://rover.io/")!)
      case "printLogMessage":
        os_log(.default, "Hello from Rover!")
      default:
        os_log(.error, "🤷‍♂️")
      }
    }

    // Add a screen viewed callback handler:
    Rover.shared.registerScreenViewedCallback { event in
      // track screen view event into your own analytics tools here.
      // a common pattern for naming screens in many is to indicate hierarchy with slashes.  We'll
      // create a screen name out of the experience's name and screen name, if provided.
      let screenName = "\(event.experienceName ?? "Experience") / \(event.screenName ?? "Screen")"
      os_log("Rover experience screen viewed: %s", type: .default, screenName)

      // MyAnalyticsSDK.trackScreen(screenName)
    }

    Rover.shared.registerButtonTappedCallback { event in
      // track an experience button tapped event into your own analytics tools here.
      os_log("Rover experience button tapped: %s", type: .default, event.nodeName ?? "Button")

      // MyAnalyticsSDK.trackEvent("Button Tapped", ["tags": event.nodeTags])
    }

    // You can mutate outgoing URLRequests from data sources in your experiences, allowing your experiences to use authenticated
    // content.
    Rover.shared.authorize(pattern: "*.apis.myapp.com") { urlRequest in
      urlRequest.setValue("mytoken", forHTTPHeaderField: "Authorization")
    }


    // Global UINavigationBarAppearance settings, commonly used pattern in apps.
    let appearance = UINavigationBarAppearance()
    appearance.backgroundColor = UIColor.green
    appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
    appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

    UINavigationBar.appearance().standardAppearance = appearance
    UINavigationBar.appearance().compactAppearance = appearance
    UINavigationBar.appearance().scrollEdgeAppearance = appearance


    return true
  }

  func application(
    _ application: UIApplication,
    performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    // Sync notifications, beacons and geofences when the app is in the background.
    Rover.shared.syncCoordinator.sync(completionHandler: completionHandler)
  }

  // Called when a push arrives while app is backgrounded and it has content-available is set to 1
  func application(
    _ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if Rover.shared.didReceiveRemoteNotification(
      userInfo: userInfo, fetchCompletionHandler: completionHandler)
    {
      return
    }

    completionHandler(.noData)
  }

  func application(
    _ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // The device successfully registered for push notifications. Pass the token to Rover.
    Rover.shared.tokenManager.setToken(deviceToken)
  }

  func application(
    _ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    // Handle our example:// deep links first
    if url.scheme == "example" {
      if let viewController = window?.rootViewController as? ViewController {
        return viewController.handleDeepLink(url: url)
      }
    }

    // Let the Router handle Rover deep links such as:
    //   - rv-example://presentExperience?experienceID=XXX&campaignID=XXX
    //   - rv-example://presentNotificationCenter
    //   - rv-example://presentSettings.
    return Rover.shared.router.handle(url)
  }

  func application(
    _ application: UIApplication, continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    // Let the Router handle Rover universal links such as:
    //  - https://example.rover.io/XXX
    //  - https://example.rover.io/XXX?campaignID=XXX
    return Rover.shared.router.handle(userActivity)
  }
}

// MARK: CLLocationManagerDelegate

extension AppDelegate: CLLocationManagerDelegate {
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    // Report the user's current location to the RegionManager so it can ensure it is monitoring for the nearest geofences and beacons. This will also track a "Location Updated" event which can be used to deliver location-relevant campaigns.
    Rover.shared.regionManager.updateLocation(manager: manager)
  }

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    switch region {
    case let region as CLBeaconRegion:
      // The user entered a monitored beacon region. Start ranging for more accurate beacon detection.
      Rover.shared.regionManager.startRangingBeacons(in: region, manager: manager)
    case let region as CLCircularRegion:
      // The user entered a geofence region. Track a "Geofence Entered" event.
      Rover.shared.regionManager.enterGeofence(region: region)
    default:
      break
    }
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    switch region {
    case let region as CLBeaconRegion:
      // The user exited a monitored beacon region. Stop ranging to resume geofence monitoring.
      Rover.shared.regionManager.stopRangingBeacons(in: region, manager: manager)
    case let region as CLCircularRegion:
      // The user exited a geofence region. Track a "Geofence Exited" event.
      Rover.shared.regionManager.exitGeofence(region: region)
    default:
      break
    }
  }

  func locationManager(
    _ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion
  ) {
    // The set of nearby beacons changed. Compare to the previous set and track beacon enter/exit events as needed.
    Rover.shared.regionManager.updateNearbyBeacons(beacons, in: region, manager: manager)
  }
}

// MARK: UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if Rover.shared.userNotificationCenterWillPresent(
      notification: notification, withCompletionHandler: completionHandler)
    {
      return
    }

    // Tell the operating system to display the notification the same way as if the app was in the background.
    completionHandler([.badge, .sound, .banner])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    // The user tapped a notification. Pass the response to Rover to handle the intended behavior.
    if Rover.shared.userNotificationCenterDidReceive(
      response: response, withCompletionHandler: completionHandler)
    {
      return
    }

    // If Rover didn't handle the notification and it returns false, then we need to handle it ourselves.
    completionHandler()
  }
}
