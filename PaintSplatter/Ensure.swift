//
//  Ensure.swift
//  PaintSplatterIOS
//
//  Created by Caleb Kierum on 8/4/19.
//  Copyright © 2019 Caleb Kierum. All rights reserved.
//

import Foundation

public func ensure<T>(_ expr: @autoclosure () throws -> T?, orError message: @autoclosure () -> String = "Error") -> T {
    do {
        if let result = try expr() { return result }
        else { print(message()) }
    }
    catch {
        print(message())
        print("error: \(error)")
    }
    fatalError("ISSUES")
}
