//
//  Font.swift
//  Pods
//
//  Created by Ata Namvari on 2016-08-23.
//
//

import Foundation

open class Font : NSObject {
    let size: CGFloat
    let weight: Int
    
    public init(size: CGFloat, weight: Int) {
        self.size = size
        self.weight = weight
    }
    
    var systemFont: UIFont {
        let weights = [
            100: UIFontWeightUltraLight,
            200: UIFontWeightThin,
            300: UIFontWeightLight,
            400: UIFontWeightRegular,
            500: UIFontWeightMedium,
            600: UIFontWeightSemibold,
            700: UIFontWeightBold,
            800: UIFontWeightHeavy,
            900: UIFontWeightBlack
        ]
        
        return UIFont.systemFont(ofSize: size, weight: weights[weight] ?? UIFontWeightRegular)
    }
}
