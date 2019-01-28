//
//  Data.NSManagedObjectContext.swift
//  RoverData
//
//  Created by Andrew Clunis on 2019-01-02.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import CoreData
import os

extension NSManagedObjectContext {
    func saveOrRollback() {
        do {
            try self.save()
        } catch {
            if let multipleErrors = (error as NSError).userInfo[NSDetailedErrorsKey] as? [Error] {
                multipleErrors.forEach {
                    os_log("Unable to save context. Reason: %s", log: .persistence, type: .error, $0.localizedDescription)
                }
            } else {
                os_log("Unable to save context. Reason: %s", log: .persistence, type: .error, error.localizedDescription)
            }

            self.rollback()
        }
    }
}
