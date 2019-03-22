//
//  Notification.Name.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-03-18.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

extension Notification.Name {
    /// This event is dispatched when a RoverViewController is presented.
    public static let RVExperiencePresented = Notification.Name("io.rover.ExperiencePresented")
    
    /// This event is dispatched when a RoverViewController is dismissed.
    public static let RVExperienceDismissed = Notification.Name("io.rover.ExperienceDismissed")
    
    /// This event is dispatched when the user finishes viewing a RoverViewController.
    public static let RVExperienceViewed = Notification.Name("io.rover.ExperienceViewed")
    
    /// This event is dispatched when a RoverViewController navigates to a new screen.
    public static let RVScreenPresented = Notification.Name("io.rover.ScreenPresented")
    
    /// This event is dispatched when a RoverViewController navigates away from a screen.
    public static let RVScreenDismissed = Notification.Name("io.rover.ScreenDismissed")
    
    /// This event is dispatched when the user finishes viewing a specific screen in RoverViewController.
    public static let RVScreenViewed = Notification.Name("io.rover.ScreenViewed")
    
    /// This event is dispatched when a block in a RoverViewController is tapped.
    public static let RVBlockTapped = Notification.Name("io.rover.BlockTapped")
}
