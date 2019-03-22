//
//  SessionState.swift
//  Rover
//
//  Created by Sean Rucker on 2019-03-22.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

enum SessionState {
    struct Entry {
        let session: Session
        
        var isUnregistered = false
        
        init(session: Session) {
            self.session = session
        }
    }
    
    static var shared = [String: Entry]()
}
