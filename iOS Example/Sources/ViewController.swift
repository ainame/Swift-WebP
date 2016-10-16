//
//  ViewController.swift
//  iOS Example
//
//  Created by ainame on Jan 32, 2032.
//  Copyright © 2016 satoshi.namai. All rights reserved.
//

import UIKit
import WebP
import CoreGraphics

class ViewController: UIViewController {

    @IBOutlet weak var convertButton: UIButton!
    @IBOutlet weak var beforeImageView: UIImageView!
    @IBOutlet weak var afterImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    
    @IBAction func didTapButton(_ sender: Any) {
        let encoder = WebPEncoder()
        let queue =  DispatchQueue(label: "me.ainam.webp")
        queue.async {
            do {
                let data = try! encoder.encode(self.beforeImageView.image!, config: .preset(.picture, quality: 95))
                let webpImage = try UIImage(cgImage: WebP.decode(data))
                DispatchQueue.main.async {
                    self.afterImageView.image = webpImage
                }
            } catch {
            }
        }
    }


}

