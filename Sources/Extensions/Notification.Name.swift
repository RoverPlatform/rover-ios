//
//  Notification.Name.swift
//  Rover
//
//  Created by Andrew Clunis on 2019-03-18.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import Foundation

enum RoverNotification: CaseIterable {
    /// This event is dispatched when a RoverViewController is presented.
    case experiencePresented
    
    /// This event is dispatched when a RoverViewController is dismissed.
    case experienceDismissed
    
    /// This event is dispatched when the user finishes viewing a RoverViewController.
    case experienceViewed
    
    /// This event is dispatched when a RoverViewController navigates to a new screen.
    case screenPresented
    
    /// This event is dispatched when a RoverViewController navigates away from a screen.
    case screenDismissed
    
    /// This event is dispatched when the user finishes viewing a specific screen in RoverViewController.
    case screenViewed
    
    /// This event is dispatched when a block in a RoverViewController is tapped.
    case blockTapped
    
    public var action: String {
        switch self {
        case .experiencePresented:
            return "io.rover.ExperiencePresented"
        case .experienceDismissed:
            return "io.rover.ExperienceDismissed"
        case .experienceViewed:
            return "io.rover.ExperienceViewed"
        case .screenPresented:
            return "io.rover.ScreenPresented"
        case .screenViewed:
            return "io.rover.ScreenViewed"
        case .screenDismissed:
            return "io.rover.ScreenDismissed"
        case .blockTapped:
            return "io.rover.BlockTapped"
        }
    }
    
    public var notificationName: Notification.Name {
        return Notification.Name(self.action)
    }
}

extension Notification.Name {
    init(roverNotification: RoverNotification) {
        self.init(roverNotification.action)
    }
}

//extension Notification.Name {
//    /// This event is dispatched when a RoverViewController is presented.
//    public static let RVExperiencePresented = Notification.Name("io.rover.ExperiencePresented")
//
//    /// This event is dispatched when a RoverViewController is dismissed.
//    public static let RVExperienceDismissed = Notification.Name("io.rover.ExperienceDismissed")
//
//    /// This event is dispatched when the user finishes viewing a RoverViewController.
//    public static let RVExperienceViewed = Notification.Name("io.rover.ExperienceViewed")
//
//    /// This event is dispatched when a RoverViewController navigates to a new screen.
//    public static let RVScreenPresented = Notification.Name("io.rover.ScreenPresented")
//
//    /// This event is dispatched when a RoverViewController navigates away from a screen.
//    public static let RVScreenDismissed = Notification.Name("io.rover.ScreenDismissed")
//
//    /// This event is dispatched when the user finishes viewing a specific screen in RoverViewController.
//    public static let RVScreenViewed = Notification.Name("io.rover.ScreenViewed")
//
//    /// This event is dispatched when a block in a RoverViewController is tapped.
//    public static let RVBlockTapped = Notification.Name("io.rover.BlockTapped")
//}
