//
//  Settings.swift
//  PaintSplatterIOS
//
//  Created by Caleb Kierum on 8/4/19.
//  Copyright © 2019 Caleb Kierum. All rights reserved.
//

/*
 Purpose: Stores static variables that control the parameters of various things inside of the program
 */

//This is just a sampling of the most interesting parameters of the simulation there are actually many (many) more

import CoreGraphics

//Tweaks constants for the splat generation
public class SplatConstants {
    //How big the entire splat is
    public static var totalScale:CGFloat = 0.13
    //The lowest scalar for the central circle
    public static var majorLow:CGFloat = 0.9
    //Scalar for the size of all circles in the splat
    public static var sizeScalar:CGFloat = 0.8
    //Scales how far out elements go from the center
    public static var displacementScalar:CGFloat = 1.4
    //Whether or not the main ball is there
    public static var major = true
    //Whether or not the bounded balls (small on the edge of the main) are there
    public static var bounded = true
    //Whether or not there is stuff thrown out from the orbiters
    public static var orbiters = true
    //Whether or not to draw larger lumps on the edges of the main circle
    public static var spinoffs = true
    //Whether random circles are thrown out from the main sphere
    public static var random = true
    //Whether lines are sent out form the splatter
    public static var lines = true
    //Give those lines a cap at the end
    public static var cap = true
    //Max lines to be drawn
    public static var maxLines:Int = 6
    //Max random thingies
    public static var maxRandom:Int = 15
    //The contribution of the first (natural) noise texture
    public static var noise1Contrib:CGFloat = 0.35
    //The contribution of the first (smooth) noise texture
    public static var noise2Contrib:CGFloat = 0.24
    //The ammount to blur the source texture
    public static var blurAmmount:CGFloat = 0.2
    //The clamps center
    public static var clampCenter:CGFloat = 0.473
    //The clamps tolerance
    public static var clampTolerance:CGFloat = 0.0
}

//CAREFUL: Many of these are intertwined and have complicated effects
public class WaterSimConstants {
    //How far a spot looks for other stpots
    public static var lookDistance:CGFloat = 3.0
    //Strength of water barrier before diffusion
    public static var overflowStrength:CGFloat = 0.2
    //Strenght of the current color vs others
    public static var diffusionBoost:CGFloat = 0.05
    //SPeed that the canvas dries
    public static var drySpeed:CGFloat = 0.03
    //The ammount that color spreads to adjacent things
    public static var colorSpread:CGFloat = 0.9
    //The ammount of wetness given to each new splat
    public static var splatWetness:CGFloat = 10.0
}
