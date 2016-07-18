//
//  TextBlockViewCell.swift
//  Pods
//
//  Created by Ata Namvari on 2016-05-06.
//
//

import UIKit

class TextBlockViewCell: UICollectionViewCell {
    
    var text: String?
    var font = UIFont.systemFontOfSize(12)

    var textAlignment = Alignment()
    var textColor = UIColor.blackColor()
    var textOffset = Offset.ZeroOffset
    
    override func drawRect(rect: CGRect) {
        let string = text as? NSString
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment.horizontal.asNSTextAlignment
        
        let attributes = [
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: textColor,
            NSParagraphStyleAttributeName: paragraphStyle
        ]
        
        let textRect = string?.boundingRectWithSize(CGSize(width: rect.width, height: CGFloat.max), options: .UsesLineFragmentOrigin, attributes: attributes, context: nil)
        
        var x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat
        
        // TODO: Offset
        
        switch textAlignment.vertical {
        case .Middle:
            x = rect.origin.x
            y = rect.origin.y + ((rect.height - (textRect?.height ?? 0)) / 2)
            width = rect.width
            height = textRect?.height ?? 0
        case .Bottom:
            x = rect.origin.x
            y = rect.origin.y + (rect.height - (textRect?.height ?? 0))
            width = rect.width
            height = textRect?.height ?? 0
        default:
            x = rect.origin.x
            y = rect.origin.y
            width = rect.width
            height = rect.height
        }
        
        let drawableRect = CGRect(x: x, y: y, width: width, height: height)
        
        string?.drawInRect(drawableRect, withAttributes: attributes)
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