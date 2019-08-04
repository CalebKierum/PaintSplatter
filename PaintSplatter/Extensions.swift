//
//  Extensions.swift
//  PaintSplatterIOS
//
//  Created by Caleb Kierum on 8/4/19.
//  Copyright © 2019 Caleb Kierum. All rights reserved.
//

import Foundation
import Metal
import UIKit
import Accelerate

/*
 The purpose of this file is to provide extensions to metal classes that make them more friendly to use
 */

//Add some convenience functions to the compute command encoder that make it easier for playground user to use
extension MTLRenderCommandEncoder {
    
    //Draw the contents of a VertexBufferCreator containing geometry
    public func drawTriangles(buffer: VertexBufferCreator) {
        if (buffer.getVertexCount() > 2) {
            setVertexBuffer(buffer.getBufferObject(), offset: 0, index: 0)
            drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: buffer.getVertexCount())
        }
    }
    
    //Draw full screen for shaders that work on the full screen
    public func drawFullScreen() {
        drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
}

extension CIColor {
    static func convert(color: UIColor) -> CIColor {
        return CIColor(color: color)
    }
}

extension Color {
    public convenience init(r: CGFloat, g: CGFloat, b: CGFloat) {
        self.init(displayP3Red: r, green: g, blue: b, alpha: 1.0)
    }
}

//Intenal class used to initialize buffers once and only once
class bufferHolder {
    //Dictionary to hold them
    static var buffers:[Int : UnsafeMutableRawPointer] = [Int : UnsafeMutableRawPointer]()
    
    //Gets a buffer of size by creating one or getting one
    //NOTE: Size is size of a square texture with 4x1byte channels
    static func get(size: Int) -> UnsafeMutableRawPointer {
        if let curr = buffers[size] {
            return curr
        } else {
            let create = size * size * 4
            //NOTE: We ignore this error because when we port to ipad it does not have the latest swift
            let data = UnsafeMutableRawPointer.allocate(byteCount: create, alignment: 1)
            buffers[size] = data
            return data
        }
    }
}

//Extensions on the playground
public extension MTLTexture {
    //Turns a MTLTexture into something that is viewable in the gridView and most importantly the playground live views
    func toImage() -> UIImage? {
        //NOTE: On macOS textures are on seperate memory and must be synchronized for this to work. See MetalState.swift
        
        //Calculate some dimensions
        let texture = self
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * 4
        
        //Get a buffer for it
        let data = bufferHolder.get(size: width)
        
        //Get the bytes from the cpu to the gpu
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.getBytes(data, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        
        //If the format is strange (usually when loading texture images) switch the channels
        if (pixelFormat == .bgra8Unorm) {
            //Use accelerate to remap the channels
            let map:[UInt8] = [2, 1, 0, 3]
            var buffer = vImage_Buffer(data: data, height: UInt(height), width: UInt(width), rowBytes: bytesPerRow)
            vImagePermuteChannels_ARGB8888(&buffer, &buffer, map, 0)
        }
        
        //Tell it the color space and use that to create the context
        guard let colorSpace = CGColorSpace(name: CGColorSpace.genericRGBLinear) else { return nil }
        guard let context = CGContext(data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        
        //Create a cgImage from the context
        guard let cgImage = context.makeImage() else { return nil }
        
        //Use that context to make the image
        //return Image(cgImage: cgImage, size: Size(width: width, height: height))
        return UIImage(cgImage: cgImage)
    }
}
