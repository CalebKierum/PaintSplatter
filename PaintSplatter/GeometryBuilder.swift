//
//  GeometryBuilder.swift
//  PaintSplatterIOS
//
//  Created by Caleb Kierum on 8/4/19.
//  Copyright © 2019 Caleb Kierum. All rights reserved.
//

/*
 This file is just for creating vertex buffer objects based on geometrical primitives
 
 GeometryCreator creates buffers initialized with a specefic shape and that VertexBufferCreator can have shapes added to them up until getBufferObject() is called
 */

import Metal
import MetalKit

struct Vertex {
    var position:vector_float4
    var color:vector_float4
}

//Stores vertices and allows you to add more until you finally turn it into a buffer
public class VertexBufferCreator {
    //Holds a bunch of vertices
    private var data:[Vertex] = []
    
    
    //Empty geometry creator
    public init () {
        
    }
    
    //Add a square
    public func addSquare(center: Point, width: CGFloat, rotation: CGFloat = 0, color: Color = Color.red) {
        let add = GeometryCreator.square(center: center, width: width, rotation: rotation, color: color)
        for v in add.data {
            data.append(v)
        }
    }
    
    //Add a circle
    public func addCircle(center: Point, radius: CGFloat, color: Color = Color.red) {
        let add = GeometryCreator.circle(center: center, radius: radius, color: color)
        for v in add.data {
            data.append(v)
        }
    }
    
    //Add a line
    public func addLine(from: Point, to: Point, width: CGFloat, color: Color = Color.red) {
        let add = GeometryCreator.line(from: from, to: to, width: width, color: color)
        for v in add.data {
            data.append(v)
        }
    }
    
    //Add a rectangle
    public func addRectangle(center: Point, width: CGFloat, height: CGFloat, rotation: CGFloat = 0, color: Color = Color.red) {
        let add = GeometryCreator.rectangle(center: center, width: width, height: height, rotation: rotation, color: color)
        for v in add.data {
            data.append(v)
        }
    }
    
    //Add a vertex
    public func addVertex(point: Point, color: Color) {
        addVertex(x: Float(point.x), y: Float(point.y), color: color)
    }
    public func addVertex(x: Float, y: Float) {
        addVertex(x: x, y: y, color: CIColor(red: 1, green: 1, blue: 1, alpha: 1))
    }
    public func addVertex(x: Float, y: Float, color: Color) {
        addVertex(x: x, y: y, color: CIColor.convert(color: color))
    }
    public func addVertex(x: Float, y: Float, color: CIColor) {
        data.append(Vertex(position: vector_float4(x, y, 0.0, 1.0), color: vector_float4(Float(color.red), Float(color.green), Float(color.blue), Float(color.alpha))))
    }
    
    //Get the buffer object that is used for rendering
    public func getBufferObject() -> MTLBuffer {
        //We need a metal device for this to work
        if (metalState.sharedDevice == nil) {
            fatalError("Must create a metal device before creating a point buffer")
        }
        //The size is the size of an element multipled by its count
        let size = data.count * MemoryLayout.size(ofValue: data[0])
        
        //Move the data into a buffer
        return ensure(metalState.sharedDevice?.makeBuffer(bytes: data, length: size, options: [MTLResourceOptions.storageModeShared]))//Used to be shared
    }
    
    //Get the vertex count
    public func getVertexCount() -> Int {
        return data.count
    }
}

public class GeometryCreator {
    
    //Creates a square with the given parameters
    public static func square(center: Point, width: CGFloat, rotation: CGFloat = 0, color: Color = Color.red) -> VertexBufferCreator {
        return GeometryCreator.rectangle(center: center, width: width, height: width, rotation: rotation, color: color)
    }
    
