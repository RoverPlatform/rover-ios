// Copyright (c) 2020-present, Rover Labs, Inc. All rights reserved.
// You are hereby granted a non-exclusive, worldwide, royalty-free license to use,
// copy, modify, and distribute this software in source code or binary form for use
// in connection with the web services and APIs provided by Rover.
//
// This copyright notice shall be included in all copies or substantial portions of
// the software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import Combine
import SwiftUI
import os.log

internal struct ExperienceViewControllerHolder {
    weak var experienceViewController: RenderExperienceViewController?
    
    init(_ experience: RenderExperienceViewController?) {
        self.experienceViewController = experience
    }
}

internal struct ScreenViewControllerHolder {
    weak var screenViewController: ScreenViewController?
    
    init(_ experience: ScreenViewController?) {
        self.screenViewController = experience
    }
}

internal struct ExperienceKey: EnvironmentKey {
    static let defaultValue: ExperienceModel? = nil
}

internal struct ScreenKey: EnvironmentKey {
    static let defaultValue: Screen? = nil
}

internal struct StringTableKey: EnvironmentKey {
    static let defaultValue: StringTable = StringTable()
}

internal struct PresentActionKey: EnvironmentKey {
    static let defaultValue: (UIViewController) -> Void = {
        _ in
        rover_log(.error, "Present action was ignored.")
    }
}

internal struct ShowActionKey: EnvironmentKey {
    static let defaultValue: (UIViewController) -> Void = {
        _ in
        rover_log(.error, "Show action was ignored.")
    }
}

internal struct ScreenViewControllerKey: EnvironmentKey {
    static let defaultValue: ScreenViewControllerHolder? = nil
}

internal struct ExperienceViewControllerKey: EnvironmentKey {
    static let defaultValue: ExperienceViewControllerHolder? = nil
}

internal struct ExperienceManagerKey: EnvironmentKey {
    static let defaultValue: ExperienceManager? = nil
}

internal struct DataKey: EnvironmentKey {
    static let defaultValue: Any? = nil
}

internal struct URLParametersKey: EnvironmentKey {
    static let defaultValue: [String: String] = [:]
}

internal struct UserInfoKey: EnvironmentKey {
    static let defaultValue: [String: Any] = [:]
}

internal struct DeviceContextKey: EnvironmentKey {
    static let defaultValue: [String: Any] = [:]
}

internal struct AuthorizeKey: EnvironmentKey {
    static let defaultValue: Authorizers = Authorizers()
}

internal struct CollectionIndexKey: EnvironmentKey {
    static var defaultValue = 0
}

internal struct CarouselViewIDKey: EnvironmentKey {
    static var defaultValue: ViewID? = nil
}

internal struct CarouselPageNumberKey: EnvironmentKey {
    static var defaultValue: Int? = nil
}

internal struct CarouselCurrentPageKey: EnvironmentKey {
    static var defaultValue: Int? = nil
}

internal struct MediaDidFinishingPlayingKey: EnvironmentKey {
    static var defaultValue: PassthroughSubject<Void, Never> = PassthroughSubject<Void, Never>()
}

internal struct MediaCurrentTimeKey: EnvironmentKey {
    static var defaultValue: CurrentValueSubject<TimeInterval, Never> = CurrentValueSubject<TimeInterval, Never>(0.0)
}

internal struct MediaDurationKey: EnvironmentKey {
    static var defaultValue: CurrentValueSubject<TimeInterval, Never> = CurrentValueSubject<TimeInterval, Never>(0.0)
}

internal struct PresentWebsiteActionKey: EnvironmentKey {
    static let defaultValue: ((SafariURL) -> Void)? = nil
}

internal struct DismissActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

internal struct NavigationPathKey: EnvironmentKey {
    static var defaultValue: Binding<NavigationPath> = .constant(NavigationPath())
}

internal struct FullScreenModalKey: EnvironmentKey {
    static var defaultValue: ((ScreenDestination) -> Void)? = nil
}

internal struct ScreenModalKey: EnvironmentKey {
    static var defaultValue: ((ScreenDestination) -> Void)? = nil
}

internal extension EnvironmentValues {
    var experience: ExperienceModel? {
        get {
            self[ExperienceKey.self]
        }
        
        set {
            self[ExperienceKey.self] = newValue
        }
    }
    
    var screen: Screen? {
        get {
            self[ScreenKey.self]
        }
        
        set {
            self[ScreenKey.self] = newValue
        }
    }
    
