//
//  UserInfoContextProvider.swift
//  RoverData
//
//  Created by Sean Rucker on 2018-02-08.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

struct UserInfoContextProvider: ContextProvider {
    let userInfo: UserInfo
    
    func captureContext(_ context: Context) -> Context {
        var nextContext = context
        nextContext.userInfo = userInfo.current()
        return nextContext
    }
}
