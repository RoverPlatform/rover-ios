//
//  Color+uiColor.swift
//  RoverExperiences
//
//  Created by Sean Rucker on 2018-05-04.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

extension Color {
    var uiColor: UIColor {
        let red = CGFloat(self.red) / 255.0
        let green = CGFloat(self.green) / 255.0
        let blue = CGFloat(self.blue) / 255.0
        let alpha = CGFloat(self.alpha)
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
