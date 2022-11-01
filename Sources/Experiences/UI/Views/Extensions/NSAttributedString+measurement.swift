//
//  NSAttributedString+measurement.swift
//  Rover
//
//  Created by Andrew Clunis on 2020-03-31.
//  Copyright © 2020 Rover Labs Inc. All rights reserved.
//

import Foundation
import UIKit

extension NSAttributedString {
    func measuredHeight(with size: CGSize) -> CGFloat {
        // Using NSAttributedString.boundingRect() does not handle certain characters and whitespace (basically, paragraph layout concerns) correctly/completely, and so often yields incorrect results.
        let container = NSTextContainer(size: size)
        container.lineFragmentPadding = 0
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(container)
        let textStorage = NSTextStorage(attributedString: self)
        textStorage.addLayoutManager(layoutManager)
        return CGFloat(ceilf(Float(layoutManager.usedRect(for: container).size.height)))
    }
}
