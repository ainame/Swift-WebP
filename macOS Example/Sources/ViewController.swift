//
//  ViewController.swift
//  macOS Example
//
//  Created by Namai Satoshi on 2016/10/17.
//  Copyright © 2016年 ainame. All rights reserved.
//

import Cocoa
import WebP

class MacOSViewController: NSViewController {
    enum State {
        case none
        case processing
    }
    var state: State = .none

    @IBOutlet weak var beforeImageView: NSImageView!
    @IBOutlet weak var afterImageView: NSImageView!
    @IBOutlet weak var convertButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func didTappedButton(sender: NSResponder) {
        print("tapped")
        if state == .processing { return }
        state = .processing

        let encoder = WebPEncoder()
        let decoder = WebPDecoder()
        let queue = DispatchQueue(label: "me.ainam.webp")
        let image = self.beforeImageView.image!

        queue.async {
            do {
                print("convert start")
                let data = try encoder.encode(image, config: .preset(.photo, quality: 95))
                var options = WebPDecoderOptions()
                options.scaledWidth = Int(image.size.width)
                options.scaledHeight = Int(image.size.height)
                let webpImage = try decoder.decode(toNSImage: data, options: options)
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