    var stringTable: StringTable {
        get {
            self[StringTableKey.self]
        }
        
        set {
            self[StringTableKey.self] = newValue
        }
    }

    var presentAction: ((UIViewController) -> Void) {
        get {
            self[PresentActionKey.self]
        }
        
        set {
            self[PresentActionKey.self] = newValue
        }
    }

    var showAction: ((UIViewController) -> Void) {
        get {
            self[ShowActionKey.self]
        }
        
        set {
            self[ShowActionKey.self] = newValue
        }
    }

    var screenViewController: ScreenViewControllerHolder? {
        get {
            self[ScreenViewControllerKey.self]
        }
        
        set {
            self[ScreenViewControllerKey.self] = newValue
        }
    }
 
    var experienceViewController: ExperienceViewControllerHolder? {
        get {
            self[ExperienceViewControllerKey.self]
        }
        
        set {
            self[ExperienceViewControllerKey.self] = newValue
        }
    }
    
    var experienceManager: ExperienceManager? {
        get {
            self[ExperienceManagerKey.self]
        }
        
        set {
            self[ExperienceManagerKey.self] = newValue
        }
    }
    
    var data: Any? {
        get {
            return self[DataKey.self]
        }
        
        set {
            self[DataKey.self] = newValue
        }
    }
    
    var urlParameters: [String: String] {
        get {
            return self[URLParametersKey.self]
        }
        
        set {
            self[URLParametersKey.self] = newValue
        }
    }
    
    var userInfo: [String: Any] {
        get {
            return self[UserInfoKey.self]
        }
        
        set {
            self[UserInfoKey.self] = newValue
        }
    }
    
    var deviceContext: [String: Any] {
        get {
            return self[DeviceContextKey.self]
        }
        
        set {
            self[DeviceContextKey.self] = newValue
        }
    }
    
    var authorizers: Authorizers {
        get {
            return self[AuthorizeKey.self]
        }
        
        set {
            self[AuthorizeKey.self] = newValue
        }
    }
    
    var collectionIndex: Int {
        get {
            return self[CollectionIndexKey.self]
        }
        
        set {
            self[CollectionIndexKey.self] = newValue
        }
    }
    
    var mediaDidFinishPlaying: PassthroughSubject<Void, Never> {
        get {
            return self[MediaDidFinishingPlayingKey.self]
        }
        
        set {
            self[MediaDidFinishingPlayingKey.self] = newValue
        }
    }
    
    var mediaCurrentTime: CurrentValueSubject<TimeInterval, Never> {
        get {
            return self[MediaCurrentTimeKey.self]
        }
        
        set {
            self[MediaCurrentTimeKey.self] = newValue
        }
    }
    
    var mediaDuration: CurrentValueSubject<TimeInterval, Never> {
        get {
            return self[MediaDurationKey.self]
        }
        
        set {
            self[MediaDurationKey.self] = newValue
        }
    }
    
    var carouselViewID: ViewID? {
        get {
            return self[CarouselViewIDKey.self]
        }
        
        set {
            self[CarouselViewIDKey.self] = newValue
        }
    }
    
    var carouselPageNumber: Int? {
        get {
            return self[CarouselPageNumberKey.self]
        }
        
        set {
            self[CarouselPageNumberKey.self] = newValue
        }
        
    }
    
    var carouselCurrentPage: Int? {
        get {
            return self[CarouselCurrentPageKey.self]
        }
        
        set {
            self[CarouselCurrentPageKey.self] = newValue
        }
    }

    var presentWebsiteAction: ((SafariURL) -> Void)? {
        get {
            self[PresentWebsiteActionKey.self]
        }

        set {
            self[PresentWebsiteActionKey.self] = newValue
        }
    }

    var dismissAction: (() -> Void)? {
        get {
            self[DismissActionKey.self]
        }

        set {
            self[DismissActionKey.self] = newValue
        }
    }

    var navigationPath: Binding<NavigationPath> {
        get {
            return self[NavigationPathKey.self]
        }

        set {
            self[NavigationPathKey.self] = newValue
        }
    }

    var fullScreenModal: ((ScreenDestination) -> Void)? {
        get {
            return self[FullScreenModalKey.self]
        }

        set {
            self[FullScreenModalKey.self] = newValue
        }
    }

    var screenModal: ((ScreenDestination) -> Void)? {
        get {
            return self[ScreenModalKey.self]
        }

        set {
            self[ScreenModalKey.self] = newValue
        }
    }
}
