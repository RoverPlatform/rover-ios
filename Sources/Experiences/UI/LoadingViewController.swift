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

import UIKit

/// The default view controller displayed by the `RoverViewController` while it is fetching an experience from the
/// server.
///
/// The `LoadingViewController` displays an activity inidicator in the center of the screen. After three seconds it
/// also displays a cancel button. When the cancel button is tapped it dismisses the view controller.
open class LoadingViewController: UIViewController {
    /// The activity indicator displayed in the center of the screen.
    #if swift(>=4.2)
    public var activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
    #else
    public var activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
    #endif
    
    /// The cancel button displayed below the activity indicator after 3 seconds.
    public var cancelButton = UIButton(type: .custom)
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        activityIndicator.color = .gray
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        
        cancelButton.setTitle(NSLocalizedString("Cancel", comment: "Rover Cancel"), for: .normal)
        cancelButton.setTitleColor(.darkText, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)
        
        let layoutGuide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: layoutGuide.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: layoutGuide.centerYAnchor)
        ])
        
        NSLayoutConstraint.activate([
            cancelButton.centerXAnchor.constraint(equalTo: activityIndicator.centerXAnchor),
            cancelButton.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 8)
        ])
        
        activityIndicator.startAnimating()
        
        // The cancel button starts off hidden and is displayed after 3 seconds
        cancelButton.isHidden = true
        Timer.scheduledTimer(withTimeInterval: TimeInterval(3), repeats: false) { [weak self] _ in
            self?.cancelButton.isHidden = false
        }
    }
    
    @objc
    private func cancel() {
        dismiss(animated: true, completion: nil)
    }
}
