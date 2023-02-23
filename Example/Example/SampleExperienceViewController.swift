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
import RoverFoundation
import RoverExperiences

class SampleExperienceViewController: UIViewController {
    
    var roverViewController: ExperienceViewController?
    var classicExperienceButton: UIButton?
    var classicExperienceUrlField: UITextField?
    var experienceButton: UIButton?
    var experienceUrlField: UITextField?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        
        let layoutWidth = view.safeAreaLayoutGuide.layoutFrame.width
        let layoutOriginY = view.safeAreaLayoutGuide.layoutFrame.origin.y
        
        classicExperienceUrlField = UITextField(frame: CGRect(
            x: view.safeAreaLayoutGuide.layoutFrame.origin.x + 5,
            y: layoutOriginY + 50,
            width: view.safeAreaLayoutGuide.layoutFrame.width - 10,
            height: 50))
        
        if let classicExperienceUrlField = classicExperienceUrlField {
            classicExperienceUrlField.borderStyle = .bezel
            classicExperienceUrlField.text = "https://inbox.staging.rover.io/rLBt7N"
            view.addSubview(classicExperienceUrlField)
        }
        
        classicExperienceButton = UIButton(type: .system)
        if let classicExperienceButton = classicExperienceButton  {
            classicExperienceButton.setTitle("Show Classic Experience", for: .normal)
            classicExperienceButton.addTarget(self, action: #selector(showClassicExperience(sender:)), for: .touchUpInside)
            
            classicExperienceButton.frame = CGRect(
                x: layoutWidth / 2 - 100,
                y: layoutOriginY + 150,
                width: 200,
                height: 50)
            view.addSubview(classicExperienceButton)
        }
        
        experienceUrlField = UITextField(frame: CGRect(
            x: view.safeAreaLayoutGuide.layoutFrame.origin.x + 5,
            y: layoutOriginY + 250,
            width: view.safeAreaLayoutGuide.layoutFrame.width - 10,
            height: 50))
        
        if let experienceUrlField = experienceUrlField {
            experienceUrlField.borderStyle = .bezel
            experienceUrlField.text = "https://testbench.rover.io/campaigns/191510/experience"
            view.addSubview(experienceUrlField)
        }
        
        experienceButton = UIButton(type: .system)
        if let experienceButton = experienceButton  {
            experienceButton.setTitle("Show Experience", for: .normal)
            experienceButton.addTarget(self, action: #selector(showExperience(sender:)), for: .touchUpInside)
            
            experienceButton.frame = CGRect(
                x: layoutWidth / 2 - 100,
                y: layoutOriginY + 350,
                width: 200,
                height: 50)
            view.addSubview(experienceButton)
        }

        roverViewController = ExperienceViewController()
    }
    
    @objc func showClassicExperience(sender: UIButton) {
        if let experienceUrlString = classicExperienceUrlField?.text,
           let experienceUrl = URL(string: experienceUrlString),
           let roverViewController = roverViewController {
            roverViewController.loadExperience(with: experienceUrl)
            present(roverViewController, animated: true)
        }
    }
    
    @objc func showExperience(sender: UIButton) {
        if let experienceUrlString = experienceUrlField?.text,
           let experienceUrl = URL(string: experienceUrlString),
           let roverViewController = roverViewController {
            roverViewController.loadExperience(with: experienceUrl)
            present(roverViewController, animated: true)
        }
    }
}
