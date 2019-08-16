//
//  PollBlock.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-06-17.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

protocol PollBlock {
    var poll: Poll { get }
    
    var id: String { get }
    
    func pollID(containedBy experienceID: String) -> String
}

protocol Poll {
    var optionIDs: [String] { get }
    
    var pollOptions: [PollOption] { get }
}

protocol PollOption {
    var id: String { get }
}

// MARK: ImagePollBlock

extension ImagePollBlock: PollBlock {
    var poll: Poll {
        imagePoll
    }
    
    func pollID(containedBy experienceID: String) -> String {
        return "\(experienceID):\(self.id)"
    }
}

extension ImagePollBlock.ImagePoll: Poll {
    var pollOptions: [PollOption] {
        return self.options
    }
    
    var optionIDs: [String] {
        return self.options.map { $0.id }
    }
}

extension ImagePollBlock.ImagePoll.Option : PollOption {

}

// MARK: TextPollBlock

extension TextPollBlock: PollBlock {
    var poll: Poll {
        textPoll
    }
    
    func pollID(containedBy experienceID: String) -> String {
        return "\(experienceID):\(self.id)"
    }
}

extension TextPollBlock.TextPoll: Poll {
    var pollOptions: [PollOption] {
        return self.options
    }
    
    var optionIDs: [String] {
        return self.options.map { $0.id }
    }
}

extension TextPollBlock.TextPoll.Option : PollOption {

}
