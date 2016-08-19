//
//  TextBlockViewCell.swift
//  Pods
//
//  Created by Ata Namvari on 2016-05-06.
//
//

import UIKit

class TextBlockViewCell: BlockViewCell {
    
    var text: NSAttributedString? {
        didSet {
            setNeedsDisplay()
        }
    }
    var font = UIFont.systemFontOfSize(12)

    var textAlignment = Alignment()
    var textColor = UIColor.blackColor()
    var textOffset = Offset.ZeroOffset // offsets were never used
    
    override func drawRect(rect: CGRect) {
        guard let text = text else { return }
        
        /*
        let string = NSMutableAttributedString(attributedString: text)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment.horizontal.asNSTextAlignment
        paragraphStyle.paragraphSpacing = 0
        
        let attributes = [
            //NSFontAttributeName: font,
            NSForegroundColorAttributeName: textColor,
            NSParagraphStyleAttributeName: paragraphStyle
        ]
        
        
        
        string.addAttributes(attributes, range: NSMakeRange(0, string.length))
         */
        
        let insettedWidth = rect.width - inset.left - inset.right
        
        let textRect = text.boundingRectWithSize(CGSize(width: insettedWidth, height: CGFloat.max), options: .UsesLineFragmentOrigin, context: nil)
        
        var x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat
        
        // TODO: Offset
        
        switch textAlignment.vertical {
        case .Middle:
            x = rect.origin.x
            y = rect.origin.y + ((rect.height - (textRect.height ?? 0)) / 2)
            width = insettedWidth
            height = textRect.height ?? 0
        case .Bottom:
            x = rect.origin.x
            y = rect.origin.y + (rect.height - (textRect.height ?? 0))
            width = insettedWidth
            height = textRect.height ?? 0
        default:
            x = rect.origin.x
            y = rect.origin.y
            width = insettedWidth
            height = rect.height
        }
        
        x += inset.left
        y += inset.top
        //height += inset.top + inset.bottom
        
        let drawableRect = CGRect(x: x, y: y, width: width, height: height)
        
        text.drawInRect(drawableRect )
    }
}

extension Alignment.HorizontalAlignment {
    var asNSTextAlignment: NSTextAlignment {
        switch self {
        case .Center:
            return .Center
        case .Left:
            return .Left
        case .Right:
            return .Right
        case .Fill:
            return .Justified
        default:
            return .Natural
        }
    }
}