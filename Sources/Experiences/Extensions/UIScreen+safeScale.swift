//
//  UIScreen+safeScale.swift
//  Rover
//
//  Created by Andrew Clunis on 2020-10-29.
//  Copyright © 2020 Rover Labs Inc. All rights reserved.
//

import UIKit

extension UIScreen {
    var safeScale: CGFloat {
        let value = self.scale
        // in some cases, we have seen it occur that scale has returned 0. In that event, return a sane value.
        return value == 0 ? 3.0 : value
    }
}
