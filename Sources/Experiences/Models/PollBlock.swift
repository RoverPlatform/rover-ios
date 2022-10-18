//
//  PollBlock.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-06-17.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

public protocol PollBlock: Block {
    var poll: Poll { get }
    
    var id: String { get }
    
    func pollID(containedBy experienceID: String) -> String
}

public protocol Poll {
    var question: Text { get }
    
    var optionIDs: [String] { get }
    
    var pollOptions: [PollOption] { get }
}

public protocol PollOption {
    var id: String { get }
        
    var text: Text { get }
}

// MARK: ImagePollBlock

extension ImagePollBlock: PollBlock {
    public var poll: Poll {
        return imagePoll
    }
    
    public func pollID(containedBy experienceID: String) -> String {
        return "\(experienceID):\(self.id)"
    }
}

extension ImagePollBlock.ImagePoll: Poll {
    public var pollOptions: [PollOption] {
        return self.options
    }
    
    public var optionIDs: [String] {
        return self.options.map { $0.id }
    }
}

extension ImagePollBlock.ImagePoll.Option : PollOption {

}

// MARK: TextPollBlock

extension TextPollBlock: PollBlock {
    public var poll: Poll {
        return textPoll
    }
    
    public func pollID(containedBy experienceID: String) -> String {
        return "\(experienceID):\(self.id)"
    }
}

extension TextPollBlock.TextPoll: Poll {
    public var pollOptions: [PollOption] {
        return self.options
    }
    
    public var optionIDs: [String] {
        return self.options.map { $0.id }
    }
}

extension TextPollBlock.TextPoll.Option : PollOption {

}
