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

import RoverData
import RoverFoundation
import SafariServices
import SwiftUI
import UIKit
import os.log

extension ExperienceAction {
    func handle(
        experience: ExperienceModel, node: Node, screen: Screen, data: Any?, urlParameters: [String: String],
        userInfo: [String: Any], deviceContext: [String: Any], authorizers: Authorizers,
        experienceViewController: RenderExperienceViewController, screenViewController: ScreenViewController
    ) {
        let experienceManager = Rover.shared.resolve(ExperienceManager.self)!

        experienceManager.conversionsTracker.track(
            tags: conversionTags,
            data: data,
            urlParameters: urlParameters,
            userInfo: userInfo,
            deviceContext: deviceContext)

        let eventQueue = experienceManager.eventQueue
        let event = EventInfo.experienceButtonTappedEvent(
            with: urlParameters["campaignID"],
            experience: experience,
            screen: screen,
            node: node
        )
        eventQueue.addEvent(event)

        let campaignID = urlParameters["campaignID"]

        switch self {
        case .performSegue:
            let segue = experience.segues.filter {
                $0.source.id == node.id
            }.first

            guard let segue = segue else {
                rover_log(.error, "Unable to find segue with source id: %@", screen.id)
                return
            }

            switch segue.style {
            case .push:
                let viewController = experienceManager.screenViewController(
                    experience, segue.destination, data, urlParameters, userInfo, authorizers)
                screenViewController.show(viewController, sender: screenViewController)

            case .modal(let presentationStyle):
                let viewController = experienceManager.navBarViewController(
                    experience, segue.destination, data, urlParameters, userInfo, authorizers)

                switch presentationStyle {
                case .fullScreen:
                    viewController.modalPresentationStyle = .fullScreen

                case .sheet:
                    viewController.modalPresentationStyle = .pageSheet
                }

                screenViewController.present(viewController, animated: true)
            }
        case .openURL(let url, let dismissExperience, _):
            guard
                let resolvedURLString = url.evaluatingExpressions(
                    data: data, urlParameters: urlParameters, userInfo: userInfo, deviceContext: deviceContext),
                let resolvedURL = URL(string: resolvedURLString)
            else {
                rover_log(.error, "Unable to resolve URL: %@", url)
                return
            }

            if dismissExperience {
                performDismissExperience(experienceViewController: experienceViewController) {
                    UIApplication.shared.open(resolvedURL) { success in
                        if !success {
                            rover_log(.error, "Unable to present unhandled URL: %@", resolvedURL.absoluteString)
                        }
                    }
                }
            } else {
                UIApplication.shared.open(resolvedURL) { success in
                    if !success {
                        rover_log(.error, "Unable to present unhandled URL: %@", resolvedURL.absoluteString)
                    }
                }
            }
        case .presentWebsite(let url, _):
            guard
                let resolvedURLString = url.evaluatingExpressions(
                    data: data, urlParameters: urlParameters, userInfo: userInfo, deviceContext: deviceContext),
                var resolvedURLComponents = URLComponents(string: resolvedURLString)
            else {
                rover_log(.error, "Unable to resolve URL: %@", url)
                return
            }
            if !(["https", "http"].contains(resolvedURLComponents.scheme)) {
                resolvedURLComponents.scheme = "https"
            }
            guard let resolvedURL = resolvedURLComponents.url else {
                rover_log(.error, "Unable to resolve URL: %@", url)
                return
            }

            let viewController = SFSafariViewController(url: resolvedURL)
            screenViewController.present(viewController, animated: true)
        case .close:
            screenViewController.dismiss(animated: true)
        case .custom(let dismissExperience, _):
            func behaviour() {
                if let callback = experienceManager.registeredCustomActionCallback {

                    callback(
                        CustomActionActivationEvent(
                            nodeId: node.id,
                            nodeID: node.id,
                            nodeName: node.name,
                            nodeProperties: node.metadata?.properties ?? [:],
                            nodeTags: node.metadata?.tags ?? [],
                            screenId: screen.id,
                            screenID: screen.id,
                            screenName: screen.name,
                            screenProperties: screen.metadata?.properties ?? [:],
                            screenTags: screen.metadata?.tags ?? [],
                            experienceId: experience.id,
                            experienceID: experience.id,
                            experienceName: experience.name,
                            experienceUrl: experience.sourceUrl,
                            campaignId: campaignID,
                            campaignID: campaignID,
                            data: data,
                            urlParameters: urlParameters,
                            userInfo: userInfo,
                            viewController: screenViewController
                        )
                    )
                }
            }
            if dismissExperience {
                performDismissExperience(experienceViewController: experienceViewController) {
                    behaviour()
                }
            } else {
                behaviour()
            }
        }

        experienceManager.registeredButtonTappedCallback?(
            ButtonTappedEvent(
                nodeID: node.id,
                nodeName: node.name,
                nodeProperties: node.metadata?.properties ?? [:],
                nodeTags: node.metadata?.tags ?? [],
                screenID: screen.id,
                screenName: screen.name,
                screenProperties: screen.metadata?.properties ?? [:],
                screenTags: screen.metadata?.tags ?? [],
                experienceID: experience.id,
                experienceName: experience.name,
                experienceUrl: experience.sourceUrl,
                campaignID: campaignID,
                data: data,
                urlParameters: urlParameters,
                userInfo: userInfo
            )
        )
    }

