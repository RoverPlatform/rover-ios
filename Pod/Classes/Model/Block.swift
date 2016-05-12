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
    var left: Unit?
    var right: Unit?
    var top: Unit?
    var bottom: Unit?
    var center: Unit?
    var middle: Unit?
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
    
    var horizontal: HorizontalAlignment?
    var vertical: VerticalAlignment?
}

class Block: NSObject {
    
    enum Position : String {
        case Stacked = "stacked"
        case Floating = "floating"
    }
    
    var position: Position?
    
    var height: Unit?
    var width: Unit?
    
    var alignment: Alignment?
    var offset: Offset?

    var backgroundColor: UIColor?
    var borderColor: UIColor?
    var borderRadius: CGFloat?
    var borderWidth: CGFloat?
    
    override init() {
        super.init()
    }
    
}

class TextBlock: Block {
    var text: String?
}

class ImageBock: Block {
    
}

class ButtonBlock: Block {
    var titleColor: UIColor?
    var title: String?
    var titleAlignment: Alignment?
    var titleOffset: Offset?
}
