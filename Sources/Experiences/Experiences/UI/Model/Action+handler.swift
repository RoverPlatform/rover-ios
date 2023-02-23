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


import UIKit
import SafariServices
import os.log
import RoverFoundation

extension ExperienceAction {
    func handle(experience: ExperienceModel, node: Node, screen: Screen, data: Any?, urlParameters: [String: String], userInfo: [String: Any], authorize: @escaping (inout URLRequest) -> Void, experienceViewController: RenderExperienceViewController, screenViewController: ScreenViewController) {
        let experienceManager = Rover.shared.resolve(ExperienceManager.self)!
        
        switch(self) {
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
                let viewController = experienceManager.screenViewController(experience, segue.destination, data, urlParameters, userInfo, authorize)
                screenViewController.show(viewController, sender: screenViewController)
                
            case let .modal(presentationStyle):
                let viewController = experienceManager.navBarViewController(experience, segue.destination, data, urlParameters, userInfo, authorize)
                
                switch presentationStyle {
                case .fullScreen:
                    viewController.modalPresentationStyle = .fullScreen
                
                case .sheet:
                    viewController.modalPresentationStyle = .pageSheet
                }
                
                screenViewController.present(viewController, animated: true)
            }
        case let .openURL(url, dismissExperience):
            guard let resolvedURLString = url.evaluatingExpressions(data: data, urlParameters: urlParameters, userInfo: userInfo), let resolvedURL = URL(string: resolvedURLString) else {
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
        case let .presentWebsite(url):
            guard let resolvedURLString = url.evaluatingExpressions(data: data, urlParameters: urlParameters, userInfo: userInfo), var resolvedURLComponents = URLComponents(string: resolvedURLString) else {
                return
            }
            if !(["https", "http"].contains(resolvedURLComponents.scheme)) {
                resolvedURLComponents.scheme = "https"
            }
            guard let resolvedURL = resolvedURLComponents.url else {
                return
            }
            
            let viewController = SFSafariViewController(url: resolvedURL)
            screenViewController.present(viewController, animated: true)
        case .close:
            screenViewController.dismiss(animated: true)
        case let .custom(dismissExperience):
            func behaviour() {
                if let callback = experienceManager.registeredCustomActionCallback {
                    let campaignID = urlParameters["campaignID"]
                    callback(
                        CustomActionActivationEvent(
                            nodeId: node.id,
                            nodeName: node.name,
                            nodeProperties: node.metadata?.properties ?? [:],
                            nodeTags: node.metadata?.tags ?? [],
                            screenId: screen.id,
                            screenName: screen.name,
                            screenProperties: screen.metadata?.properties ?? [:],
                            screenTags: screen.metadata?.tags ?? [],
                            experienceId: experience.id,
                            experienceName: experience.name,
                            campaignId: campaignID,
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
}
