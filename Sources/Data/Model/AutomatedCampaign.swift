//
//  AutomatedCampaign.swift
//  RoverData
//
//  Created by Andrew Clunis on 2019-01-22.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import CoreData
import Foundation

public final class AutomatedCampaign: Campaign {
    @discardableResult
    public static func insert(into context: NSManagedObjectContext) -> AutomatedCampaign {
        return AutomatedCampaign(context: context)
    }
}
