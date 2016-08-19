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

    enum NavBarButtons : String {
        case Close = "close"
        case Back = "back"
        case Both = "both"
        case None = "none"
    }
    
    var identifier: String?
    var title: String?
    var headerRows: [Row]?
    var rows:[Row]
    var footerRows: [Row]?
    var backgroundColor = UIColor.whiteColor()
    var titleColor: UIColor?
    var navBarColor: UIColor?
    var navItemColor: UIColor?
    var statusBarStyle: UIStatusBarStyle?
    var useDefaultNavBarStyle = true
    var navBarButtons = NavBarButtons.Both
    
    var backgroundImage: Image?
    var backgorundContentMode: ImageContentMode = .Original
    var backgroundScale: CGFloat = 1
    
    init(rows: [Row]) {
        self.rows = rows
        
        super.init()
    }
}
