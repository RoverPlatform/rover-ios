//
//  ExperienceIdentifier.swift
//  RoverExperiences
//
//  Created by Sean Rucker on 2018-05-04.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation

public enum ExperienceIdentifier: Equatable, Hashable {
    case campaignID(id: ID)
    case campaignURL(url: URL)
    case experienceID(id: ID)
}
