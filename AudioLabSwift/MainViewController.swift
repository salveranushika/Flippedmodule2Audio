//
//  MainViewController.swift
//  AudioLabSwift
//
//  Created by Ruthiwik  on 10/8/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import UIKit

class MainViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    
    @IBAction func goToModuleA(_ sender: UIButton) {
            performSegue(withIdentifier: "gotoA", sender: self)

    }
    

    @IBAction func gotoMouleB(_ sender: UIButton) {
        
           performSegue(withIdentifier: "gotoB", sender: self)

    }
}
