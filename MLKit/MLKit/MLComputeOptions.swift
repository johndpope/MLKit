//
//  MLComputeOptions.swift
//  MLKit
//
//  Created by Kesav Mulakaluri on 12/22/15.
//  Copyright © 2015 Kesav Mulakaluri. All rights reserved.
//

import Foundation

/// Describes how to perform matrix computations.
public enum MLComputeMode {
    /// Perform computations on the CPU using the Accelerate framework.
    case CPU
    
    /// Perform computations on the GPU using the Metal framework.
    case GPU
}

/// Used to specify how computations should be carried out on the device.
public struct MLComputeOptions {
    
    /// The current `MLComputeMode`. Defaults to CPU.
    public static var computeMode: MLComputeMode = .CPU
    
    /// Returns the appropriate `MLComputeDevice` for the current `MLComputeMode`.
    public static var computeDevice: MLComputeDevice {
        switch computeMode {
        case .CPU:
            return CPU()
        case .GPU:
            return GPU.deviceGPU
        }
    }
}


// MARK: - Convenience Functions

/// Sets the current `MLComputeMode` to `computeMode`.
public func MLSetComputeMode(computeMode: MLComputeMode) {
    MLComputeOptions.computeMode = computeMode
}

/// Gets the current `MLComputeMode`.
public func MLGetComputeMode() -> MLComputeMode {
    return MLComputeOptions.computeMode
}

/// Gets the `MLComputeDevice` for the current `MLComputeMode`.
public func MLGetComputeDevice() -> MLComputeDevice {
    return MLComputeOptions.computeDevice
}