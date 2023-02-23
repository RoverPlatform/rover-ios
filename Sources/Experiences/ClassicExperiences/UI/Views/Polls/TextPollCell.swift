// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of 
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import os
import UIKit

class TextPollCell: PollCell {
    override func configure(with block: ClassicBlock) {
        super.configure(with: block)
        
        guard let block = block as? ClassicTextPollBlock else {
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

extension ClassicTextPollBlock {
    func intrinsicHeight(blockWidth: CGFloat) -> CGFloat {
        let innerWidth = blockWidth - CGFloat(insets.left) - CGFloat(insets.right)

        let size = CGSize(width: innerWidth, height: CGFloat.greatestFiniteMagnitude)

        let questionAttributedText = self.textPoll.question.attributedText(forFormat: .plain)
        
        let questionHeight = questionAttributedText?.measuredHeight(with: size) ?? CGFloat(0)

        let borderHeight = CGFloat(textPoll.options.first?.border.width ?? 0) * 2
        
        let optionsHeightAndSpacing = self.textPoll.options.reduce(0) { result, option in
            result + CGFloat(option.height) + CGFloat(option.topMargin) + borderHeight
        }

        return CGFloat(optionsHeightAndSpacing) + questionHeight + CGFloat(insets.top + insets.bottom)
    }
}
