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

import RoverFoundation
import RoverNotifications
import SwiftUI
import UIKit

enum ExampleTab: String, CaseIterable {
  case inbox = "inbox"
  case settings = "settings"
}

class ViewController: UITabBarController {
  private let inboxNavigator = CommunicationHubNavigator()
  private var communicationHubController: CommunicationHubHostingController!

  override func viewDidLoad() {
    super.viewDidLoad()

    // Create the Communication Hub hosting controller with navigator support
    communicationHubController = CommunicationHubHostingController(
      navigator: inboxNavigator,
      /// Optionally specify the Communication Hub's title bar text, if needed. It defaults to "Inbox".
      title: "Inbox",
      // Optionally specify the accent color to use for buttons and links. It defaults to your app's accent color.
      accentColor: .green,
      navigationBarBackgroundColor: Color.blue,
      navigationBarColorScheme: .dark
    )
    communicationHubController.tabBarItem = UITabBarItem(
      title: "Inbox", image: UIImage(systemName: "envelope.open"), tag: 0)

    // Add the settings view controller to the tab bar.  Note that you typically wouldn't want to add this to the tab bar in your application.  Refer to the documentation.
    let settingsViewController = Rover.shared.resolve(UIViewController.self, name: "settings")!
    settingsViewController.tabBarItem = UITabBarItem(
      title: "Settings", image: UIImage(systemName: "gearshape"), tag: 1)

    viewControllers = [
      communicationHubController,
      settingsViewController,
    ]
  }

  // MARK: - Deep Link Handling

  func handleDeepLink(url: URL) -> Bool {
    guard url.scheme == "example", url.host == "tab" else {
      return false
    }

    let pathComponents = url.pathComponents.filter { $0 != "/" }
    guard let tabName = pathComponents.first,
      let tab = ExampleTab(rawValue: tabName)
    else {
      return false
    }

    return switchToTab(tab, url: url)
  }

  private func switchToTab(_ tab: ExampleTab, url: URL) -> Bool {
    switch tab {
    case .inbox:
      selectedIndex = 0
      // Navigate to specific post if postID is provided
      inboxNavigator.navigateToURL(url)
      return true
    case .settings:
      selectedIndex = 1
      return true
    }
  }
}
