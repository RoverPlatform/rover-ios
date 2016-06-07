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

class Block: NSObject {
    
    // Layout
    
    enum Position : String {
        case Stacked = "stacked"
        case Floating = "floating"
    }
    
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

    
}

class TextBlock: Block {
    var text: String?
    var textAlignment = Alignment(horizontal: .Left, vertical: .Top)
    var textColor = UIColor.blackColor()
    var textOffset = Offset.ZeroOffset
    var font = UIFont.systemFontOfSize(12)
}

class ImageBock: Block {
    let image: Image?
    
    required init(image: Image?) {
        self.image = image
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
    
    enum Action {
        case Deeplink(NSURL)
        case Website(NSURL)
    }
    
    struct Appearance {
        var titleColor: UIColor?
        var title: String?
        var titleAlignment: Alignment?
        var titleOffset: Offset?
        var titleFont: UIFont?
        
        var backgroundColor: UIColor?
        var borderColor: UIColor?
        var borderRadius: CGFloat?
        var borderWidth: CGFloat?
    }
    
    var appearences: [State: Appearance] = [:]
    
    var action: Action?
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
