//
//  PollCellAnswerDelegate.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-08-14.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

protocol PollCellAnswerDelegate: AnyObject {
    func castVote(on imagePollBlock: ImagePollBlock, for option: ImagePollBlock.ImagePoll.Option)
    
    func castVote(on textPollBlock: TextPollBlock, for option: TextPollBlock.TextPoll.Option)
}

