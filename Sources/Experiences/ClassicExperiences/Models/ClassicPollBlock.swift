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

import Foundation

public protocol ClassicPollBlock: ClassicBlock {
    var poll: Poll { get }
    
    var id: String { get }
    
    func pollID(containedBy experienceID: String) -> String
}

public protocol Poll {
    var question: ClassicText { get }
    
    var optionIDs: [String] { get }
    
    var pollOptions: [PollOption] { get }
}

public protocol PollOption {
    var id: String { get }
        
    var text: ClassicText { get }
}

// MARK: ImagePollBlock

extension ClassicImagePollBlock: ClassicPollBlock {
    public var poll: Poll {
        return imagePoll
    }
    
    public func pollID(containedBy experienceID: String) -> String {
        return "\(experienceID):\(self.id)"
    }
}

extension ClassicImagePollBlock.ImagePoll: Poll {
    public var pollOptions: [PollOption] {
        return self.options
    }
    
    public var optionIDs: [String] {
        return self.options.map { $0.id }
    }
}

extension ClassicImagePollBlock.ImagePoll.Option : PollOption {

}

// MARK: TextPollBlock

extension ClassicTextPollBlock: ClassicPollBlock {
    public var poll: Poll {
        return textPoll
    }
    
    public func pollID(containedBy experienceID: String) -> String {
        return "\(experienceID):\(self.id)"
    }
}

extension ClassicTextPollBlock.TextPoll: Poll {
    public var pollOptions: [PollOption] {
        return self.options
    }
    
    public var optionIDs: [String] {
        return self.options.map { $0.id }
    }
}

extension ClassicTextPollBlock.TextPoll.Option : PollOption {

}
