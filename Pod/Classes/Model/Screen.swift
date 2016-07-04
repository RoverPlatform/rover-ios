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
    
    init(rows: [Row]) {
        self.rows = rows
        
        super.init()
    }
}
