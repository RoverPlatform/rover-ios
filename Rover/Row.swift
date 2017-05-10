//
//  Row.swift
//  Pods
//
//  Created by Ata Namvari on 2016-05-02.
//
//

import Foundation

@objc
open class Row: NSObject {
    open var blocks: [Block]
    
    open var height: Unit?
    
    open let backgroundBlock = Block()
    
    open var customKeys = [String: String]()
    
    init(blocks: [Block]) {
        backgroundBlock.position = .Floating
        backgroundBlock.alignment = Alignment(horizontal: .Fill, vertical: .Fill)
        
        self.blocks = blocks + [backgroundBlock]
        
        super.init()
    }
    
}
