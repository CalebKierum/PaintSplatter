//
//  TextureTools.swift
//  PaintSplatterIOS
//
//  Created by Caleb Kierum on 8/4/19.
//  Copyright © 2019 Caleb Kierum. All rights reserved.
//

import Foundation
import Metal
import CoreImage
import MetalKit
import UIKit
import MetalPerformanceShaders

//Some tools for creating textures
public class TextureTools {
    
    //Creates a square texture of the dimensions
    public static func createTexture(ofSize size: CGFloat) -> MTLTexture {
        if (metalState.sharedDevice == nil) {
            fatalError("Must create a metal device before creating a texture")
        }
        
        //Describve it with its hight and turn of mipmaps
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: Int(size), height: Int(size), mipmapped: false)
        
        //Allow it to be used in all scenarios
        let usage:MTLTextureUsage = [MTLTextureUsage.shaderWrite, MTLTextureUsage.shaderRead, MTLTextureUsage.renderTarget]
        descriptor.usage = usage
        
        //Create it
        return ensure(metalState.sharedDevice?.makeTexture(descriptor: descriptor))
    }
    
    public static func loadTexture(named: String) -> MTLTexture {
        let textureLoader = ensure(MTKTextureLoader(device: metalState.sharedDevice!))
        
        let textureLoaderOptions = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
        ]
        
        return ensure(try textureLoader.newTexture(name: named,
                                            scaleFactor: 1.0,
                                            bundle: nil,
                                            options: textureLoaderOptions))
    }
    public static func loadTexture(image: UIImage) -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: metalState.sharedDevice!)
        
        let options = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue | MTLTextureUsage.shaderWrite.rawValue | MTLTextureUsage.renderTarget.rawValue),
            MTKTextureLoader.Option.SRGB: false
        ]
        
        return ensure(try textureLoader.newTexture(cgImage: image.cgImage!, options: options))
    }
}
