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
        super.viewDidAppear(animated)
        
        let vc = RoverViewController()
        vc.loadExperience(id: "5d546f150d0b8f0013ca6b01", useDraft: true)
        present(vc, animated: true, completion: nil)
    }
}
