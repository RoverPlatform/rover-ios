//
//  Block.swift
//  Pods
//
//  Created by Ata Namvari on 2016-03-17.
//
//

import UIKit

public enum Unit {
    case Points(CGFloat)
    case Percentage(CGFloat)
}

public struct Offset {
    public var left = Unit.Points(0)
    public var right = Unit.Points(0)
    public var top = Unit.Points(0)
    public var bottom = Unit.Points(0)
    public var center = Unit.Points(0)
    public var middle = Unit.Points(0)
    
    static var ZeroOffset: Offset {
        return Offset()
    }
}

public struct Alignment {
    
    public enum HorizontalAlignment : String {
        case Left = "left"
        case Center = "center"
        case Right = "right"
        case Fill = "fill"
    }
    
    public enum VerticalAlignment : String {
        case Top = "top"
        case Middle = "middle"
        case Bottom = "bottom"
        case Fill = "fill"
    }
    
    public var horizontal = HorizontalAlignment.Left
    public var vertical = VerticalAlignment.Top
}

public class Block: NSObject {
    
    public enum Action {
        case Deeplink(NSURL)
        case Website(NSURL)
        case Screen(String)
    }
    
    // Layout
    
    public enum Position : String {
        case Stacked = "stacked"
        case Floating = "floating"
    }
    
    public var identifier: String? = nil
    
    public var position = Position.Stacked
    
    public var height: Unit?
    public var width: Unit?
    
    public var alignment = Alignment()
    public var offset = Offset.ZeroOffset

    // Appearance
    
    public var backgroundColor = UIColor.clearColor()
    public var borderColor = UIColor.clearColor()
    public var borderRadius: CGFloat = 0
    public var borderWidth: CGFloat = 0
    public var opacity: Float = 1
    public var inset = UIEdgeInsetsZero

    // BackgroundImage
    
    public var backgroundImage: Image?
    public var backgroundContentMode: ImageContentMode = .Original
    public var backgroundScale: CGFloat = 1
    
    public var action: Action?
}

class TextBlock: Block {
    public var text: String?
    public var textAlignment = Alignment(horizontal: .Left, vertical: .Top)
    public var textColor = UIColor.blackColor()
    public var textOffset = Offset.ZeroOffset // TextOffset was never used
    public var font = Font(size: 12, weight: 400) //= UIFont.systemFontOfSize(12)
    
    private var _attributedText: NSAttributedString?
    var attributedText: NSAttributedString? {
        if let data = text?.dataUsingEncoding(NSUnicodeStringEncoding) {
            do {
                if let attrText = _attributedText { return attrText }
                
                guard let attributedString = try? NSMutableAttributedString(data: data, options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType], documentAttributes: nil) else { return nil }
                
                attributedString.enumerateAttribute(NSFontAttributeName, inRange: NSMakeRange(0, attributedString.length), options: []) { (value, range, stop) in
                    guard let fontValue = value as? UIFont else {
                        return
                    }
                    let traits = fontValue.fontDescriptor().symbolicTraits
                    var font: UIFont
                    
                    if traits.contains(.TraitBold) {
                        font = Font(size: self.font.size, weight: min(self.font.weight + 300, 900)).systemFont
                    } else {
                        font = self.font.systemFont
                    }
                    
                    var descriptor = font.fontDescriptor()
                    
                    if traits.contains(.TraitItalic) {
                        descriptor = descriptor.fontDescriptorWithSymbolicTraits(.TraitItalic)
                    }
                    
                    let newFont = UIFont(descriptor: descriptor, size: font.pointSize)
                    attributedString.removeAttribute(NSFontAttributeName, range: range)
                    attributedString.addAttribute(NSFontAttributeName, value: newFont, range: range)
                    
                }
                
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = textAlignment.horizontal.asNSTextAlignment
                
                let attributes = [
                    NSForegroundColorAttributeName: textColor,
                    NSParagraphStyleAttributeName: paragraphStyle
                ]
                
                attributedString.addAttributes(attributes, range: NSMakeRange(0, attributedString.length))
                
                let string = attributedString.string
                
                if attributedString.length > 0 && string.substringFromIndex(string.endIndex.advancedBy(-1)) == "\n" {
                    attributedString.replaceCharactersInRange(NSMakeRange(attributedString.length - 1, 1), withString: "")
                }
                
                _attributedText = attributedString
                
                return attributedString
            } catch {
                rvLog("Bad HTML String", data: text, level: .Error)
                return nil
            }
        } else {
            return nil
        }
    }
}

public class ImageBock: Block {
    public var image: Image?
    
    public required init(image: Image?) {
        self.image = image
        super.init()
    }
}

class WebBlock: Block {
    public var url: NSURL?
    public var scrollable = false
    
    public required init(url: NSURL?) {
        self.url = url
        super.init()
    }
}

public class ButtonBlock: Block {

    public enum State {
        case Normal
        case Highlighted
        case Selected
        case Disabled
    }
    
    public struct Appearance {
        public var titleColor: UIColor = UIColor.blackColor()
        public var title: String?
        public var titleAlignment: Alignment = Alignment(horizontal: .Center, vertical: .Middle)
        public var titleOffset: Offset?
        public var titleFont: UIFont = UIFont.systemFontOfSize(12)
        
        public var backgroundColor: UIColor?
        public var borderColor: UIColor?
        public var borderRadius: CGFloat?
        public var borderWidth: CGFloat?
        
        var attributedTitle: NSAttributedString? {
            if let data = title?.dataUsingEncoding(NSUnicodeStringEncoding) {
                guard let title = title else { return nil }
                let attributedString = NSMutableAttributedString(string: title)
                
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = titleAlignment.horizontal.asNSTextAlignment
                
                attributedString.addAttributes([
                    NSFontAttributeName: titleFont,
                    NSForegroundColorAttributeName: titleColor,
                    NSParagraphStyleAttributeName: paragraphStyle
                    ], range: NSMakeRange(0, attributedString.length))
                return attributedString
            } else {
                return nil
            }
        }
    }
    
    public var appearences: [State: Appearance] = [:]
}

public class Image {
    public let size: CGSize
    public let url: NSURL
    
    var aspectRatio: CGFloat {
        return size.width / size.height
    }
    
    public init(size: CGSize, url: NSURL) {
        self.size = size
        self.url = url
    }
}

public enum ImageContentMode : String {
    case Original = "original"
    case Stretch = "stretch"
    case Tile = "tile"
    case Fill = "fill"
    case Fit = "fit"
}