    //Creates a circle with the given parameters
    public static func circle(center: Point, radius: CGFloat, color: Color = Color.red) -> VertexBufferCreator {
        
        let data = VertexBufferCreator()
        if (!radius.isNaN) {
            //How many verticies is based on radius
            let resolution:Int = Int(20 * radius)+10
            
            //Put points on the edge of the circle
            for i in 1...resolution {
                let prog = CGFloat(i) / CGFloat(resolution)
                let prog2 = CGFloat(i + 1) / CGFloat(resolution)
                let twoPI:CGFloat = 2 * 3.141592
                let theta1 = prog * twoPI
                let theta2 = prog2 * twoPI
                data.addVertex(x: Float(cos(theta1) * radius + center.x), y: Float(sin(theta1) * radius + center.y), color: color)
                data.addVertex(x: Float(cos(theta2) * radius + center.x), y: Float(sin(theta2) * radius + center.y), color: color)
                data.addVertex(point: center, color: color)
            }
        }
        return data
    }
    
    //Creates a line with the given parameters
    public static func line(from: Point, to: Point, width: CGFloat, color: Color = Color.red) -> VertexBufferCreator {
        let dx = to.x - from.x
        let dy = to.y - from.y
        return GeometryCreator.rectangle(center: Point(x: (from.x + to.x) / 2.0, y: (from.y + to.y) / 2.0), width: sqrt(dx * dx + dy * dy), height: width, rotation: atan2(dy, dx), color: color)
    }
    
    //Creates a rectangle with the given parameters. Rotation is 0 means width is perfectly horizontal
    public static func rectangle(center: Point, width: CGFloat, height: CGFloat, rotation: CGFloat = 0, color: Color = Color.red) -> VertexBufferCreator{
        let data = VertexBufferCreator()
        //Spawns 6 points based on the 4 parts that this could be at
        var tl = Point(x: -width / 2.0, y: height / 2.0)
        var tr = Point(x: width / 2.0, y: height / 2.0)
        var bl = Point(x: -width / 2.0, y: -height / 2.0)
        var br = Point(x: width / 2.0, y: -height / 2.0)
        tl.rotate(rotation)
        tr.rotate(rotation)
        bl.rotate(rotation)
        br.rotate(rotation)
        tl += center
        tr += center
        bl += center
        br += center
        
        data.addVertex(point: bl, color: color)
        data.addVertex(point: br, color: color)
        data.addVertex(point: tr, color: color)
        data.addVertex(point: bl, color: color)
        data.addVertex(point: tr, color: color)
        data.addVertex(point: tl, color: color)
        
        return data
    }
    
