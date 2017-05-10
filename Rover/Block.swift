//
//  Block.swift
//  Pods
//
//  Created by Ata Namvari on 2016-03-17.
//
//

import UIKit

public enum Unit {
    case points(CGFloat)
    case percentage(CGFloat)
}

public struct Offset {
    public var left = Unit.points(0)
    public var right = Unit.points(0)
    public var top = Unit.points(0)
    public var bottom = Unit.points(0)
    public var center = Unit.points(0)
    public var middle = Unit.points(0)
    
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

open class Block: NSObject {
    
    public enum Action {
        case deeplink(URL)
        case website(URL)
        case screen(String)
    }
    
    // Layout
    
    public enum Position : String {
        case Stacked = "stacked"
        case Floating = "floating"
    }
    
    open var identifier: String? = nil
    
    open var position = Position.Stacked
    
    open var height: Unit?
    open var width: Unit?
    
    open var alignment = Alignment()
    open var offset = Offset.ZeroOffset

    // Appearance
    
    open var backgroundColor = UIColor.clear
    open var borderColor = UIColor.clear
    open var borderRadius: CGFloat = 0
    open var borderWidth: CGFloat = 0
    open var opacity: Float = 1
    open var inset = UIEdgeInsets.zero

    // BackgroundImage
    
    open var backgroundImage: Image?
    open var backgroundContentMode: ImageContentMode = .Original
    open var backgroundScale: CGFloat = 1
    
    open var action: Action?
    open var customKeys = [String: String]()
}

class TextBlock: Block {
    open var text: String?
    open var textAlignment = Alignment(horizontal: .Left, vertical: .Top)
    open var textColor = UIColor.black
    open var textOffset = Offset.ZeroOffset // TextOffset was never used
    open var font = Font(size: 12, weight: 400) //= UIFont.systemFontOfSize(12)
    
    fileprivate var _attributedText: NSAttributedString?
    var attributedText: NSAttributedString? {
        if let data = text?.data(using: String.Encoding.unicode) {
            do {
                if let attrText = _attributedText { return attrText }
                
                guard let attributedString = try? NSMutableAttributedString(data: data, options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType], documentAttributes: nil) else { return nil }
                
                attributedString.enumerateAttribute(NSFontAttributeName, in: NSMakeRange(0, attributedString.length), options: []) { (value, range, stop) in
                    guard let fontValue = value as? UIFont else {
                        return
                    }
                    let traits = fontValue.fontDescriptor.symbolicTraits
                    var font: UIFont
                    
                    if traits.contains(.traitBold) {
                        font = Font(size: self.font.size, weight: min(self.font.weight + 300, 900)).systemFont
                    } else {
                        font = self.font.systemFont
                    }
                    
                    var descriptor = font.fontDescriptor
                    
                    if traits.contains(.traitItalic) {
                        descriptor = descriptor.withSymbolicTraits(.traitItalic)!
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
                ] as [String : Any]
                
                attributedString.addAttributes(attributes, range: NSMakeRange(0, attributedString.length))
                
                let string = attributedString.string
                
                if attributedString.length > 0 && string.substring(from: string.characters.index(string.endIndex, offsetBy: -1)) == "\n" {
                    attributedString.replaceCharacters(in: NSMakeRange(attributedString.length - 1, 1), with: "")
                }
                
                _attributedText = attributedString
                
                return attributedString
            } catch {
                rvLog("Bad HTML String", data: text, level: .error)
                return nil
            }
        } else {
            return nil
        }
    }
}

open class ImageBock: Block {
    open var image: Image?
    
    public required init(image: Image?) {
        self.image = image
        super.init()
    }
}

class WebBlock: Block {
    open var url: URL?
    open var scrollable = false
    
    public required init(url: URL?) {
        self.url = url
        super.init()
    }
}

open class ButtonBlock: Block {

    public enum State {
        case normal
        case highlighted
        case selected
        case disabled
    }
    
    public struct Appearance {
        public var titleColor: UIColor = UIColor.black
        public var title: String?
        public var titleAlignment: Alignment = Alignment(horizontal: .Center, vertical: .Middle)
        public var titleOffset: Offset?
        public var titleFont: UIFont = UIFont.systemFont(ofSize: 12)
        
        public var backgroundColor: UIColor?
        public var borderColor: UIColor?
        public var borderRadius: CGFloat?
        public var borderWidth: CGFloat?
        
        var attributedTitle: NSAttributedString? {
            if let data = title?.data(using: String.Encoding.unicode) {
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
    
    open var appearences: [State: Appearance] = [:]
}

open class Image {
    open let size: CGSize
    open let url: URL
    
    var aspectRatio: CGFloat {
        return size.width / size.height
    }
    
    public init(size: CGSize, url: URL) {
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
