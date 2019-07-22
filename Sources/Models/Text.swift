//
//  Text.swift
//  Rover
//
//  Created by Sean Rucker on 2017-10-19.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import UIKit

public struct Text: Decodable {
    public enum Alignment: String, Decodable {
        case center = "CENTER"
        case left = "LEFT"
        case right = "RIGHT"
    }
    
    public struct Font: Decodable {
        public enum Weight: String, Decodable {
            case ultraLight = "ULTRA_LIGHT"
            case thin = "THIN"
            case light = "LIGHT"
            case regular = "REGULAR"
            case medium = "MEDIUM"
            case semiBold = "SEMI_BOLD"
            case bold = "BOLD"
            case heavy = "HEAVY"
            case black = "BLACK"
        }
        
        public var size: Double
        public var weight: Weight
        
        public init(size: Double, weight: Weight) {
            self.size = size
            self.weight = weight
        }
    }
    
    public var rawValue: String
    public var alignment: Alignment
    public var color: Color
    public var font: Font
    
    public init(rawValue: String, alignment: Alignment, color: Color, font: Font) {
        self.rawValue = rawValue
        self.alignment = alignment
        self.color = color
        self.font = font
    }
}

// MARK: Convenience Initializers

extension Text {
    func attributedText(forFormat format: NSAttributedString.DocumentType = .html) -> NSAttributedString? {
        guard let data = rawValue.data(using: String.Encoding.unicode) else {
            return nil
        }
        
        let options = [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.html]
        
        guard let attributedString = try? NSMutableAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }
        
        let range = NSRange(location: 0, length: attributedString.length)
        
        // Bold and italicize
        
        attributedString.enumerateAttribute(NSAttributedString.Key.font, in: range, options: []) { value, range, _ in
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
        
        attributedString.addAttributes(attributes, range: range)
        
        // Remove double newlines at end of string, as a workaround for an artifact that appears in some of the HTML structure in some experiences saved by older versions of the authoring tool.
        
        if format == .html {
            let string = attributedString.string
            if attributedString.length > 0 && string.suffix(1) == "\n" {
                attributedString.replaceCharacters(in: NSRange(location: attributedString.length - 1, length: 1), with: "")
            }
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