    //Creates a splat of the specefied color and center
    public static func splat(center: Point, color: Color = Color.red) -> VertexBufferCreator {
        
        //NOTE:  Constants to tweak this are in SplatConstants
        
        //The buffer that will get filled with shapes
        let buffer = VertexBufferCreator()
        
        //Should be how much the frame it keeps up
        let spaceScalar:CGFloat = 1 * Random.floatLinear(start: 0.8, end: 1.2)
        
        //Scalars for the main blob
        let practicalScalar = SplatConstants.totalScale * spaceScalar
        
        //I realize it is bad style but if trues are used to show the tree structure of the generation and what is dependent on what
        if (true) {
            //Central ball
            let majorSize = Random.floatBiasHigh(factor: 4, start: SplatConstants.majorLow, end: 1.0) * practicalScalar
            
            //-Bounded
            if (SplatConstants.bounded) {
                let count = Random.int(start: 1, end: 8)
                for _ in 0..<count {
                    let size = Random.floatLinear(start: majorSize * 0.4, end: majorSize * 0.7)
                    var displacement = Random.floatLinear(start: majorSize * 0.6, end: majorSize * 0.8)
                    let theta = Random.randomRadian()
                    
                    displacement *= SplatConstants.displacementScalar
                    
                    var point = Point(x: cos(theta) * displacement, y: sin(theta) * displacement)
                    point += center
                    
                    buffer.addCircle(center: point, radius: size * SplatConstants.sizeScalar * 0.7, color: color)
                }
            }
            
            //-Orbiters
            if (true) {
                let counter = Random.int(start: 2, end: 8)
                var theta = Random.randomRadian()
                for _ in 0..<counter {
                    let targetSize = majorSize / 3.5
                    
                    let scalar = Random.floatLinear()
                    
                    if (SplatConstants.spinoffs && (Random.floatLinear(start: scalar / 2, end: 1.0) > scalar)) {
                        let spinCount = Random.int(start: 1, end: 4)
                        for _ in 0..<spinCount {
                            let targetSize = majorSize / 1.5
                            let displacementScale = Random.floatLinear()
                            var displacement = majorSize + displacementScale * majorSize * 2
                            let size = Random.floatLinear(start: targetSize * 0.5, end: targetSize) * pow(1 - displacementScale, 3.0)
                            
                            let mag:CGFloat = (2.0 * 3.141592) / 52.0
                            let waver = Random.floatLinear(start: -mag, end: mag)
                            displacement *= SplatConstants.displacementScalar
                            var point = Point(x: cos(theta + waver) * displacement, y: sin(theta + waver) * displacement)
                            point += center
                            
                            buffer.addCircle(center: point, radius: size * SplatConstants.sizeScalar, color: color)
                        }
                    }
                    
                    let size = Random.putInRange(scalar, start: targetSize * 0.85, end: targetSize * 1.0)
                    theta += Random.randomRadian()
                    var displacement = Random.floatLinear(start: majorSize - size, end: majorSize * 1.1)
                    displacement *= SplatConstants.displacementScalar
                    var point = Point(x: cos(theta) * displacement, y: sin(theta) * displacement)
                    point += center
                    
                    if (SplatConstants.orbiters) {
                        buffer.addCircle(center: point, radius: size * SplatConstants.sizeScalar * 0.9, color: color)
                    }
                }
            }
            
            //-Random
            if (SplatConstants.random) {
                let randomCount = Random.int(start: 6, end: SplatConstants.maxRandom)
                for _ in 0..<randomCount {
                    let scalar = Random.floatLinear()
                    var displacement = majorSize*1.4 + majorSize * 2.5 * scalar
                    let targetSize = practicalScalar / 8.2
                    let scale = targetSize * pow(1.0 - scalar, 1.2) * Random.floatLinear(start: 0.9, end: 1.0)
                    let theta = Random.randomRadian()
                    
                    displacement *= SplatConstants.displacementScalar
                    var point = Point(x: cos(theta) * displacement, y: sin(theta) * displacement)
                    point += center
                    
                    buffer.addCircle(center: point, radius: scale * SplatConstants.sizeScalar, color: color)
                }
            }
            
            //-Lines
            if (true) {
                let count = Random.int(start: 0, end: SplatConstants.maxLines)
                for _ in 0..<count {
                    let widthScalar:CGFloat = 1.0
                    let width = Random.floatBiasLow(factor: 1.2, start: practicalScalar * 0.12, end: practicalScalar * 0.13) * widthScalar
                    let length = Random.floatBiasLow(factor: 1.5, start: majorSize * 0.4, end: majorSize * 1.5)
                    let theta = Random.randomRadian()
                    
                    let core = majorSize * 0.5
                    var outset = majorSize + length
                    
                    var p1 = Point(x: cos(theta) * core, y: sin(theta) * core)
                    p1 += center
                    
                    outset *= SplatConstants.displacementScalar
                    var p2 = Point(x: cos(theta) * outset, y: sin(theta) * outset * SplatConstants.displacementScalar)
                    p2 += center
                    
                    if (SplatConstants.lines) {
                        buffer.addLine(from: p1, to: p2, width: width * SplatConstants.sizeScalar, color: color)
                    }
                    
                    
                    if (SplatConstants.cap) {
                        let width = width * Random.floatLinear(start: 1.00, end: 1.1)
                        buffer.addCircle(center: p2, radius: width * SplatConstants.sizeScalar, color: color)
                    }
                }
            }
            
            if (SplatConstants.major) {
                buffer.addCircle(center: center, radius: majorSize  * SplatConstants.sizeScalar * 1.1, color: color)
            }
        }
        return buffer
    }
}
