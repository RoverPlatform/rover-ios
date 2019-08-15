//
//  PollCell.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-08-14.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import UIKit

protocol PollCellDelegate: AnyObject {
    func didCastVote(on textPollBlock: TextPollBlock, for option: TextPollBlock.TextPoll.Option)
    func didCastVote(on imagePollBlock: ImagePollBlock, for option: ImagePollBlock.ImagePoll.Option)
}

class PollCell: BlockCell {
    struct OptionResult {
        let selected: Bool
        let fraction: Double
        let percentage: Int
    }
    
    weak var delegate: PollCellDelegate?
    
    override var content: UIView? {
        return containerView
    }
    
    var isLoading = false {
        didSet {
            alpha = isLoading ? 0.5 : 1.0
//            isUserInteractionEnabled = !isLoading
        }
    }
    
    let containerView = UIStackView()
    let questionView = UITextView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        questionView.clipsToBounds = true
        questionView.isScrollEnabled = false
        questionView.backgroundColor = UIColor.clear
        questionView.isUserInteractionEnabled = false
        questionView.textContainer.lineFragmentPadding = 0
        questionView.textContainerInset = UIEdgeInsets.zero
        
        containerView.axis = .vertical
        containerView.addArrangedSubview(questionView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setResults(_ results: [PollCell.OptionResult], animated: Bool) {
        fatalError("Must be overridden")
    }
    
    func clearResults() {
        fatalError("Must be overridden")
    }
    
    func optionSelected(_ option: TextPollBlock.TextPoll.Option) {
        if let textPollBlock = block as? TextPollBlock {
            delegate?.didCastVote(on: textPollBlock, for: option)
        }
    }
    
    func optionSelected(_ option: ImagePollBlock.ImagePoll.Option) {
        if let imagePollBlock = block as? ImagePollBlock {
            delegate?.didCastVote(on: imagePollBlock, for: option)
        }
    }
}
