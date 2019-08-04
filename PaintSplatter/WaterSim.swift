//
//  WaterSim.swift
//  PaintSplatterIOS
//
//  Created by Caleb Kierum on 8/4/19.
//  Copyright © 2019 Caleb Kierum. All rights reserved.
//

import Metal
import MetalKit

//An enum storing queued up actions
//A central design of this is that any method may be called when the metal state is not preparing so safe those commands for later
enum Actions {
    case reset
    case paint(MTLTexture)
    case location(Point)
}

//The watercolor simulation itself
public class WatercolorSimulation {
    //Frame is used to switch between which texture is read and which is written
    private var frame:Int = 0
    
    //These textures switch of as read and write
    private var tex1:MTLTexture
    private var tex2:MTLTexture
    
    //The metal state we will use to draw
    private var state:metalState
    
    //Actions queued up until the state is preparing
    private var queue:[Actions] = []
    
    //The pipeline for stepping the simulation one frame
    private var step:MTLRenderPipelineState
    
    //The pipeline for clearing the simulation
    private var clear:MTLRenderPipelineState
    
    //The pipeline for painting a splat
    private var paint:MTLRenderPipelineState
    
    //Stores how many simulate calls are queued up
    private var simQueue:Int = 0
    
    //The texture the splatter will be drawn to
    private var splatterTexture:MTLTexture
    
    //Stores the two noise textures
    private var noise1:MTLTexture
    private var noise2:MTLTexture
    
    //These two textures are buffers used for various purposes
    private var combTex:MTLTexture
    private var combTex2:MTLTexture
    
    //Initialize this with a resolution and a metal state object to work wtih
    public init(state: metalState, resolution: CGFloat) {
        
        //Initialize all of the textures
        tex1 = TextureTools.createTexture(ofSize: resolution)
        tex2 = TextureTools.createTexture(ofSize: resolution)
        splatterTexture = TextureTools.createTexture(ofSize: resolution)
        combTex = TextureTools.createTexture(ofSize: resolution)
        combTex2 = TextureTools.createTexture(ofSize: resolution)
        
        //Save the passed in metal state
        self.state = state
        
        //Read the shaders from Water.metal
        let library = ensure(metalState.sharedDevice?.makeDefaultLibrary())
        
        //Get the functions
        let s_vertex = ensure(library.makeFunction(name: "main_vertex"))
        let s_clear = ensure(library.makeFunction(name: "clear"))
        let s_paint = ensure(library.makeFunction(name: "paint"))
        let s_simulate = ensure(library.makeFunction(name: "step"))
        
        //Create the pipelines for everytihng
        step = state.createRenderPipeline(vertex: s_vertex, fragment: s_simulate)
        clear = state.createRenderPipeline(vertex: s_vertex, fragment: s_clear)
        paint = state.createRenderPipeline(vertex: s_vertex, fragment: s_paint)
        
        //Load up the two noise images
        noise1 = TextureTools.loadTexture(named: "NewNoise")
        noise2 = TextureTools.loadTexture(named: "natural")
        
        //Reset the simulation
        reset()
    }
    
    //Makes the canvas white with no wetness
    public func reset() {
        
        //State check!
        if (state.getState() == .Preparing) {
            
            //get the ouput texture
            let output = getOutput()
            
            //Set the drawable to it
            state.setDrawable(to: output)
            
            //Get the command encoder
            let render = state.getRenderEncoder()
            
            //Set the state to the shader
            render.setRenderPipelineState(clear)
            
            //Draw
            render.drawFullScreen()
            
            //Finish encoding
            state.finishEncoding(encoder: render)
            
            //Increase frame by one
            frame += 1
        } else {
            //We are in the wrong state so queue it up
            queue = []
            queue.append(.reset)
        }
    }
    
    //Craetes a paintsplatter at the position and draws it to the canvas
    public func paintSplatter(pos: Point) {
        
        //State check!
        if (state.getState() == .Preparing) {
            
            //Create a splat geometry
            let buffer2 = GeometryCreator.splat(center: pos, color: Color.white)
            
            //Draw it to the texture
            state.draw(geometry: buffer2, to: splatterTexture)
            
            //Blur that texture
            state.blur(texture: splatterTexture, ammount: SplatConstants.blurAmmount)
            
            //Add noise one
            let textua1 = state.combine(blurred: splatterTexture, weight: 1.0, noise: noise1, weight: Float(SplatConstants.noise1Contrib), color: Color.white, onto: combTex)
            
            //Add noise two
            var textua2 = state.combine(blurred: textua1, weight: 1.0, noise: noise2, weight: Float(SplatConstants.noise2Contrib), color: Color.white, onto: combTex2)
            
            //Clamp the result//0.82 0 dsf ssdfsf
            state.clamp(texture: &textua2, wall: SplatConstants.clampCenter, tolerance: SplatConstants.clampTolerance, onto: combTex)
            
            //Paint onto the canvas (calls water state internal function)
            paint(texture: textua2)
        } else {
            //We are in the wrong state so queue it up
            queue.append(.location(pos))
        }
    }
    
