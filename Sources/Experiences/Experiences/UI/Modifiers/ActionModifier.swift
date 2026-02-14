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

struct ActionModifier: ViewModifier {
    var layer: Layer

    @Environment(\.experience) private var experience
    @Environment(\.screen) private var screen
    @Environment(\.presentAction) private var presentAction
    @Environment(\.showAction) private var showAction
    @Environment(\.presentWebsiteAction) private var presentWebsiteAction
    @Environment(\.dismissAction) private var dismissAction
    @Environment(\.experienceViewController) private var experienceViewControllerHolder
    @Environment(\.screenViewController) private var screenViewControllerHolder
    @Environment(\.data) private var data
    @Environment(\.urlParameters) private var urlParameters
    @Environment(\.userInfo) private var userInfo
    @Environment(\.deviceContext) private var deviceContext
    @Environment(\.authorizers) private var authorizers
    @Environment(\.navigationPath) private var path
    @Environment(\.screenModal) private var screenModal
    @Environment(\.fullScreenModal) private var fullScreenModal

    @ViewBuilder
    func body(content: Content) -> some View {
        if let action = layer.action {
            Button {
                // If we don't have an experienceViewControllerHolder and screenViewControllerHolder we are in a SwiftUI context
                if (experienceViewControllerHolder == nil && screenViewControllerHolder == nil),
                    let experience,
                    let screen
                {
                    action.handle(
                        experience: experience,
                        node: layer,
                        screen: screen,
                        data: data,
                        urlParameters: urlParameters,
                        userInfo: userInfo,
                        deviceContext: deviceContext,
                        authorizers: authorizers,
                        path: path,
                        presentWebsiteAction: presentWebsiteAction,
                        dismissAction: dismissAction,
                        fullScreenModal: fullScreenModal,
                        screenModal: screenModal
                    )
                } else {
                    // NB: Being very careful here to not capture the view controllers from the Environment in this button callback closure, otherwise you get a hard-to-trace retain cycle through the SwiftUI environment.
                    if let experience = experience,
                        let screen = screen,
                        let experienceViewController = experienceViewControllerHolder?.experienceViewController,
                        let screenViewController = screenViewControllerHolder?.screenViewController
                    {
                        action.handle(
                            experience: experience,
                            node: layer,
                            screen: screen,
                            data: data,
                            urlParameters: urlParameters,
                            userInfo: userInfo,
                            deviceContext: deviceContext,
                            authorizers: authorizers,
                            experienceViewController: experienceViewController,
                            screenViewController: screenViewController
                        )
                    }
                }
            } label: {
                content
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            content
        }
    }
}
