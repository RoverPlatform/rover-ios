//
//  GameWidgetBundle.swift
//  GameWidget
//
//  Created by Andrew Marmion on 22/01/2026.
//

import WidgetKit
import SwiftUI
import RoverNBALiveActivities
import RoverNFLLiveActivities
import RoverNHLLiveActivities

@main
struct GameWidgetBundle: WidgetBundle {
    var body: some Widget {
        RoverNBALiveActivity()
        RoverNFLLiveActivity()
        RoverNHLLiveActivity()
    }
}
