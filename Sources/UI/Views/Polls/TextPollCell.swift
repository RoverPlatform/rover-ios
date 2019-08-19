//
//  TextPollCell.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-06-19.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import os
import UIKit

class TextPollCell: PollCell {
    override func configure(with block: Block) {
        super.configure(with: block)
        
        guard let block = block as? TextPollBlock else {
            return
        }
        
        let poll = block.textPoll
        let options = poll.options
        verticalSpacing = CGFloat(options.first?.topMargin ?? 0)
        
        optionsList.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        options
            .map { option in
                TextPollOption(option: option) { [weak self] in
                    self?.optionSelected(option)
                }
            }
            .forEach { optionsList.addArrangedSubview($0) }
        
        questionText = poll.question
    } 
    
    // MARK: Results
    
    override func setResults(_ results: [PollCell.OptionResult], animated: Bool) {
        zip(results, optionsList.arrangedSubviews)
            .map { ($0, $1 as! TextPollOption) }
            .forEach { $1.setResult($0, animated: animated) }
    }
    
    override func clearResults() {
        optionsList.arrangedSubviews
            .map { $0 as! TextPollOption }
            .forEach { $0.clearResult() }
    }
}

// MARK: Measurement

extension TextPollBlock {
    func intrinsicHeight(blockWidth: CGFloat) -> CGFloat {
        let innerWidth = blockWidth - CGFloat(insets.left) - CGFloat(insets.right)

        let size = CGSize(width: innerWidth, height: CGFloat.greatestFiniteMagnitude)

        let questionAttributedText = self.textPoll.question.attributedText(forFormat: .plain)

        let questionHeight = questionAttributedText?.boundingRect(with: size, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height ?? CGFloat(0)

        let optionsHeightAndSpacing = self.textPoll.options.flatMap { option in
            return [option.height, option.topMargin]
        }.reduce(0) { (accumulator, addend) in
            return accumulator + addend
        }

        return CGFloat(optionsHeightAndSpacing) + questionHeight + CGFloat(insets.top + insets.bottom)
    }
}
