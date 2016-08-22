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
            textView.text = text
            setNeedsDisplay()
        }
    }
    var font = UIFont.systemFontOfSize(12)

    var textAlignment = Alignment() {
        didSet {
            textView.textAlignment = textAlignment
        }
    }
    
    override var inset: UIEdgeInsets {
        didSet {
            textView.inset = inset
        }
    }
    
    var textColor = UIColor.blackColor()
    var textOffset = Offset.ZeroOffset // offsets were never used
    
    private let textView = TextView()
    
    override func commonInit() {
        super.commonInit()
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = UIColor.clearColor()
        textView.userInteractionEnabled = false
        
        addSubview(textView)
        addConstraints([
            NSLayoutConstraint(item: textView, attribute: .Top, relatedBy: .Equal, toItem: self, attribute: .Top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: textView, attribute: .Leading, relatedBy: .Equal, toItem: self, attribute: .Leading, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: textView, attribute: .Bottom, relatedBy: .Equal, toItem: self, attribute: .Bottom, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: textView, attribute: .Trailing, relatedBy: .Equal, toItem: self, attribute: .Trailing, multiplier: 1, constant: 0)
            ])
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

class TextView : UIView {
    
    var text: NSAttributedString?
    var textAlignment = Alignment()
    var inset = UIEdgeInsetsZero
    
//    convenience init() {
//        self.init(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
//    }
    
    override func drawRect(rect: CGRect) {
        guard let text = text else { return }
        
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
