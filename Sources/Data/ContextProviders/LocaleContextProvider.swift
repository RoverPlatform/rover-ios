//
//  LocaleContextProvider.swift
//  RoverData
//
//  Created by Sean Rucker on 2017-08-14.
//  Copyright © 2017 Rover Labs Inc. All rights reserved.
//

import Foundation

class LocaleContextProvider: ContextProvider {
    let locale: Locale
    let logger: Logger
    
    var localeLanguage: String? {
        guard let languageCode = locale.languageCode else {
            logger.warn("Failed to capture locale language")
            return nil
        }
        
        return languageCode
    }
    
    var localeRegion: String? {
        guard let regionCode = locale.regionCode else {
            logger.warn("Failed to capture locale region")
            return nil
        }
        
        return regionCode
    }
    
    var localeScript: String? {
        return locale.scriptCode
    }
    
    init(locale: Locale, logger: Logger) {
        self.locale = locale
        self.logger = logger
    }

    func captureContext(_ context: Context) -> Context {
        var nextContext = context
        nextContext.localeLanguage = localeLanguage
        nextContext.localeRegion = localeRegion
        nextContext.localeScript = localeScript
        return nextContext
    }
}