    //Paints a paint splatter texture 'texture' onto the canvas
    public func paint(texture: MTLTexture) {
        
        //State check!
        if (state.getState() == .Preparing) {
            
            //Get a random color for the splatter
            let splatColor = randomColor()
            
            //Get the input and output texture
            let input = getInput()
            let output = getOutput()
            
            //Set the drawable
            state.setDrawable(to: output)
            
            //Set the encoder
            let render = state.getRenderEncoder()
            
            //Set to state
            render.setRenderPipelineState(paint)
            
            //Pass in the previous canvas and the splatter texture
            render.setFragmentTexture(input, index: 0)
            render.setFragmentTexture(texture, index: 1)
            
            //Pass in the color to the shader
            let intermediate = CIColor.convert(color: splatColor)
            var color:float3 = float3(Float(intermediate.red), Float(intermediate.green), Float(intermediate.blue))
            render.setFragmentBytes(&color, length: MemoryLayout<float3>.stride, index: 0)
            var wet:Float = Float(WaterSimConstants.splatWetness)
            render.setFragmentBytes(&wet, length: MemoryLayout<Float>.stride, index: 1)
            
            
            //Draw full screen
            render.drawFullScreen()
            
            //Finish encoding
            state.finishEncoding(encoder: render)
            
            //Increase the frame
            frame += 1
        } else {
            //We are in the wrong state so queue it up
            queue.append(.paint(texture))
        }
    }
    
    //Steps the water simulation by one frame
    public func simulate() -> MTLTexture? {
        
        //Queue up another simulation incase this goes bad
        simQueue += 4
        
        //State check
        if (state.getState() != .Preparing) {
            return nil
        } else {
            
            //Go through the instruciton queue and do everything
            for instruction in queue {
                switch instruction {
                case .reset:
                    reset()
                case let .paint(tex):
                    paint(texture: tex)
                case let .location(pos):
                    paintSplatter(pos: pos)
                }
                
            }
            
            //We have emptied the queue
            queue = []
            
            //If we have simulations queued up (should be at least one) then do them
            var output:MTLTexture? = nil
            for _ in 0..<simQueue {
                //Get the input and output textures
                let input = getInput()
                output = getOutput()
                
                //Set the drawable to a texture to the output
                state.setDrawable(to: output!)
                
                //Get the render encoder
                let render = state.getRenderEncoder()
                
                var in_ld:Float = Float(WaterSimConstants.lookDistance)
                render.setFragmentBytes(&in_ld, length: MemoryLayout<Float>.stride, index: 0)
                var in_os:Float = Float(WaterSimConstants.overflowStrength)
                render.setFragmentBytes(&in_os, length: MemoryLayout<Float>.stride, index: 1)
                var in_db:Float = Float(WaterSimConstants.diffusionBoost)
                render.setFragmentBytes(&in_db, length: MemoryLayout<Float>.stride, index: 2)
                var in_ds:Float = Float(WaterSimConstants.drySpeed)
                render.setFragmentBytes(&in_ds, length: MemoryLayout<Float>.stride, index: 3)
                var in_cs:Float = Float(WaterSimConstants.colorSpread)
                render.setFragmentBytes(&in_cs, length: MemoryLayout<Float>.stride, index: 4)
                
                //Set the pipeline
                render.setRenderPipelineState(step)
                
                //Pass in the canvas
                render.setFragmentTexture(input, index: 0)
                
                //Draw full screen
                render.drawFullScreen()
                
                //Finish encoding
                state.finishEncoding(encoder: render)
                
                //Increase the frame
                frame += 1
            }
            
            //Reset the queue conter and return the result
            simQueue = 0
            return output
        }
    }
    
    //Get the input texture (switches the textures from role as input textures and output textures)
    private func getInput() -> MTLTexture {
        if (frame % 2 == 0) {
            return tex1
        } else {
            return tex2
        }
    }
    
    //Get the output texture (switches the textures from role as input textures and output textures)
    private func getOutput() -> MTLTexture {
        if (frame % 2 == 1) {
            return tex1
        } else {
            return tex2
        }
    }
    
}
