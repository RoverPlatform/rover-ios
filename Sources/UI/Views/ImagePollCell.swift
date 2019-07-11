//
//  ImagePollCell.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-06-19.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit
import os

fileprivate let OPTION_TEXT_HEIGHT = 40

// MARK: Option View

class ImagePollOptionView: UIView {
    private let content = UIImageView()
    private let captionView = UILabel()
    
    private let image: Image
    
    init(
        image: Image,
        style: ImagePollBlock.OptionStyle
    ) {
        self.image = image
        super.init(frame: CGRect.zero)
        
        self.addSubview(content)
        self.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        self.clipsToBounds = true
        
        self.configureContent(content: content, withInsets: .zero)
        self.configureOpacity(opacity: style.opacity)
        self.configureBorder(border: style.border, constrainedByFrame: nil)
        // Configure image content view:
        
        // this is temporary to make things render simple 1:1.  probably different later.
        self.heightAnchor.constraint(equalTo: self.widthAnchor).isActive = true
        
        // TODO: set up caption view.
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Usage in XIB not supported.")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // configure image here since the laid out side matters.
        let frameAtStartTime = self.frame
        content.configureAsFilledImage(image: image) { [weak self] in
            return frameAtStartTime == self?.frame
        }
    }
}

// MARK: Cell


class ImagePollCell: BlockCell {
    /// a simple container view to the relatively complex layout of the text poll.
    let containerView = UIView()
    
    private var optionViews = [ImagePollOptionView]()
    
    override var content: UIView? {
        return containerView
    }
    
    var questionView: PollQuestionView?
    
    override func configure(with block: Block) {
        super.configure(with: block)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        questionView?.removeFromSuperview()
        self.optionViews.forEach { $0.removeFromSuperview() }
        
        guard let imagePollBlock = block as? ImagePollBlock else {
            return
        }
        
        questionView = PollQuestionView(questionText: imagePollBlock.question, style: imagePollBlock.questionStyle)
        containerView.addSubview(questionView!)
        questionView?.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
        questionView?.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
        questionView?.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
        self.optionViews = imagePollBlock.options.map { option in
            ImagePollOptionView(image: option.image, style: imagePollBlock.optionStyle)
        }
        
        // TODO: the 2x1 layout and the 2x2 layout.
        
        // merge them into tuples.
        
        // we render the poll options in two columns, regardless of device size.
        var optionViewPairs = optionViews.tuples
        
        for pairIndex in 0..<optionViewPairs.count {
            let (firstView, secondView) = optionViewPairs[pairIndex]
            containerView.addSubview(firstView)
            containerView.addSubview(secondView)
            if pairIndex == 0 {
                // first row
                firstView.topAnchor.constraint(equalTo: questionView!.bottomAnchor).isActive = true
                secondView.topAnchor.constraint(equalTo: questionView!.bottomAnchor).isActive = true
            } else {
                // subsequent rows stack on one another
                let (previousFirstView, previousSecondView) = optionViewPairs[pairIndex - 1]
                
                firstView.topAnchor.constraint(equalTo: previousFirstView.bottomAnchor, constant: CGFloat(imagePollBlock.optionStyle.verticalSpacing)).isActive = true
                secondView.topAnchor.constraint(equalTo: previousSecondView.bottomAnchor, constant: CGFloat(imagePollBlock.optionStyle.verticalSpacing)).isActive = true
            }

            
            firstView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
            firstView.trailingAnchor.constraint(equalTo: containerView.centerXAnchor, constant: -1 * CGFloat(imagePollBlock.optionStyle.horizontalSpacing) / 2).isActive = true
            
            secondView.leadingAnchor.constraint(equalTo: containerView.centerXAnchor, constant: CGFloat(imagePollBlock.optionStyle.horizontalSpacing) / 2).isActive = true
            secondView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
        }
    }
}

extension Array {
    var tuples: [(Element,Element)] {
        var optionPairs = [(Element,Element)]()
        for optionIndex in 0..<self.count {
            if optionIndex % 2 == 1 {
                optionPairs.append((self[optionIndex - 1], self[optionIndex]))
            }
        }
        return optionPairs
    }
}

extension UIImageView {
    func configureAsFilledImage(image: Image, checkStillMatches: @escaping () -> Bool) {
        // Reset any existing background image
        
        self.alpha = 0.0
        self.image = nil
    
        self.contentMode = .scaleAspectFill
        
        if let image = ImageStore.shared.image(for: image, filledInFrame: self.frame) {
            self.image = image
            self.alpha = 1.0
        } else {
            ImageStore.shared.fetchImage(for: image, filledInFrame: frame) { [weak self] image in
                let frame = self?.frame
                guard let image = image, checkStillMatches() else {
                    return
                }
                
                self?.image = image
                
                UIView.animate(withDuration: 0.25) {
                    self?.alpha = 1.0
                }
            }
        }
    }
}

extension ImagePollBlock {
    func intrinisicHeight(blockWidth: CGFloat) -> CGFloat {
        let innerWidth = blockWidth - CGFloat(insets.left) - CGFloat(insets.right)
        
        let size = CGSize(width: innerWidth, height: CGFloat.greatestFiniteMagnitude)
        
        let questionAttributedText = self.questionStyle.attributedText(for: self.question)
        
        let questionHeight = questionAttributedText?.boundingRect(with: size, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height ?? CGFloat(0)
            
        
        let horizontalSpacing = CGFloat(self.optionStyle.horizontalSpacing)
        let optionTextHeight = CGFloat(OPTION_TEXT_HEIGHT)
        let verticalSpacing = CGFloat(self.optionStyle.verticalSpacing)
        
        let optionImageHeight = (blockWidth - horizontalSpacing) / 2
        
        switch self.options.count {
        case 2:
            return verticalSpacing + optionTextHeight + optionImageHeight + questionHeight
        case 4:
            return 2 * (verticalSpacing + optionTextHeight + optionImageHeight) + questionHeight
        default:
            os_log("Unsupported number of image poll options.", log: .rover)
            return 0
        }
    }
}
