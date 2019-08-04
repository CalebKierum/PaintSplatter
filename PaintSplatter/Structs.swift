//
//  Structs.swift
//  PaintSplatterIOS
//
//  Created by Caleb Kierum on 8/4/19.
//  Copyright © 2019 Caleb Kierum. All rights reserved.
//

import Foundation
import UIKit

public typealias Color = UIColor
public typealias Point = CGPoint

extension Point {
    public static func += (left: inout Point, right: Point) {
        left.x += right.x
        left.y += right.y
    }
    public mutating func rotate(_ by: CGFloat) {
        let sx = x
        let sy = y
        x = sx * cos(by) - sy * sin(by)
        y = sx * sin(by) + sy * cos(by)
    }
    
}
