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

class IOSViewController: UIViewController {
    enum State {
        case none
        case processing
    }
    
    @IBOutlet weak var convertButton: UIButton!
    @IBOutlet weak var beforeImageView: UIImageView!
    @IBOutlet weak var afterImageView: UIImageView!
    
    var state: State = .none
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    
    @IBAction func didTapButton(_ sender: Any) {
        print("tapped")
        if state == .processing { return }
        state = .processing
        let encoder = WebPEncoder()
        let decoder = WebPDecoder()
        let queue = DispatchQueue(label: "me.ainam.webp")
        let image = beforeImageView.image!
        queue.async {
            do {
                print("convert start")
                let data = try! encoder.encode(image, config: .preset(.picture, quality: 95))
                var options = WebPDecoderOptions()
                options.scaledWidth = Int(image.size.width)
                options.scaledHeight = Int(image.size.height)
                let cgImage: CGImage = try decoder.decode(data, options: options)
                let webpImage = UIImage(cgImage: cgImage)
                print("decode finish")
                DispatchQueue.main.async {
                    self.afterImageView.image = webpImage
                    self.state = .none
                }
            } catch let error {
                self.state = .none
                print(error)
            }
        }
    }

}

