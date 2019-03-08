//
//  DispatcherService.swift
//  RoverCampaignsFoundation
//
//  Created by Sean Rucker on 2018-05-10.
//  Copyright © 2018 Rover Labs Inc. All rights reserved.
//

import Foundation
import os.log

class DispatcherService: OperationQueue, Dispatcher {
    func dispatch(_ action: Action, completionHandler: (() -> Void)?) {
        let produceHandler: BlockObserver.ProduceHandler = { [weak self] in
            self?.addOperation($1)
        }
        
        let finishHandler: BlockObserver.FinishHandler = { _, _  in
            completionHandler?()
        }
        
        let observer = BlockObserver(produceHandler: produceHandler, finishHandler: finishHandler)
        action.addObserver(observer: observer)
        
        super.addOperation(action)
    }
}
