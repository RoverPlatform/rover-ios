//
//  Experience.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-08-01.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

extension ImagePollBlock {
    func pollId(containedBy experience: Experience) -> String {
        return "\(experience.id):\(self.id)"
    }
}

extension TextPollBlock {
    func pollId(containedBy experience: Experience) -> String {
        return "\(experience.id):\(self.id)"
    }
}
