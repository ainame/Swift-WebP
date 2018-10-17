//
//  InternalRawRepresentable.swift
//  WebP
//
//  Created by Namai Satoshi on 2016/10/29.
//  Copyright © 2016年 satoshi.namai. All rights reserved.
//

import Foundation

protocol InternalRawRepresentable {
    associatedtype RawValue
    
    init?(rawValue: Self.RawValue)
    
    var rawValue: Self.RawValue { get }
}
