//
//  Screen.swift
//  Pods
//
//  Created by Ata Namvari on 2016-05-02.
//
//

import Foundation

@objc
public class Screen: NSObject {

    public enum NavBarButtons : String {
        case Close = "close"
        case Back = "back"
        case Both = "both"
        case None = "none"
    }
    
    public var identifier: String?
    public var title: String?
    public var headerRows: [Row]?
    public var rows:[Row]
    public var footerRows: [Row]?
    public var backgroundColor = UIColor.whiteColor()
    public var titleColor: UIColor?
    public var navBarColor: UIColor?
    public var navItemColor: UIColor?
    public var statusBarStyle: UIStatusBarStyle?
    public var useDefaultNavBarStyle = true
    public var navBarButtons = NavBarButtons.Both
    
    public var backgroundImage: Image?
    public var backgorundContentMode: ImageContentMode = .Original
    public var backgroundScale: CGFloat = 1
    
    init(rows: [Row]) {
        self.rows = rows
        
        super.init()
    }
}
