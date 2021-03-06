//
//  BufferProvider.swift
//  Model_IO_OSX
//
//  Created by Andriy K. on 6/20/15.
//  Copyright © 2015 Andriy K. All rights reserved.
//

import Cocoa
import simd
import Accelerate

/// This class is responsible for providing a uniformBuffer which will be passed to vertex shader. It holds n buffers. In case n == 3 for frame0 it will give buffer0 for frame1 - buffer1 for frame2 - buffer2 for frame3 - buffer0 and so on. It's user responsibility to make sure that GPU is not using that buffer before use. For details refer to wwdc session 604 (18:00).

class BufferProvider: NSObject {
  
  static let floatSize = sizeof(Float)
  static let floatsPerMatrix = 16
  static let numberOfMatrices = 2
  
  static let boolSize = sizeof(Bool)
  
  static var bufferSize: Int {
    return (matrixSize * numberOfMatrices) + (16)
  }
  
  static var matrixSize: Int {
    return floatSize * floatsPerMatrix
  }
  
  private(set) var indexOfAvaliableBuffer = 0
  private(set) var numberOfInflightBuffers: Int
  private var buffers:[MTLBuffer]
  
  private(set) var avaliableResourcesSemaphore:dispatch_semaphore_t
  
  init(inFlightBuffers: Int, device: MTLDevice) {
    
    avaliableResourcesSemaphore = dispatch_semaphore_create(inFlightBuffers)
    
    numberOfInflightBuffers = inFlightBuffers
    buffers = [MTLBuffer]()
    for (var i = 0; i < inFlightBuffers; i++) {
      let buffer = device.newBufferWithLength(BufferProvider.bufferSize, options: MTLResourceOptions.CPUCacheModeDefaultCache)
      buffer.label = "Uniform buffer"
      buffers.append(buffer)
    }
  }
  
  deinit{
    for _ in 0...numberOfInflightBuffers{
      dispatch_semaphore_signal(avaliableResourcesSemaphore)
    }
  }
  
  func bufferWithMatrices(projectionMatrix: Matrix4, modelViewMatrix: Matrix4, b0: Bool, b1: Bool) -> MTLBuffer {
    
    let uniformBuffer = self.buffers[indexOfAvaliableBuffer++]
    if indexOfAvaliableBuffer == numberOfInflightBuffers {
      indexOfAvaliableBuffer = 0
    }
        
    let size = BufferProvider.matrixSize
    memcpy(uniformBuffer.contents(), projectionMatrix.raw(), size)
    memcpy(uniformBuffer.contents() + size, modelViewMatrix.raw(), size)
    
    let params = [b0, b1]
    memcpy(uniformBuffer.contents() + 2*size, params, BufferProvider.boolSize * params.count)
    
    return uniformBuffer
  }
  
}
