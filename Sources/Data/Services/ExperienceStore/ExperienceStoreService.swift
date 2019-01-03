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
        do {
            guard let path = experienceLocalURL(id: id) else {
                os_log("Not able to retrieve experience because local storage for it could not be determined.")
                return nil
            }
            let json = try Data.init(contentsOf: path)
            return try JSONDecoder.default.decode(Experience.self, from: json)
        } catch {
            os_log("Unable to retrieve experience locally: %s", log: .persistence, type: .error, error.localizedDescription)
            return nil
        }
    }
    
    func insert(experience: Experience) {
        do {
            let json =  try JSONEncoder.default.encode(experience)
            guard let path = experienceLocalURL(id: experience.id) else {
                os_log("Not able to store experience because local storage for it could not be determined.")
                return
            }
            try json.write(to: path, options: Data.WritingOptions.atomicWrite)
        } catch {
            os_log("Unable to store experience locally: %s", log: .persistence, type: .error, error.localizedDescription)
        }
    }
    
    private func experienceLocalURL(id: String) -> URL? {
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
        return experiencesDirectory
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
