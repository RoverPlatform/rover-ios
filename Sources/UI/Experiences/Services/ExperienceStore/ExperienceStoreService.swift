//
//  ExperienceStoreService.swift
//  RoverUI
//
//  Created by Sean Rucker on 2018-05-03.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import os

class ExperienceStoreService: ExperienceStore {
    func get(byID id: String) -> Experience? {
        return nil
    }
    
    func insert(experience: Experience) {
        // ANDREW START HERE run experience through codable and store it on disk at experiencePath
    }
    
    private func experiencePath(id: String) -> String? {
        var experiencesDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        experiencesDirectory.appendPathComponent("io.rover")
        experiencesDirectory.appendPathComponent("experiences")

        if !FileManager.default.directoryExists(at: experiencesDirectory) {
            do {
                try FileManager.default.createDirectory(at: experiencesDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                os_log("Experiences storage directory did not exist, and unable to create it.  Unable to store experiences.  Reason: %s", log: .persistence, type: .error, error.localizedDescription)
                return nil
            }
        }
        
        experiencesDirectory.appendPathComponent(id)
        experiencesDirectory.appendPathExtension("json")
        return experiencesDirectory.path
    }
}

extension FileManager {
    func directoryExists(at: URL) -> Bool {
        var returnBool : ObjCBool = false
        if self.fileExists(atPath: at.path, isDirectory: &returnBool) {
            return returnBool.boolValue
        } else {
            return false
        }
    }
}
