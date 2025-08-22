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
import SwiftUI
import UIKit

/// Displays the Communication Hub as a UIViewController (suitable for modal presentation within the routing system), or when embedding in a UIKit UITabBarController.
public class CommunicationHubHostingController: UIHostingController<CommunicationHubView> {

  public let navigator: CommunicationHubNavigator?

  /// Instantiate a Rover Communication Hub view controller.
  ///
  /// The Communication Hub will adopt your UIAppearance settings by default, but you can override this by by explicitly providing a background color and color scheme.
  ///
  /// - Parameters:
  ///   - accentColor: Provide a custom accent/tint color for tinted elements in the Communication Hub UI.
  ///   - navigationBarBackgroundColor: Set the UINavigationBar's background color
  ///   - navigationBarColorScheme: Specify a color scheme for the elements on the navigation bar. If using a dark or saturated background color, set this to `.dark`.
  public init(
    navigator: CommunicationHubNavigator? = nil, title: String? = nil, accentColor: Color = .accentColor, navigationBarBackgroundColor: Color? = nil, navigationBarColorScheme: ColorScheme? = nil
  ) {
    self.navigator = navigator
    let communicationHubView = CommunicationHubView(
      navigator: navigator ?? CommunicationHubNavigator(), title: title, accentColor: accentColor, navigationBarBackgroundColor: navigationBarBackgroundColor, navigationBarColorScheme: navigationBarColorScheme)
    super.init(rootView: communicationHubView)
  }

  @MainActor required dynamic init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
