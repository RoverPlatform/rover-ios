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

import SwiftUI
import RoverData
import CoreData
import Foundation
import os.log

/// This object is responsible for updating the main app badge, and also offers API for obtaining (and observing) the badge count for a Hub tab.
@MainActor
public class RoverBadge: ObservableObject {
    private let persistentContainer: InboxPersistentContainer
    private let updateAppBadge: Bool

    /// Whether the Hub tab has unread items and should display a badge.
    ///
    /// If nil, then the count is 0 and the badge is not displayed.
    @Published public private(set) var newBadge: String? = nil

    init(persistentContainer: InboxPersistentContainer, updateAppBadge: Bool) {
        self.persistentContainer = persistentContainer
        self.updateAppBadge = updateAppBadge

        // Observe changes to unread posts in Core Data
        observeUnreadPostsChanges()
    }
    
    private var observerToken: NSObjectProtocol?

    deinit {
        if let token = observerToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    private func observeUnreadPostsChanges() {
        // Set up a NotificationCenter observer for Core Data changes
        observerToken = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: persistentContainer.viewContext,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateBadgeCount()
            }
        }
            
        // Initial badge count
        updateBadgeCount()
    }
    
    private func updateBadgeCount() {
        Task { @MainActor in
            let unreadCount = persistentContainer.getBadgeCount()
            
            self.newBadge = unreadCount > 0 ? String(unreadCount) : nil
            
            if self.updateAppBadge {
                os_log("Updating app badge number to %d", log: .hub, type: .info, unreadCount)
                UIApplication.shared.applicationIconBadgeNumber = unreadCount
            }
        }
    }
}

