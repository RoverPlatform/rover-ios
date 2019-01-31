//
//  ScheduledCampaign.swift
//  RoverData
//
//  Created by Andrew Clunis on 2019-01-22.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import CoreData
import Foundation

public final class ScheduledCampaign: Campaign {
    @discardableResult
    public static func insert(into context: NSManagedObjectContext) -> ScheduledCampaign {
        return ScheduledCampaign(context: context)
    }
}
