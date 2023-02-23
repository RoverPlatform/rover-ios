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

import UIKit

class ImagePollCell: PollCell {
    override func configure(with block: ClassicBlock) {
        super.configure(with: block)

        guard let block = block as? ClassicImagePollBlock else {
            return
        }
        
        let poll = block.imagePoll
        let options = poll.options
        guard options.count > 1 else {
            assertionFailure()
            return
        }
        
        verticalSpacing = CGFloat(options[0].topMargin)
        let horizontalSpacing = CGFloat(options[1].leftMargin)
        
        optionsList.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        options.tuples
            .map { pair -> (ImagePollOption, ImagePollOption) in
                let leftOption = ImagePollOption(option: pair.0) { [weak self] in
                    self?.optionSelected(pair.0)
                }
                
                let rightOption = ImagePollOption(option: pair.1) { [weak self] in
                    self?.optionSelected(pair.1)
                }
                
                return (leftOption, rightOption)
            }
            .map { pair -> UIStackView in
                let stackView = UIStackView()
                stackView.spacing = horizontalSpacing
                stackView.addArrangedSubview(pair.0)
                stackView.addArrangedSubview(pair.1)
                stackView.distribution = .fillEqually
                return stackView
            }
            .forEach { optionsList.addArrangedSubview($0) }
        
        questionText = poll.question
    }
    
    override func setResults(_ results: [PollCell.OptionResult], animated: Bool) {
        let options: [ImagePollOption] = optionsList.arrangedSubviews.reduce(into: []) { result, row in
            (row as! UIStackView).arrangedSubviews
                .map { $0 as! ImagePollOption }
                .forEach { result.append($0) }
        }
        
        zip(results, options)
            .forEach { $1.setResult($0, animated: animated) }
    }
    
    override func clearResults() {
        let options: [ImagePollOption] = optionsList.arrangedSubviews.reduce(into: []) { result, row in
            (row as! UIStackView).arrangedSubviews
                .map { $0 as! ImagePollOption }
                .forEach { result.append($0) }
        }
        
        options
            .forEach { $0.clearResult() }
    }
}

// MARK: Helpers

extension Array {
    /// Pair off a set of two items in sequence in the array.
    fileprivate var tuples: [(Element, Element)] {
        var optionPairs = [(Element, Element)]()
        for optionIndex in 0..<self.count {
            if optionIndex % 2 == 1 {
                optionPairs.append((self[optionIndex - 1], self[optionIndex]))
            }
        }
        return optionPairs
    }
}

// MARK: Measurement

extension ClassicImagePollBlock {
    func intrinisicHeight(blockWidth: CGFloat) -> CGFloat {
        let innerWidth = blockWidth - CGFloat(insets.left) - CGFloat(insets.right)
        
        let size = CGSize(width: innerWidth, height: CGFloat.greatestFiniteMagnitude)
        
        let questionAttributedText = self.imagePoll.question.attributedText(forFormat: .plain)
        
        let questionHeight = questionAttributedText?.measuredHeight(with: size) ?? CGFloat(0)
        
        let optionsHeightAndSpacing = self.imagePoll.options.tuples.map { (firstOption, secondOption) in
            let horizontalSpacing = CGFloat(secondOption.leftMargin)
            let optionTextHeight: CGFloat = 40
            let verticalSpacing = CGFloat(max(firstOption.topMargin, secondOption.topMargin))
            
            let optionImageHeight = (blockWidth - horizontalSpacing) / 2
            return verticalSpacing + optionTextHeight + optionImageHeight
        }.reduce(CGFloat(0)) { (accumulator, addend) in
            return accumulator + addend
        }
        
        return optionsHeightAndSpacing + questionHeight + CGFloat(insets.top + insets.bottom)
    }
}
