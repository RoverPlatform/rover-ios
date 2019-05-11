//
//  LoadingViewController.swift
//  Rover
//
//  Created by Sean Rucker on 2019-05-11.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit

/// The default view controller displayed by the `RoverViewController` while it is fetching an experience from the
/// server.
///
/// The `LoadingViewController` displays an activity inidicator in the center of the screen. After three seconds it
/// also displays a cancel button. When the cancel button is tapped it dismisses the view controller.
open class LoadingViewController: UIViewController {
    /// The activity indicator displayed in the center of the screen.
    public var activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
    
    /// The cancel button displayed below the activity indicator after 3 seconds.
    public var cancelButton = UIButton(type: .custom)
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        activityIndicator.color = .gray
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.darkText, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)
        
        if #available(iOS 11.0, *) {
            let layoutGuide = view.safeAreaLayoutGuide
            NSLayoutConstraint.activate([
                activityIndicator.centerXAnchor.constraint(equalTo: layoutGuide.centerXAnchor),
                activityIndicator.centerYAnchor.constraint(equalTo: layoutGuide.centerYAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        }
        
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
