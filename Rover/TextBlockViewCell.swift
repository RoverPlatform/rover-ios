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
            textView.setNeedsDisplay()
        }
    }
    var font = UIFont.systemFont(ofSize: 12)

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
    
    var textColor = UIColor.black
    var textOffset = Offset.ZeroOffset // offsets were never used
    
    fileprivate let textView = TextView()
    
    override func commonInit() {
        super.commonInit()
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = UIColor.clear
        textView.isUserInteractionEnabled = false
        
        addSubview(textView)
        addConstraints([
            NSLayoutConstraint(item: textView, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: textView, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: textView, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: textView, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1, constant: 0)
            ])
    }
}

extension Alignment.HorizontalAlignment {
    var asNSTextAlignment: NSTextAlignment {
        switch self {
        case .Center:
            return .center
        case .Left:
            return .left
        case .Right:
            return .right
        case .Fill:
            return .justified
        }
    }
}

class TextView : UIView {
    
    var text: NSAttributedString?
    var textAlignment = Alignment()
    var inset = UIEdgeInsets.zero
    
//    convenience init() {
//        self.init(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
//    }
    
    override func draw(_ rect: CGRect) {
        guard let text = text else { return }
        
        let insettedWidth = rect.width - inset.left - inset.right
        
        let textRect = text.boundingRect(with: CGSize(width: insettedWidth, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil)
        
        var x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat
        
        // TODO: Offset
        
        switch textAlignment.vertical {
        case .Middle:
            x = rect.origin.x
            y = rect.origin.y + ((rect.height - (textRect.height)) / 2)
            width = insettedWidth
            height = textRect.height
        case .Bottom:
            x = rect.origin.x
            y = rect.origin.y + (rect.height - (textRect.height ))
            width = insettedWidth
            height = textRect.height
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
        
        text.draw(in: drawableRect )
    }
}
