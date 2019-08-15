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
        let rvc = RoverViewController()
        rvc.loadExperience(id: "5d4da79b050975001389f090", useDraft: true)
        self.present(rvc, animated: false)
    }

}
