//
//  main.swift
//  ParallelDP
//
//  Created by Jiheng Zhang on 1/1/2016.
//  Copyright © 2016 verse. All rights reserved.
//

import Foundation
import MetalKit

// parameter setting for DP
let T = 2  // periods
let K = 8  // capacity
let L = 3  // dimension

// parameters needs to be transmitted to device
let paramemterVector: [Float] = [
    2,           // order cost
    1,              // deplete cost
    1,              // salvage value
    0.95            // discount rate
]

let holdCost: Float = 1.11
let depleteCost: Float = 1
let orderCost: Float = 1
let rate: Float = 0.95

// basic calcuation of buffer
let numberOfStates = Int(pow(Double(K), Double(L)))
let unitSize = sizeof(Float)
let resultBufferSize = numberOfStates*unitSize

// hardcoded to 512 for now (recommendation: read about threadExecutionWidth)
let threadExecutionWidth = 128
let numThreadsPerGroup = MTLSize(width:threadExecutionWidth,height:1,depth:1)
let numGroups = MTLSize(width:(resultBufferSize+threadExecutionWidth-1)/threadExecutionWidth, height:1, depth:1)

// Initialize Metal
var device: MTLDevice! = MTLCreateSystemDefaultDevice()
// Build command queue
var commandQueue: MTLCommandQueue! = device.newCommandQueue()

// Allocate memory on device
let resourceOption = MTLResourceOptions()
var buffer:[MTLBuffer] = [
    device.newBufferWithLength(resultBufferSize, options: resourceOption),
    device.newBufferWithLength(resultBufferSize, options: resourceOption)
]
var parameterBuffer:MTLBuffer = device.newBufferWithBytes(paramemterVector, length: unitSize*paramemterVector.count, options: resourceOption)

// Get functions from Shaders and add to MTL library
var defaultLibrary: MTLLibrary! = device.newDefaultLibrary()
let initDP = defaultLibrary.newFunctionWithName("initialize")
let iterateDP = defaultLibrary.newFunctionWithName("iterate")

// Initialize
var commandBufferInitDP: MTLCommandBuffer! = commandQueue.commandBuffer()
var encoderInitDP = commandBufferInitDP.computeCommandEncoder()
var pipelineFilterInit = try device.newComputePipelineStateWithFunction(initDP!)
encoderInitDP.setComputePipelineState(pipelineFilterInit)
encoderInitDP.setBuffer(buffer[0], offset: 0, atIndex: 0)
encoderInitDP.setBuffer(parameterBuffer, offset: 0, atIndex: 2)
encoderInitDP.dispatchThreadgroups(numThreadsPerGroup, threadsPerThreadgroup: numGroups)
encoderInitDP.endEncoding()
commandBufferInitDP.commit()
commandBufferInitDP.waitUntilCompleted()

// Iterate T periods
// It's import that t starts from 0%2=0, since we start with buffer[0]
for t in 0..<T {
    
    var commandBufferIterateDP: MTLCommandBuffer! = commandQueue.commandBuffer()
    var encoderIterateDP = commandBufferIterateDP.computeCommandEncoder()
    var pipelineFilterIterate = try device.newComputePipelineStateWithFunction(iterateDP!)
    encoderIterateDP.setComputePipelineState(pipelineFilterIterate)
    
    encoderIterateDP.setBuffer(buffer[t%2], offset: 0, atIndex: 0)
    encoderIterateDP.setBuffer(buffer[(t+1)%2], offset: 0, atIndex: 1)
    encoderIterateDP.setBuffer(parameterBuffer, offset: 0, atIndex: 2)
    
    encoderIterateDP.dispatchThreadgroups(numThreadsPerGroup, threadsPerThreadgroup: numGroups)
    encoderIterateDP.endEncoding()
    commandBufferIterateDP.commit()
    commandBufferIterateDP.waitUntilCompleted()

}

// a. Get GPU data
var data = NSData(bytesNoCopy: buffer[T%2].contents(), length: resultBufferSize, freeWhenDone: false)
// b. prepare Swift array large enough to receive data from GPU
var finalResultArray = [Float](count: numberOfStates, repeatedValue: 0)
// c. get data from GPU into Swift array
data.getBytes(&finalResultArray, length:resultBufferSize)

print(finalResultArray)

