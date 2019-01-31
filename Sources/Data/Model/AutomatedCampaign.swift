//
//  AutomatedCampaign.swift
//  RoverData
//
//  Created by Andrew Clunis on 2019-01-22.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation
import CoreData

public final class AutomatedCampaign: Campaign {
    @discardableResult
    static public func insert(into context: NSManagedObjectContext) -> AutomatedCampaign {
        return AutomatedCampaign(context: context)
    }
}
