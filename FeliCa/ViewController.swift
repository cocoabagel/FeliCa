//
//  ViewController.swift
//  FeliCa
//
//  Created by Kazutoshi Baba on 2020/01/15.
//  Copyright © 2020 COCOABAGEL. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    let felica = Felica()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        felica.didFinishScan = { dataList in
            print("did finish scan")
        }
        
        felica.didFailWithError = { error in
            print(error.localizedDescription)
        }
    }
    
    @IBAction func scanButtonTapped(_ sender: Any) {
        felica.scan()
    }
}
