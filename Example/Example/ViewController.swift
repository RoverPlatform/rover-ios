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
import UIKit

class ViewController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add the inbox to the tab bar
        let inbox = Rover.shared.resolve(UIViewController.self, name: "inbox")!
        inbox.tabBarItem = UITabBarItem(title: "Notifications", image: nil, tag: 0)
        
        // Add the settings view controller to the tab bar.  Note that you typically wouldn't want to add this to the tab bar in your application.  Refer to the documentation.
        let settingsViewController = Rover.shared.resolve(UIViewController.self, name: "settings")!
        settingsViewController.tabBarItem = UITabBarItem(title: "Settings", image: nil, tag: 0)
        
        viewControllers = [
            inbox,
            settingsViewController
        ]
    }
}
