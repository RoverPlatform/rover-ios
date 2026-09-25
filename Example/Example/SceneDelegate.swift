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
import RoverUI
import UIKit

/// The window scene delegate, named in Info.plist under `UIApplicationSceneManifest`.
///
/// Apps built with the iOS 27 SDK must adopt the UIScene life cycle; UIKit refuses to
/// launch them otherwise. Deep links and universal links arrive at the scene, not the
/// application, so the Rover router is called from here. Push notifications, background
/// fetch and the notification center delegate stay on `AppDelegate`, which is still where
/// UIKit delivers them.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    // The storyboard named in the scene manifest has already built the window and its
    // root view controller. When the app is launched from a deep link or universal link,
    // the URL arrives here instead of through the callbacks below.
    for context in connectionOptions.urlContexts {
      handle(url: context.url)
    }

    for userActivity in connectionOptions.userActivities {
      handle(userActivity: userActivity)
    }
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
      handle(url: context.url)
    }
  }

  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    handle(userActivity: userActivity)
  }

  private func handle(url: URL) {
    // Handle our example:// deep links first
    if url.scheme == "example", let viewController = window?.rootViewController as? ViewController {
      _ = viewController.handleDeepLink(url: url)
      return
    }

    // Let the Router handle Rover deep links such as:
    //   - rv-example://presentExperience?experienceID=XXX&campaignID=XXX
    //   - rv-example://presentNotificationCenter
    //   - rv-example://presentSettings.
    _ = Rover.shared.router.handle(url)
  }

  private func handle(userActivity: NSUserActivity) {
    // Let the Router handle Rover universal links such as:
    //  - https://example.rover.io/XXX
    //  - https://example.rover.io/XXX?campaignID=XXX
    _ = Rover.shared.router.handle(userActivity)
  }
}
