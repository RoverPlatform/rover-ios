//
//  ViewController.swift
//  Example
//
//  Created by Andrew Clunis on 2019-04-26.
//  Copyright © 2019 Rover Labs Inc. All rights reserved.
//

import os
import Rover
import UIKit

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let experienceFile = Bundle.main.path(forResource: "experience.json", ofType: nil)!
        
        let experienceFileURL: URL = URL(fileURLWithPath: experienceFile)
        os_log("Experience file path: %@", experienceFileURL.absoluteString)
        let experienceJson = try! Data(contentsOf: experienceFileURL)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.rfc3339)
        
        let experience = try! decoder.decode(Experience.self, from: experienceJson)
        
        let rvc = RoverViewController()
        rvc.loadExperience(experience: experience)
        
        self.present(rvc, animated: false)
    }
}
