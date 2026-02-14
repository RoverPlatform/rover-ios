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

import Foundation

enum ExperienceFixtures {
    /// A minimal v2 experience document (one screen, one text node, one scroll container).
    /// Source: https://testbench.rover.io/simple-screen/document.json
    static let simpleScreenJSON =
        """
        {"localizations":{},"urlParameters":[],"fonts":[],"userInfo":[],"segues":[],"data":{"models":[],"locked":false},"colors":[],"gradients":[],"appearance":"light","initialScreenID":"1875473F-3DE7-4922-975A-E35C54FA714F","authorizers":[],"screenIDs":["1875473F-3DE7-4922-975A-E35C54FA714F"],"nodes":[{"conversionTags":[],"id":"1875473F-3DE7-4922-975A-E35C54FA714F","isInitialScreen":true,"androidStatusBarStyle":"light","androidStatusBarBackgroundColor":{"referenceType":"custom","customColor":{"red":0.21568627450980393,"green":0,"alpha":1,"blue":0.7019607843137254}},"name":"Screen","backgroundColor":{"referenceType":"system","colorName":"systemBackground"},"childIDs":["CB43F0AA-0A39-4A0B-A912-C3FB4C61467E","F300BE81-CE0A-4718-9405-9267D57AD8A5"],"backButtonStyle":{"__caseName":"default","title":"Screen"},"__typeName":"Screen","statusBarStyle":"default"},{"isLocked":false,"textColor":{"referenceType":"system","colorName":"label"},"text":"Simple Screen","id":"CB43F0AA-0A39-4A0B-A912-C3FB4C61467E","textAlignment":"leading","childIDs":[],"font":{"emphases":[],"textStyle":"body","__caseName":"dynamic"},"__typeName":"Text"},{"disableScrollBar":false,"childIDs":[],"id":"F300BE81-CE0A-4718-9405-9267D57AD8A5","axis":"vertical","__typeName":"ScrollContainer","isLocked":false}]}
        """
        .data(using: .utf8)!

    /// A variant of the simple screen with different text content, for testing change detection.
    static let simpleScreenUpdatedJSON =
        """
        {"localizations":{},"urlParameters":[],"fonts":[],"userInfo":[],"segues":[],"data":{"models":[],"locked":false},"colors":[],"gradients":[],"appearance":"light","initialScreenID":"1875473F-3DE7-4922-975A-E35C54FA714F","authorizers":[],"screenIDs":["1875473F-3DE7-4922-975A-E35C54FA714F"],"nodes":[{"conversionTags":[],"id":"1875473F-3DE7-4922-975A-E35C54FA714F","isInitialScreen":true,"androidStatusBarStyle":"light","androidStatusBarBackgroundColor":{"referenceType":"custom","customColor":{"red":0.21568627450980393,"green":0,"alpha":1,"blue":0.7019607843137254}},"name":"Screen","backgroundColor":{"referenceType":"system","colorName":"systemBackground"},"childIDs":["CB43F0AA-0A39-4A0B-A912-C3FB4C61467E","F300BE81-CE0A-4718-9405-9267D57AD8A5"],"backButtonStyle":{"__caseName":"default","title":"Screen"},"__typeName":"Screen","statusBarStyle":"default"},{"isLocked":false,"textColor":{"referenceType":"system","colorName":"label"},"text":"Updated Screen","id":"CB43F0AA-0A39-4A0B-A912-C3FB4C61467E","textAlignment":"leading","childIDs":[],"font":{"emphases":[],"textStyle":"body","__caseName":"dynamic"},"__typeName":"Text"},{"disableScrollBar":false,"childIDs":[],"id":"F300BE81-CE0A-4718-9405-9267D57AD8A5","axis":"vertical","__typeName":"ScrollContainer","isLocked":false}]}
        """
        .data(using: .utf8)!

    /// CDN configuration for resolving asset URLs during v2 experience decoding.
    static let cdnConfigurationJSON =
        """
        {"imageLocation":"https://content.example.com/images/{name}","mediaLocation":"https://content.example.com/media/{name}","fontLocation":"https://content.example.com/fonts/{name}"}
        """
        .data(using: .utf8)!

    /// A minimal v1 classic experience for testing version routing.
    static let simpleClassicExperienceJSON =
        """
        {
            "id": "classic-exp-1",
            "name": "Simple Classic Experience",
            "homeScreenID": "screen-1",
            "screens": [{
                "id": "screen-1",
                "name": "Home Screen",
                "isStretchyHeaderEnabled": false,
                "rows": [],
                "background": {
                    "color": { "red": 255, "green": 255, "blue": 255, "alpha": 1.0 },
                    "contentMode": "ORIGINAL",
                    "scale": "X1"
                },
                "statusBar": {
                    "style": "DARK",
                    "color": { "red": 0, "green": 0, "blue": 0, "alpha": 1.0 }
                },
                "titleBar": {
                    "backgroundColor": { "red": 255, "green": 255, "blue": 255, "alpha": 1.0 },
                    "buttons": "CLOSE",
                    "buttonColor": { "red": 0, "green": 0, "blue": 0, "alpha": 1.0 },
                    "text": "Classic",
                    "textColor": { "red": 0, "green": 0, "blue": 0, "alpha": 1.0 },
                    "useDefaultStyle": true
                },
                "keys": {},
                "tags": []
            }],
            "keys": {},
            "tags": []
        }
        """
        .data(using: .utf8)!
}
