//
//  Experience.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-08-01.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

extension ImagePollBlock {
    func pollID(containedBy experienceID: String) -> String {
        return "\(experienceID):\(self.id)"
    }
}

extension TextPollBlock {
    func pollID(containedBy experienceID: String) -> String {
        return "\(experienceID):\(self.id)"
    }
}
