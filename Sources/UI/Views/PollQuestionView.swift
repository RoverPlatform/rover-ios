//
//  PollQuestionView.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-07-09.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import UIKit

class PollQuestionView: UITextView {
    init(
        questionText: Text
    ) {
        super.init(frame: .zero, textContainer: nil)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.translatesAutoresizingMaskIntoConstraints = false
        self.clipsToBounds = true
        
        self.attributedText = questionText.attributedTextForPollQuestion
        self.isScrollEnabled = false
        self.backgroundColor = UIColor.clear
        self.isUserInteractionEnabled = false
        self.textContainer.lineFragmentPadding = 0
        self.textContainerInset = UIEdgeInsets.zero
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Usage in XIB not supported.")
    }
}

extension Text {
    fileprivate var attributedTextForPollQuestion: NSAttributedString? {
        return self.attributedText(forFormat: .plain)
    }
}
