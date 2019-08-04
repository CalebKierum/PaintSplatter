//
//  MetalState.swift
//  PaintSplatterIOS
//
//  Created by Caleb Kierum on 8/4/19.
//  Copyright © 2019 Caleb Kierum. All rights reserved.
//

import Foundation
import Metal
import CoreImage
import MetalPerformanceShaders

/*
 Metal State is a class designed to abstract away the details of Metal making it easier
 to develop 2D graphics prototypes.
 
 Not made for highly efficient realtime simulation. It optimizes for ease of use.
 
 It does not make any attempt to recover from failures
 
 See metalState for more information
 */

//This is a state machine designed to not let the user mess up when programming
public enum States {
    case Idle
    case Preparing
    case Rendering
    case Computing
}

//This holds the metal state allowing for an additional abstraction on metal
public class metalState {
    //The representation of the gpu
    public var device:MTLDevice? = nil
    
    //Sends the device out to other classes like the texture loader and geometry creator
    public static var sharedDevice:MTLDevice? = nil
    
    //Constant command queue
    private var queue:MTLCommandQueue? = nil
    
    //The current state it is in
    private var state:States = .Idle
    
    //The command buffer (changes each frame)
    private var buffer:MTLCommandBuffer? = nil
    
    //Clear color of the frame
    private var clear:MTLClearColor = MTLClearColorMake(0, 0, 0, 1.0)
    
    //This is a faking feature that causes it to draw the clear color if no commands were sent
    private var shouldDrawBlank:Bool = true
    
    //The drawable that will be rendered to set with setDrawable
    private var drawable:MTLTexture? = nil
    
    //This is the list of textures that may not be synchronized this is a problem on macOS because it could cause the display in playground call to result in black
    private var synchronizeList:[MTLTexture] = []
    
    //Pipelines for all the common functions of this
    private var copy_pipeline:MTLRenderPipelineState? = nil
    private var clamp_pipeline:MTLRenderPipelineState? = nil
    private var alpha_pipeline:MTLRenderPipelineState? = nil
    private var draw_pipeline:MTLRenderPipelineState? = nil
    
    public init () {
        //Grab the highest powered mtl device (mostly on macOS is this a problem)
        let dev = ensure(MTLCreateSystemDefaultDevice())
        device = dev
        metalState.sharedDevice = dev
        
        //Get the command queue
        queue = dev.makeCommandQueue()
        
        //Get the library
        let library = ensure(dev.makeDefaultLibrary())
        
        //Compile all of them into function
        let copy_vertex = ensure(library.makeFunction(name: "vertex_mix"))
        let copy_fragment = ensure(library.makeFunction(name: "fragment_mix"))
        
        let alpha_vertex = ensure(library.makeFunction(name: "vertex_alpha"))
        let alpha_fragment = ensure(library.makeFunction(name: "fragment_alpha"))
        
        let clamp_vertex = ensure(library.makeFunction(name: "vertex_clamp"))
        let clamp_fragment = ensure(library.makeFunction(name: "fragment_clamp"))
        
        let draw_vertex = ensure(library.makeFunction(name: "vertexShader"))
        let draw_fragment = ensure(library.makeFunction(name: "fragmentShader"))
        
        //Get pipelines from them
        copy_pipeline = createRenderPipeline(vertex: copy_vertex, fragment: copy_fragment)
        alpha_pipeline = createRenderPipeline(vertex: alpha_vertex, fragment: alpha_fragment)
        clamp_pipeline = createRenderPipeline(vertex: clamp_vertex, fragment: clamp_fragment)
        draw_pipeline = createRenderPipeline(vertex: draw_vertex, fragment: draw_fragment)
    }
    
    //Read the state of the object
    public func getState() -> States{
        return state
    }
    //Cache render pass descriptors for when the drawable does not change
    private var cache:MTLRenderPassDescriptor?
    //Mark the cache as invalid whenever a new drawable is set
    private var invalid:Bool = false
    private func renderPassDescriptor() -> MTLRenderPassDescriptor? {
        if (!invalid && cache != nil) {
            return cache!
        }
        if let draw = drawable {
            let descriptor = MTLRenderPassDescriptor()
            descriptor.colorAttachments[0].texture = draw
            descriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
            descriptor.colorAttachments[0].storeAction = MTLStoreAction.store
            descriptor.colorAttachments[0].clearColor = clear
            cache = descriptor
            invalid = false
            return descriptor
        }
        cache = nil
        return nil
    }
    
    //Sets the drawable to something marking the old drawable as needing synchronization
    public func setDrawable(to: MTLTexture) {
        if let d = drawable {
            synchronizeList.append(d)
        }
        invalid = true
        drawable = to
    }
    
