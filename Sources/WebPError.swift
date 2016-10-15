//
//  WebPError.swift
//  WebP
//
//  Created by Namai Satoshi on 2016/10/16.
//  Copyright © 2016年 satoshi.namai. All rights reserved.
//

import Foundation

enum WebPError: Error {
    case importError
    case encodeError
    case decodeError
    case invalidParameter
    case brokenHeaderError
}
