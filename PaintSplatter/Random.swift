//
//  Random.swift
//  PaintSplatterIOS
//
//  Created by Caleb Kierum on 8/4/19.
//  Copyright © 2019 Caleb Kierum. All rights reserved.
//

import Foundation
import SpriteKit

/*
 This class has custom random formulas this is for two reasons:
 1. Procedural generation is better when you can decrease the likelyhood of similar sequential numbers being gererated (groupings dont look good) so we have a pot of numbers we randomize.
 2. Sometimes we want to bias the numbers to be higher or lower in the range
 */

//We extend the array so we can shuffle it
extension Array {
    //Shuffle the array
    mutating func shuffle() {
        //For each element sort it by a random value
        for _ in 0..<((count>0) ? (count-1) : 0) {
            sort { (_,_) in arc4random() < arc4random() }
        }
    }
}

//Utilities for generating random numbers
public class Random {
    
    //This is a large array of random numbers generated at runtime it will be stirred with new numbers but will never have numbers added or removed
    private static var pot:[CGFloat] = []
    
    //Poker points to a position in the pot allowing you to move along it
    private static var poker:Int = 0
    
    //Fill up the pot with random values
    public static func initialize() {
        
        //Poker goes to zero
        poker = 0
        
        //We want 200 random numbers
        let NUMS = 200
        for i in 0...NUMS {
            //Between 0 and 1
            let value = CGFloat(i) / CGFloat(NUMS)
            pot.append(value)
        }
        //Shuffle the pot
        pot.shuffle()
    }
    
    //Stir the pot whenever you have gone through it once. Randomize a portion of the pot again and move the poker. Shuffling is too expensive
    public static func stir() {
        
        //Swap 30 random numbers
        for _ in 0..<30 {
            swap(index1: int(start: 0, end: 199), index2: int(start: 0, end: 199))
        }
        //Set the poker to a new position
        poker = int(start: 0, end: 150)
    }
    
    //Swaps elements in the pot at the two specefied indexes
    private static func swap(index1: Int, index2: Int) {
        let num1 = pot[index1]
        pot[index1] = pot[index2]
        pot[index2] = num1
    }
    
    //Gets a linear float between start and end (any number is equally likely)
    public static func floatLinear(start: CGFloat = 0, end: CGFloat = 1) -> CGFloat {
        poker += 1
        if (poker > pot.count - 2) {
            stir()
        }
        return putInRange(pot[poker], start: start, end: end)
    }
    
    //Gets a biased float between start and end (lower numbers are more likely if factor is higher)
    public static func floatBiasLow(factor: CGFloat, start: CGFloat = 0, end: CGFloat = 1) -> CGFloat {
        return putInRange(pow(floatLinear(), factor), start: start, end: end)
    }
    
    //Gets a biased float between start and end (higher numbers are more likely if factor is higher)
    public static func floatBiasHigh(factor: CGFloat, start: CGFloat = 0, end: CGFloat = 1) -> CGFloat {
        return putInRange(pow(floatLinear(), 1.0 / factor), start: start, end: end)
    }
    
    //Gets a random int between start and end
    public static func int(start: Int, end: Int) -> Int {
        return Int(arc4random_uniform(UInt32(end - start))) + start
    }
    
    //Puts a float between 0 and 1 inside of a numerical range
    static public func putInRange(_ num: CGFloat, start: CGFloat, end: CGFloat) -> CGFloat {
        return num * (end - start) + start
    }
    
    //Gets a random radian
    static public func randomRadian() -> CGFloat {
        return floatLinear(start: 0, end: 2.0 * 3.141592)
    }
}

//Gets a random color on the rainbow
var x:CGFloat = 0
public func randomColor() -> Color {
    func helper(x: CGFloat, d: CGFloat) -> CGFloat {
        return 0.5 + 0.5 * cos(6.28318 * (1.0 * x + d));
    }
    
    //Increase the x by a random amount moving it around the rainbow
    x += Random.floatLinear(start: 0.05, end: 0.12)
    let r:CGFloat = helper(x: x, d: 0)
    let g:CGFloat = helper(x: x, d: 0.33)
    let b:CGFloat = helper(x: x, d: 0.67)
    return Color(r: r, g: g, b: b)
}