    func performDismissExperience(experienceViewController: UIViewController, callback: @escaping () -> Void) {
        // we want to dismiss the underlying ExperienceViewController, so we'll ask it's presenting view controller to dismiss it.
        if let presentingViewController = experienceViewController.presentingViewController {
            presentingViewController.dismiss(animated: true) {
                callback()
            }
        } else {
            // ExperienceViewController not presented; likely embedded in a container view as a child view controller.
            callback()
        }
    }

    func handle(
        experience: ExperienceModel,
        node: Node,
        screen: Screen,
        data: Any?,
        urlParameters: [String: String],
        userInfo: [String: Any],
        deviceContext: [String: Any],
        authorizers: Authorizers,
        path: Binding<NavigationPath>,
        presentWebsiteAction: ((SafariURL) -> Void)?,
        dismissAction: (() -> Void)?,
        fullScreenModal: ((ScreenDestination) -> Void)?,
        screenModal: ((ScreenDestination) -> Void)?
    ) {
        let experienceManager = Rover.shared.resolve(ExperienceManager.self)!

        experienceManager.conversionsTracker.track(
            tags: conversionTags,
            data: data,
            urlParameters: urlParameters,
            userInfo: userInfo,
            deviceContext: deviceContext
        )

        let eventQueue = experienceManager.eventQueue
        let event = EventInfo.experienceButtonTappedEvent(
            with: urlParameters["campaignID"],
            experience: experience,
            screen: screen,
            node: node
        )
        eventQueue.addEvent(event)

        let campaignID = urlParameters["campaignID"]

        switch self {
        case .performSegue:
            let segue = experience.segues.filter {
                $0.source.id == node.id
            }.first

            guard let segue = segue else {
                rover_log(.error, "Unable to find segue with source id: %@", screen.id)
                return
            }

            switch segue.style {
            case .push:
                if let destinationScreen = segue.destination {
                    let destination = ScreenDestination(screen: destinationScreen, data: data)
                    path.wrappedValue.append(destination)
                }
            case .modal(let style):
                if let destinationScreen = segue.destination {
                    let destination = ScreenDestination(screen: destinationScreen, data: data)
                    switch style {
                    case .sheet:
                        screenModal?(destination)
                    case .fullScreen:
                        fullScreenModal?(destination)
                    }
                }
            }

        case .openURL(let url, _, _):
            guard
                let resolvedURLString = url.evaluatingExpressions(
                    data: data,
                    urlParameters: urlParameters,
                    userInfo: userInfo,
                    deviceContext: deviceContext
                ), let resolvedURL = URL(string: resolvedURLString)
            else {
                rover_log(.error, "Unable to resolve URL: %@", url)
                return
            }

            UIApplication.shared.open(resolvedURL) { success in
                if !success {
                    rover_log(.error, "Unable to present unhandled URL: %@", resolvedURL.absoluteString)
                }
            }

        case .presentWebsite(let url, _):
            guard
                let resolvedURLString = url.evaluatingExpressions(
                    data: data,
                    urlParameters: urlParameters,
                    userInfo: userInfo,
                    deviceContext: deviceContext
                ), var resolvedURLComponents = URLComponents(string: resolvedURLString)
            else {
                rover_log(.error, "Unable to resolve URL: %@", url)
                return
            }

            if !(["https", "http"].contains(resolvedURLComponents.scheme)) {
                resolvedURLComponents.scheme = "https"
            }

            guard let resolvedURL = resolvedURLComponents.url else {
                rover_log(.error, "Unable to resolve URL: %@", url)
                return
            }

            let safariURL = SafariURL(url: resolvedURL)
            presentWebsiteAction?(safariURL)
        case .close:
            if !path.wrappedValue.isEmpty {
                path.wrappedValue.removeLast()
            } else {
                dismissAction?()
            }

        case .custom:
            // This is not available and is a no-op
            break
        }

        experienceManager.registeredButtonTappedCallback?(
            ButtonTappedEvent(
                nodeID: node.id,
                nodeName: node.name,
                nodeProperties: node.metadata?.properties ?? [:],
                nodeTags: node.metadata?.tags ?? [],
                screenID: screen.id,
                screenName: screen.name,
                screenProperties: screen.metadata?.properties ?? [:],
                screenTags: screen.metadata?.tags ?? [],
                experienceID: experience.id,
                experienceName: experience.name,
                experienceUrl: experience.sourceUrl,
                campaignID: campaignID,
                data: data,
                urlParameters: urlParameters,
                userInfo: userInfo
            )
        )
    }
}
