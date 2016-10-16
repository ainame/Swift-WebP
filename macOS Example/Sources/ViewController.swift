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
        let queue =  DispatchQueue(label: "me.ainam.webp")
        queue.async {
            do {
                print("convert start")
                let data = try! encoder.encode(self.beforeImageView.image!, config: .preset(.picture, quality: 95))
                let webpImage = try NSImage(cgImage: WebPSimple.decode(data), size: self.beforeImageView.frame.size)
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

