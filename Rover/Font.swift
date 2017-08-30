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
            100: UIFont.Weight.ultraLight,
            200: UIFont.Weight.thin,
            300: UIFont.Weight.light,
            400: UIFont.Weight.regular,
            500: UIFont.Weight.medium,
            600: UIFont.Weight.semibold,
            700: UIFont.Weight.bold,
            800: UIFont.Weight.heavy,
            900: UIFont.Weight.black
        ]
        
        return UIFont.systemFont(ofSize: size, weight: weights[weight] ?? UIFont.Weight.regular)
    }
}
