//
//  ImageStore.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-04-11.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

public protocol ImageStore {
    func fetchedImage(for configuration: ImageConfiguration) -> UIImage?
    func fetchImage(for configuration: ImageConfiguration, completionHandler: ((UIImage?) -> Void)?)
}
