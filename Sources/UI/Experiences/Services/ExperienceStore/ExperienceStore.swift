//
//  ExperienceStore.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-05-04.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.

import Foundation

public protocol ExperienceStore {
//    func experience(for identifier: ExperienceIdentifier) -> Experience?
//    func fetchExperience(for identifier: ExperienceIdentifier, completionHandler: ((FetchExperienceResult) -> Void)?)
    
    // NOT using ExperienceIdentifier, because the campaign lookup concern will soon be local.
    
    func get(byID id: String) -> Experience?
    
    func insert(experience: Experience)
}

// MARK: ExperienceIdentifier

public enum ExperienceIdentifier: Equatable, Hashable {
    case campaignID(id: String)
    case campaignURL(url: URL)
    case experienceID(id: String)
}
