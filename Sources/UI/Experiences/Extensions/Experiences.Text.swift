//
//  Text+attributedText.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-05-04.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import UIKit

extension Text {
    var attributedText: NSAttributedString? {
        guard let data = rawValue.data(using: String.Encoding.unicode) else {
            return nil
        }
        
        let options = [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.html]
        
        guard let attributedString = try? NSMutableAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }
        
        let range = NSMakeRange(0, attributedString.length)
        
        // Bold and italicize
        
        #if swift(>=4.2)
        attributedString.enumerateAttribute(NSAttributedString.Key.font, in: range, options: []) { (value, range, stop) in
            guard let value = value as? UIFont else {
                return
            }
            
            let traits = value.fontDescriptor.symbolicTraits
            let fontSize = CGFloat(self.font.size)
            let fontWeight = traits.contains(.traitBold) ? self.font.weight.uiFontWeightBold : self.font.weight.uiFontWeight
            var font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
            
            if traits.contains(.traitItalic) {
                let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic)!
                font = UIFont(descriptor: descriptor, size: fontSize)
            }
            
            attributedString.removeAttribute(NSAttributedString.Key.font, range: range)
            attributedString.addAttribute(NSAttributedString.Key.font, value: font, range: range)
        }
        
        let attributes = [NSAttributedString.Key.foregroundColor: color.uiColor,
                          NSAttributedString.Key.paragraphStyle: alignment.paragraphStyle]
        #else
        attributedString.enumerateAttribute(NSAttributedStringKey.font, in: range, options: []) { (value, range, stop) in
            guard let value = value as? UIFont else {
                return
            }
            
            let traits = value.fontDescriptor.symbolicTraits
            let fontSize = CGFloat(self.font.size)
            let fontWeight = traits.contains(.traitBold) ? self.font.weight.uiFontWeightBold : self.font.weight.uiFontWeight
            var font = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
            
            if traits.contains(.traitItalic) {
                let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic)!
                font = UIFont(descriptor: descriptor, size: fontSize)
            }
            
            attributedString.removeAttribute(NSAttributedStringKey.font, range: range)
            attributedString.addAttribute(NSAttributedStringKey.font, value: font, range: range)
        }
        
        let attributes = [NSAttributedStringKey.foregroundColor: color.uiColor,
                          NSAttributedStringKey.paragraphStyle: alignment.paragraphStyle]
        #endif
        
        attributedString.addAttributes(attributes, range: range)
        
        // Remove double newlines at end of string
        
        let string = attributedString.string
        if attributedString.length > 0 && string.suffix(1) == "\n" {
            attributedString.replaceCharacters(in: NSMakeRange(attributedString.length - 1, 1), with: "")
        }
        
        return attributedString
    }
}

// MARK: Text.Alignment

extension Text.Alignment {
    var textAlignment: NSTextAlignment {
        switch self {
        case .center:
            return .center
        case .left:
            return .left
        case .right:
            return .right
        }
    }
    
    var paragraphStyle: NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        return paragraphStyle
    }
}

// MARK: Text.Font

extension Text.Font {
    var uiFont: UIFont {
        let size = CGFloat(self.size)
        return UIFont.systemFont(ofSize: size, weight: weight.uiFontWeight)
    }
}

// MARK: Text.Font.Weight

extension Text.Font.Weight {
    var uiFontWeight: UIFont.Weight {
        switch self {
        case .ultraLight:
            return UIFont.Weight.ultraLight
        case .thin:
            return UIFont.Weight.thin
        case .light:
            return UIFont.Weight.light
        case .regular:
            return UIFont.Weight.regular
        case .medium:
            return UIFont.Weight.medium
        case .semiBold:
            return UIFont.Weight.semibold
        case .bold:
            return UIFont.Weight.bold
        case .heavy:
            return UIFont.Weight.heavy
        case .black:
            return UIFont.Weight.black
        }
    }
    
    var uiFontWeightBold: UIFont.Weight {
        switch self {
        case .ultraLight:
            return UIFont.Weight.regular
        case .thin:
            return UIFont.Weight.medium
        case .light:
            return UIFont.Weight.semibold
        case .regular:
            return UIFont.Weight.bold
        case .medium:
            return UIFont.Weight.heavy
        case .semiBold, .bold, .heavy, .black:
            return UIFont.Weight.black
        }
    }
}

