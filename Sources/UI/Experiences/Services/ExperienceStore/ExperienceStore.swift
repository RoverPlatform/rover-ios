//
//  ExperienceStore.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-05-04.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public protocol ExperienceStore {
    func experience(for identifier: ExperienceIdentifier) -> Experience?
    func fetchExperience(for identifier: ExperienceIdentifier, completionHandler: ((FetchExperienceResult) -> Void)?)
}