    //Sets the background/clear color to the passe in color
    public func setBackground(color: Color) {
        let intermediate = CIColor.convert(color: color)
        clear = MTLClearColor(red: Double(intermediate.red), green: Double(intermediate.green), blue: Double(intermediate.blue), alpha: 1.0)
    }
    
    //Compiles a shader returning its function
    public func compileShader(named: String) -> MTLFunction {
        let shader = ensure(try String(contentsOf: #fileLiteral(resourceName: "Shaders.metal")))
        let library = ensure(try device?.makeLibrary(source: shader, options: nil))
        return ensure(library.makeFunction(name: named))
    }
    
    //Creates a compute pipeline from a compute command
    public func createComputePipeline(function: MTLFunction) -> MTLComputePipelineState {
        return ensure(try device?.makeComputePipelineState(function: function))
    }
    
    //Creates a render pipeline from a vertex and a fragment shader
    public func createRenderPipeline(vertex: MTLFunction, fragment: MTLFunction) -> MTLRenderPipelineState {
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.sampleCount = 1
        pipelineDescriptor.vertexFunction = vertex
        pipelineDescriptor.fragmentFunction = fragment
        pipelineDescriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        
        return ensure(try device?.makeRenderPipelineState(descriptor: pipelineDescriptor))
    }
    
    //Prepare the frame by making a command buffer for it
    //Idle->Preparing
    public func prepareFrame() {
        
        //State machine check
        if (state != .Idle) {
            fatalError("Invalid Command! Must be idle current state is \(state)")
        }
        state = .Preparing
        shouldDrawBlank = true
        buffer = ensure(queue?.makeCommandBuffer())
    }
    
    //Get the render command encoder that considers the drawable and a few other factors
    //Preparing->Rendering
    public func getRenderEncoder() -> MTLRenderCommandEncoder {
        
        //State machine check
        if (state != .Preparing) {
            fatalError("Invalid Command! Must be preparing current state is \(state)")
        }
        
        //Create a descriptor based on the drawable
        if let desc = renderPassDescriptor() {
            shouldDrawBlank = false
            state = .Rendering
            return ensure(buffer?.makeRenderCommandEncoder(descriptor: desc))
        } else {
            fatalError("You must have a drawable to draw to for a render command encoder")
        }
        fatalError("Error")
    }
    
    //Finish encoding a command encoder so you can use a new one
    //Rendering->Preparing
    public func finishEncoding(encoder: MTLRenderCommandEncoder) {
        
        //State machine check
        if (state != .Rendering) {
            fatalError("Invalid Command! Must be rendering current state is \(state)")
        }
        encoder.endEncoding()
        state = .Preparing
    }
    
    //Computing->Preparing
    public func finishEncoding(encoder: MTLComputeCommandEncoder) {
        
        //State machine check
        if (state != .Computing) {
            fatalError("Invalid Command! Must be computing current state is \(state)")
        }
        encoder.endEncoding()
        state = .Preparing
    }
    
    //Get a compute command encoder that you can use to send out compute commands
    //Preparing->Computing
    public func getComputeEncoder() -> MTLComputeCommandEncoder {
        
        //State machine check
        if (state != .Preparing) {
            fatalError("Invalid Command! Must be preparing current state is \(state)")
        }
        state = .Computing
        return ensure(buffer?.makeComputeCommandEncoder())
    }
    
    //Blur a texture by the ammount using metal preformance shaders
    //Preparing->Preparing
    public func blur(texture passIn: MTLTexture, ammount: CGFloat) {
        
        //State machine check
        if (state != .Preparing) {
            fatalError("Invalid Command! Must be preparing current state is \(state)")
        }
        
        //Make the blur the same no matter the resolution of the texture passed in
        let screenUnits = (ammount / (2.0 * 10.0)) * CGFloat(passIn.width)
        
        //Get the metal preformance shader kernel
        let kernel = MPSImageGaussianBlur(device: device!, sigma: Float(screenUnits))
        
        // not the safest way, but it works for brevity's sake
        var texture: MTLTexture = passIn
        
        //Blur it
        kernel.encode(commandBuffer: buffer!, inPlaceTexture: &texture, fallbackCopyAllocator: nil)
    }
    
    //Combine two textures additively giving them the weight multipliers. Strongly recommmend passing in your own texture to draw onto
    //Preparing->Preparing
    public func combine(blurred: MTLTexture, weight w1: Float, noise: MTLTexture, weight w2: Float, color: Color, onto: MTLTexture? = nil) -> MTLTexture {
        
        //State machine check
        if (state != .Preparing) {
            fatalError("Invalid Command! Must be preparing current state is \(state)")
        }
        
        
        let cpipeline = copy_pipeline!
        
        //If you gave us a texture we will use it if not we will create our own
        var ctex:MTLTexture!
        if let t = onto {
            ctex = t
        } else {
            ctex = TextureTools.createTexture(ofSize: CGFloat(max(blurred.width, noise.width)))
        }
        
        //Set the drawable
        setDrawable(to: ctex)
        
        //Get the encoder
        let render = getRenderEncoder()
        
        //Pass the textures into the gpu
        render.setRenderPipelineState(cpipeline)
        render.setFragmentTexture(blurred, index: 0)
        render.setFragmentTexture(noise, index: 1)
        
        //Copy the parameters and copy them into buffers to be used in the shader
        var c_weight1 = w1
        var c_weight2 = w2
        let intermediate = CIColor.convert(color: color)
        var color:float3 = float3(Float(intermediate.red), Float(intermediate.green), Float(intermediate.blue))
        render.setFragmentBytes(&c_weight1, length: MemoryLayout<Float>.stride, index: 0)
        render.setFragmentBytes(&c_weight2, length: MemoryLayout<Float>.stride, index: 1)
        render.setFragmentBytes(&color, length: MemoryLayout<float3>.stride, index: 2)
        
        //Draw full screen
        render.drawFullScreen()
        
        //Finish encoding
        finishEncoding(encoder: render)
        
        //Return what you drew on
        return ctex
    }
    
    //Views the alpha channel of a texture drawing it onto onto
    public func viewAlpha(texture: MTLTexture, onto: MTLTexture) {
        
        //State machine check
        if (state != .Preparing) {
            fatalError("Invalid Command! Must be preparing current state is \(state)")
        }
        shouldDrawBlank = false
        
        //Get the pipeiline
        let cpipeline = alpha_pipeline!
        
        //Grab a drawable
        setDrawable(to: onto)
        
        //Get a render encoder
        let render = getRenderEncoder()
        
        //Set the pipeline state
        render.setRenderPipelineState(cpipeline)
        
        //Pass in the texture
        render.setFragmentTexture(texture, index: 0)
        
        //GO!
        render.drawFullScreen()
        
        //Finish encoding everything
        finishEncoding(encoder: render)
    }
    
    //Clamps the texture's channels based on the wall and tolerance with smoothstep. Strongly recommmend passing in your own texture to draw onto
    public func clamp(texture: inout MTLTexture, wall: CGFloat, tolerance: CGFloat, onto: MTLTexture? = nil) {
        
        //State machine check
        if (state != .Preparing) {
            fatalError("Invalid Command! Must be preparing current state is \(state)")
        }
        
        //Get the pipeline for this
        let cpipeline = clamp_pipeline!
        
        //If you didnt specefiy a texture we will create one
        var clamped:MTLTexture!
        if let t = onto {
            clamped = t
        } else {
            clamped = TextureTools.createTexture(ofSize: CGFloat(max(texture.width, texture.width)))
        }
        
        //Set the drawable
        setDrawable(to: clamped)
        
        //Get a render encoder
        let render2 = getRenderEncoder()
        
        //Set the state
        render2.setRenderPipelineState(cpipeline)
        
        //Pass in the parameters to the gpu
        var wall:Float = Float(wall)
        var tolerance:Float = Float(tolerance)
        render2.setFragmentBytes(&wall, length: MemoryLayout<Float>.stride, index: 0)
        render2.setFragmentBytes(&tolerance, length: MemoryLayout<Float>.stride, index: 1)
        
        //Pass in the texture
        render2.setFragmentTexture(texture, index: 0)
        
        //Draw full screen
        render2.drawFullScreen()
        
        //Finish encoding
        finishEncoding(encoder: render2)
        
        //Returns the texture that was clamped
        texture = clamped
    }
    
    //Draw geometryt to a texture
    public func draw(geometry: VertexBufferCreator, to: MTLTexture) {
        
        //State machine check
        if (state != .Preparing) {
            fatalError("Invalid Command! Must be preparing current state is \(state)")
        }
        
        //Set the drawable
        setDrawable(to: to)
        
        //Get the pipeline
        let pipeline = draw_pipeline!
        
        //Get the render encoder
        let render =  getRenderEncoder()
        
        //Set the state
        render.setRenderPipelineState(pipeline)
        
        //Draw the geometry
        render.drawTriangles(buffer: geometry)
        
        //Finish up
        finishEncoding(encoder: render)
    }
    
    //Finish up the frame by synchronizing and commiting etc
    public func finishFrame() {
        
        //State machine check
        if (state != .Preparing) {
            fatalError("Invalid Command! Must be preparing current state is \(state)")
        }
        
        //If no commands are issued lets draw the clear color only
        if (shouldDrawBlank) {
            finishEncoding(encoder: getRenderEncoder())
        }
        
        //Clear the synchronize list
        synchronizeList = []
        
        
        //Commit the buffer
        buffer?.commit()
        
        //We do not exploit parallel cpu and gpu computation as it is confusing to playground user
        buffer?.waitUntilCompleted()
        
        //Return to idle
        state = .Idle
    }
}
