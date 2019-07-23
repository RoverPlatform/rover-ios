//
//  PollQuestionView.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-07-09.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import UIKit

class NewPollQuestionView: UIView {
    private let backgroundView = UIImageView()
    private let content = UITextView()
    
    init(
        questionText: Text
    ) {
        super.init(frame: .zero)
        self.addSubview(backgroundView)
        self.addSubview(content)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        self.clipsToBounds = true
        
        content.attributedText = questionText.attributedTextForPollQuestion
        content.isScrollEnabled = false
        content.backgroundColor = UIColor.clear
        content.isUserInteractionEnabled = false
        content.textContainer.lineFragmentPadding = 0
        content.textContainerInset = UIEdgeInsets.zero
        
        self.configureContent(content: content, withInsets: .zero)
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



// TODO: everything below doomed

class PollQuestionView: UIView {
    private let backgroundView = UIImageView()
    private let content = UITextView()
    
    init(
        questionText: String,
        style: QuestionStyle
    ) {
        super.init(frame: .zero)
        self.addSubview(backgroundView)
        self.addSubview(content)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        self.clipsToBounds = true
        
        content.attributedText = style.attributedText(for: questionText)
        content.isScrollEnabled = false
        content.backgroundColor = UIColor.clear
        content.isUserInteractionEnabled = false
        content.textContainer.lineFragmentPadding = 0
        content.textContainerInset = UIEdgeInsets.zero
        
        self.configureContent(content: content, withInsets: .zero)
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Usage in XIB not supported.")
    }
}

extension QuestionStyle {
    func attributedText(for text: String) -> NSAttributedString? {
        let text = Text(rawValue: text, alignment: .left, color: self.color, font: self.font)
        return text.attributedText(forFormat: .plain)
    }
}
