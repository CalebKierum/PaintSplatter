//
//  ExecuteContinuously.swift
//  PaintSplatter
//
//  Created by Caleb Kierum on 8/4/19.
//  Copyright © 2019 Caleb Kierum. All rights reserved.
//

import Foundation

//Schedules a block to be run at 15fps or lower
public func executeContinuously(block: @escaping () -> Void) {
    //Get the date and capture the block
    let date = Date()
    let copy = block
    
    //Simulation runs for about a minute
    var count = 0
    let timer2 = Timer(fire: date, interval: 1.0 / 15.0, repeats: true, block: { _ in
        count += 1
        copy()
    })
    
    //Schedule it to be run on the runloop
    RunLoop.main.add(timer2, forMode: RunLoop.Mode.common)
}
