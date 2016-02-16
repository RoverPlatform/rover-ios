//
//  ViewController.swift
//  Rover
//
//  Created by ata_n on 01/05/2016.
//  Copyright (c) 2016 ata_n. All rights reserved.
//

import UIKit
import Rover

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func simulateClicked(sender: UIButton) {
        Rover.simulateBeaconEnter(UUID: NSUUID(UUIDString: "3595AA03-1767-4483-8A1B-A5BE6BEE9D35")!, majorNumber: 1, minorNumber: 1)
    }
}

