//
//  FetchExperienceResult.swift
//  RoverExperiences
//
//  Created by Sean Rucker on 2018-05-04.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

public enum FetchExperienceResult {
    case error(error: Error?, isRetryable: Bool)
    case success(experience: Experience)
}
