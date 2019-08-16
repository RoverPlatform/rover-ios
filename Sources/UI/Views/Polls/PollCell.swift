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

class PollCellQuestion: UIView {
    let textView = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        textView.numberOfLines = 0
        
        
//        textView.clipsToBounds = true
//        textView.isScrollEnabled = false
//        textView.backgroundColor = UIColor.clear
//        textView.isUserInteractionEnabled = false
//        textView.textContainer.lineFragmentPadding = 0
//        textView.textContainerInset = UIEdgeInsets.zero
        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)
        NSLayoutConstraint.activate([
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
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
    let question = PollCellQuestion()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        containerView.axis = .vertical
        containerView.addArrangedSubview(question)
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
