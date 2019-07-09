//
//  ImagePollCell.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-06-19.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit

// MARK: Option View

class ImagePollOptionView: UIView {
    private let content = UIImageView()
    private let captionView = UILabel()
    
    init(
        image: Image,
        style: ImagePollBlock.OptionStyle
    ) {
        super.init(frame: CGRect.zero)
        self.addSubview(content)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure image content view:
        content.configureAsImage(image: image) {
            // Option views are not recycled in the containing CollectionView driving the Rover experience, so we don't need to worry about checking that the background image loading callback is associated with a "stale" option.
            return true
        }
        self.configureContent(content: content, withInsets: .zero)
        self.configureOpacity(opacity: style.opacity)
        self.configureBorder(border: style.border, constrainedByFrame: nil)
        
        // this is temporary to make things render simple 1:1.  probably different later.
        self.heightAnchor.constraint(equalTo: self.widthAnchor).isActive = true
        
        // TODO: set up caption view.
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Usage in XIB not supported.")
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
        
        for optionViewIndex in 0..<optionViews.count {
            let currentOptionView = self.optionViews[optionViewIndex]
            containerView.addSubview(currentOptionView)
            if optionViewIndex > 0 {
                let previousOptionView = self.optionViews[optionViewIndex - 1]
                currentOptionView.topAnchor.constraint(equalTo: previousOptionView.bottomAnchor, constant: CGFloat(imagePollBlock.optionStyle.verticalSpacing)).isActive = true
            } else {
                currentOptionView.topAnchor.constraint(equalTo: questionView!.bottomAnchor).isActive = true
            }
            currentOptionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
            currentOptionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
        }
    }
}
