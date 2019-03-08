//
//  OpenURLAction.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-04-27.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

open class OpenURLAction: Action {
    public let url: URL
    
    public init(url: URL) {
        self.url = url
    }
    
    override open func execute() {
        DispatchQueue.main.async { [weak self, url] in
            UIApplication.shared.open(url, options: [:]) { [weak self] _ in
                self?.finish()
            }
        }
    }
}
