//
//  Block.swift
//  Pods
//
//  Created by Ata Namvari on 2016-03-17.
//
//

import UIKit

enum Unit {
    case Points(CGFloat)
    case Percentage(CGFloat)
}

struct Offset {
    var left = Unit.Points(0)
    var right = Unit.Points(0)
    var top = Unit.Points(0)
    var bottom = Unit.Points(0)
    var center = Unit.Points(0)
    var middle = Unit.Points(0)
    
    static var ZeroOffset: Offset {
        return Offset()
    }
}

struct Alignment {
    
    enum HorizontalAlignment : String {
        case Left = "left"
        case Center = "center"
        case Right = "right"
        case Fill = "fill"
    }
    
    enum VerticalAlignment : String {
        case Top = "top"
        case Middle = "middle"
        case Bottom = "bottom"
        case Fill = "fill"
    }
    
    var horizontal = HorizontalAlignment.Left
    var vertical = VerticalAlignment.Top
}

protocol BackgroundImage {
    
}

public class Block: NSObject {
    
    enum Action {
        case Deeplink(NSURL)
        case Website(NSURL)
        case Screen(String)
    }
    
    // Layout
    
    enum Position : String {
        case Stacked = "stacked"
        case Floating = "floating"
    }
    
    var identifier: String? = nil
    
    var position = Position.Stacked
    
    var height: Unit?
    var width: Unit?
    
    var alignment = Alignment()
    var offset = Offset.ZeroOffset

    // Appearance
    
    var backgroundColor = UIColor.clearColor()
    var borderColor = UIColor.clearColor()
    var borderRadius: CGFloat = 0
    var borderWidth: CGFloat = 0
    var opacity: Float = 1
    var inset = UIEdgeInsetsZero

    // BackgroundImage
    
    var backgroundImage: Image?
    var backgroundContentMode: ImageContentMode = .Original
    var backgroundScale: CGFloat = 1
    
    var action: Action?
}

class TextBlock: Block {
    var text: String?
    var textAlignment = Alignment(horizontal: .Left, vertical: .Top)
    var textColor = UIColor.blackColor()
    var textOffset = Offset.ZeroOffset // TextOffset was never used
    var font = UIFont.systemFontOfSize(12)
    
    var attributedText: NSAttributedString? {
        if let data = text?.dataUsingEncoding(NSUnicodeStringEncoding) {
            do {
                guard let attributedString = try? NSMutableAttributedString(data: data, options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType], documentAttributes: nil) else { return nil }
                attributedString.enumerateAttribute(NSFontAttributeName, inRange: NSMakeRange(0, attributedString.length), options: []) { (value, range, stop) in
                    guard let fontValue = value as? UIFont else {
                        return
                    }
                    let traits = fontValue.fontDescriptor().symbolicTraits
                    let descriptor = self.font.fontDescriptor().fontDescriptorWithSymbolicTraits(traits)
                    let newFont = UIFont(descriptor: descriptor, size: self.font.pointSize)
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
                
                if attributedString.length > 0 {
                    attributedString.replaceCharactersInRange(NSMakeRange(attributedString.length - 1, 1), withString: "")
                }
                
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

class ImageBock: Block {
    let image: Image?
    
    required init(image: Image?) {
        self.image = image
        super.init()
    }
}

class WebBlock: Block {
    let url: NSURL?
    var scrollable = false
    
    required init(url: NSURL?) {
        self.url = url
        super.init()
    }
}

class ButtonBlock: Block {

    enum State {
        case Normal
        case Highlighted
        case Selected
        case Disabled
    }
    
    struct Appearance {
        var titleColor: UIColor = UIColor.blackColor()
        var title: String?
        var titleAlignment: Alignment = Alignment(horizontal: .Center, vertical: .Middle)
        var titleOffset: Offset?
        var titleFont: UIFont = UIFont.systemFontOfSize(12)
        
        var backgroundColor: UIColor?
        var borderColor: UIColor?
        var borderRadius: CGFloat?
        var borderWidth: CGFloat?
        
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
    
    var appearences: [State: Appearance] = [:]
}

class Image {
    let size: CGSize
    let url: NSURL
    
    var aspectRatio: CGFloat {
        return size.width / size.height
    }
    
    init(size: CGSize, url: NSURL) {
        self.size = size
        self.url = url
    }
}

enum ImageContentMode : String {
    case Original = "original"
    case Stretch = "stretch"
    case Tile = "tile"
    case Fill = "fill"
    case Fit = "fit"
}
