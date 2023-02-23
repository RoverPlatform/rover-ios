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

public struct ClassicText: Decodable {
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
    public var color: ClassicColor
    public var font: Font
    
    public init(rawValue: String, alignment: Alignment, color: ClassicColor, font: Font) {
        self.rawValue = rawValue
        self.alignment = alignment
        self.color = color
        self.font = font
    }
}

// MARK: Convenience Initializers

extension ClassicText {
    func attributedText(forFormat format: NSAttributedString.DocumentType) -> NSAttributedString? {
        guard let data = rawValue.data(using: String.Encoding.unicode) else {
            return nil
        }
        
        let options = [NSAttributedString.DocumentReadingOptionKey.documentType: format]
        
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
        
        // Workaround to remove an unwanted trailing newline produced by a closing </p> tag being parsed by NSAttributeString's HTML parser.
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

extension ClassicText.Alignment {
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

extension ClassicText.Font {
    var uiFont: UIFont {
        let size = CGFloat(self.size)
        return UIFont.systemFont(ofSize: size, weight: weight.uiFontWeight)
    }
}

// MARK: Text.Font.Weight

extension ClassicText.Font.Weight {
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
