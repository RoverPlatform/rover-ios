//
//  Screen.swift
//  Pods
//
//  Created by Ata Namvari on 2016-05-02.
//
//

import Foundation

@objc
open class Screen: NSObject {

    public enum NavBarButtons : String {
        case Close = "close"
        case Back = "back"
        case Both = "both"
        case None = "none"
    }
    
    open var identifier: String?
    open var title: String?
    open var headerRows: [Row]?
    open var rows:[Row]
    open var footerRows: [Row]?
    open var backgroundColor = UIColor.white
    open var titleColor: UIColor?
    open var navBarColor: UIColor?
    open var navItemColor: UIColor?
    open var statusBarStyle: UIStatusBarStyle?
    open var useDefaultNavBarStyle = true
    open var navBarButtons = NavBarButtons.Both
    
    open var backgroundImage: Image?
    open var backgorundContentMode: ImageContentMode = .Original
    open var backgroundScale: CGFloat = 1
    
    init(rows: [Row]) {
        self.rows = rows
        
        super.init()
    }
}
