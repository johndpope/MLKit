//
//  GPU.swift
//  MLKit
//
//  Created by Kesav Mulakaluri on 12/19/15.
//  Copyright © 2015 Kesav Mulakaluri. All rights reserved.
//

import Foundation
import Metal

/// GPU is a light weight wrapper around Metal to perform efficient
/// matrix computations.
class GPU: MLComputeDevice {
    
    /// The shared instance used to get access to the GPU.
    static let deviceGPU = GPU()
    
    /// The abstraction for the GPU.
    private let device: MTLDevice
    
    /// A collection of all the shaders in MLKit.
    private let library: MTLLibrary
    
    /// The queue that contains all the commands that need to be executed on
    /// the GPU.
    private let commandQueue: MTLCommandQueue
    
    
    // MARK: - Initializers
    
    private init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Unable to create MTLDevice.")
        }
        
        // When a project using Metal is built, all the .metal files will be compiled
        // into a file called default.metallib. Normally, Metal will look in the
        // app's main bundle for this resource, but Frameworks have a different
        // bundle structure and store their resources under 
        // /Versions/<Current Version>/Resources so grab the path to it and load
        // from there.
        let bundle = NSBundle(forClass: GPU.self)
        guard let libraryURL = bundle.URLForResource("default", withExtension: "metallib", subdirectory: "Versions/A/Resources"),
              let libraryPath = libraryURL.path else {
            fatalError("Unable to find default metallib")
        }
        
        guard let library = try? device.newLibraryWithFile(libraryPath) else {
            fatalError("Unable to create MTLLibrary.")
        }
        
        self.device = device
        self.library = library
        self.commandQueue = device.newCommandQueue()
    }

    
    // MARK: - Matrix Operations
    
    /// Returns `a` + `b`.
    func addMatrices(a a: Matrix, b: Matrix) -> Matrix {        
        let result = applyMatrixMatrixShader("matrix_add", a: a, b: b)
        return result
    }
    
    /// Returns `a` - `b`.
    func subtractMatrices(a a: Matrix, b: Matrix) -> Matrix {        
        let result = applyMatrixMatrixShader("matrix_subtract", a: a, b: b)
        return result
    }
    
    /// Returns `a` * `b`.
    func multiplyMatrices(a a: Matrix, b: Matrix) -> Matrix {
        return a
    }
    
    /// Multiplies each element in `a` by `c`.
    func scaleMatrix(a: Matrix, by c: Float) ->  Matrix {
        let result = applyMatrixConstShader("matrix_scale", a: a, c: c)
        return result
    }
    
    /// Applies the sigmoid function to each element in `a`.
    func applySigmoid(a: Matrix) -> Matrix {
        return a
    }
    
    
    // MARK: - Private Methods
    
    /// Loads a compute shader from the GPU's shader library.
    ///
    /// - parameter shader: The name of the compute shader to load.
    ///
    /// - returns: The `MTLComputePipelineState` associated with `shader`.
    private func loadComputeShader(shader: String) -> MTLComputePipelineState {
        guard let scalingFunction = library.newFunctionWithName(shader) else {
            fatalError("No shader named \(shader).")
        }
        
        guard let pipeline = try? device.newComputePipelineStateWithFunction(scalingFunction) else {
            fatalError("Could not create compute pipeline with the \(shader) shader.")
        }
        
        return pipeline
    }
    
    private func applyMatrixMatrixShader(shader: String, a: Matrix, b: Matrix) -> Matrix {
        // Get the shader and configure the command encoder.
        let pipeline = loadComputeShader(shader)
        let commandBuffer = commandQueue.commandBuffer()
        let commandEncoder = commandBuffer.computeCommandEncoder()
        commandEncoder.setComputePipelineState(pipeline)
        
        // Load the data into MTLBuffers the shader can access.
        let inputA = a.elements
        let inputB = b.elements
        let output = [Float](count: a.rows * b.columns, repeatedValue: 0)
        
        let inputBufferA = device.newBufferWithContents(inputA)
        let inputBufferB = device.newBufferWithContents(inputB)
        let outputBuffer = device.newBufferWithContents(output)
        commandEncoder.setBuffer(inputBufferA, offset: 0, atIndex: 0)
        commandEncoder.setBuffer(inputBufferB, offset: 0, atIndex: 1)
        commandEncoder.setBuffer(outputBuffer, offset: 0, atIndex: 2)
        
        // Set the number of threads to be executed in parallel.
        let execWidth = pipeline.threadExecutionWidth
        let threadsPerGroup = MTLSize(width: execWidth, height: 1, depth: 1)
        let numThreadGroups = MTLSize(width: (output.count + execWidth)/threadsPerGroup.width, height: 1, depth: 1)
        commandEncoder.dispatchThreadgroups(numThreadGroups, threadsPerThreadgroup: threadsPerGroup)
        
        // Commit the computations to the GPU and wait for it to finish.
        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Grab the data from the from the MTLBuffer and return the new scaled
        // matrix.
        let size = output.count * sizeof(Float)
        let data = NSData(bytesNoCopy: outputBuffer.contents(), length: size, freeWhenDone: false)
        var result = [Float](count: output.count, repeatedValue: 0)
        data.getBytes(&result, length: size)
        
        return Matrix(rows: a.rows, columns: a.columns, elements: result)
    }
    
    private func applyMatrixConstShader(shader: String, a: Matrix, c: Float) -> Matrix {
        // Get the shader and configure the command encoder.
        let pipeline = loadComputeShader(shader)
        let commandBuffer = commandQueue.commandBuffer()
        let commandEncoder = commandBuffer.computeCommandEncoder()
        commandEncoder.setComputePipelineState(pipeline)
        
        // Load the data into MTLBuffers the shader can access.
        var scalingFactor = c
        let input = a.elements
        let output = [Float](count: a.elements.count, repeatedValue: 0)
        let size = a.elements.count * sizeof(Float)
        
        let inputBuffer = device.newBufferWithContents(input)
        let outputBuffer = device.newBufferWithContents(output)
        commandEncoder.setBytes(&scalingFactor, length: sizeof(Float), atIndex: 0)
        commandEncoder.setBuffer(inputBuffer, offset: 0, atIndex: 1)
        commandEncoder.setBuffer(outputBuffer, offset: 0, atIndex: 2)
        
        // Set the number of threads to be executed in parallel.
        let execWidth = pipeline.threadExecutionWidth
        let threadsPerGroup = MTLSize(width: execWidth, height: 1, depth: 1)
        let numThreadGroups = MTLSize(width: (input.count + execWidth)/threadsPerGroup.width, height: 1, depth: 1)
        commandEncoder.dispatchThreadgroups(numThreadGroups, threadsPerThreadgroup: threadsPerGroup)
        
        // Commit the computations to the GPU and wait for it to finish.
        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        // Grab the data from the from the MTLBuffer and return the new scaled
        // matrix.
        let data = NSData(bytesNoCopy: outputBuffer.contents(), length: size, freeWhenDone: false)
        var result = [Float](count: output.count, repeatedValue: 0)
        data.getBytes(&result, length: size)
        
        return Matrix(rows: a.rows, columns: a.columns, elements: result)
    }
}


// MARK: - MTLDevice Extensions

extension MTLDevice {
    
    /// Creates a new `MTLBuffer` with the specified contents.
    func newBufferWithContents(contents: [Float]) -> MTLBuffer {
        let size = contents.count * sizeof(Float)
        return newBufferWithBytes(contents, length: size, options: .StorageModePrivate)
    }
}
