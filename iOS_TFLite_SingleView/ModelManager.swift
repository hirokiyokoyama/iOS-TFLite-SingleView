//
//  ModelManager.swift
//  iOS_SingleView_1
//
//  Created by 横山裕樹 on 2020/06/08.
//  Copyright © 2020 HirokiYokoyama. All rights reserved.
//

import CoreImage
import TensorFlowLite
import UIKit
//import Accelerate

struct Result {
    let time: Double
    let output: [Float32]
}
/// This class handles all data preprocessing and makes calls to run inference on a given frame
/// by invoking the `Interpreter`. It then formats the inferences obtained and returns the top N
/// results for a successful inference.
class ModelManager : NSObject {

  // MARK: - Internal Properties

  /// The current thread count used by the TensorFlow Lite Interpreter.
    let threadCount: Int

    let resultCount = 3
    let threadCountLimit = 10

  // MARK: - Model Parameters

    var inputShape : [Int]? {
        do {
            let inputTensor = try interpreter.input(at: 0)
            let dim = inputTensor.shape.dimensions
            return dim
        } catch let error {
            print("Failed to invoke the interpreter with error: \(error.localizedDescription)")
            return nil
        }
    }

    let modelFilename = "model"
    let modelExtension = "tflite"

    // MARK: - Private Properties

  /// List of labels from the given labels file.
    //private var labels: [String] = []

  /// TensorFlow Lite `Interpreter` object for performing inference on a given model.
    private var interpreter: Interpreter

  // MARK: - Initialization

  /// A failable initializer for `ModelDataHandler`. A new instance is created if the model and
  /// labels files are successfully loaded from the app's main bundle. Default `threadCount` is 1.
    init?(threadCount: Int = 1) {

        // Construct the path to the model file.
        guard let modelPath = Bundle.main.path(
          forResource: modelFilename,
          ofType: modelExtension
        ) else {
          print("Failed to load the model file with name: \(modelFilename).")
          return nil
        }

        // Specify the options for the `Interpreter`.
        self.threadCount = threadCount
        var options = Interpreter.Options()
        options.threadCount = threadCount
        do {
          // Create the `Interpreter`.
          interpreter = try Interpreter(modelPath: modelPath, options: options)
          // Allocate memory for the model's input `Tensor`s.
          try interpreter.allocateTensors()
        } catch let error {
          print("Failed to create the interpreter with error: \(error.localizedDescription)")
          return nil
        }
        // Load the classes listed in the labels file.
        //loadLabels(fileInfo: labelsFileInfo)
        super.init()
    }

    /// Performs image preprocessing, invokes the `Interpreter`, and processes the inference results.
    func runModel(onFrame frame: Data) -> Result? {
        let interval: TimeInterval
        let outputTensor: Tensor
        
        do {
            let inputTensor = try interpreter.input(at: 0)

            //let grayData = convertRGBtoGray(frame)

            let inputData: Data
            if inputTensor.dataType == .uInt8 {
                inputData = frame
            } else {
                inputData = convertToFloats(frame)
            }

            // Copy the RGB data to the input `Tensor`.
            try interpreter.copy(inputData, toInputAt: 0)

            // Run inference by invoking the `Interpreter`.
            let startDate = Date()
            try interpreter.invoke()
            interval = Date().timeIntervalSince(startDate) * 1000

            // Get the output `Tensor` to process the inference results.
            outputTensor = try interpreter.output(at: 0)
        } catch let error {
            print("Failed to invoke the interpreter with error: \(error.localizedDescription)")
            return nil
        }

        let output: [Float]

        switch outputTensor.dataType {
        case .uInt8:
            guard let outputQuantization = outputTensor.quantizationParameters else {
                    print("No results returned because the quantization values for the  output tensor are nil.")
                    return nil
            }
            let quantizedResults = [UInt8](outputTensor.data)
            output = quantizedResults.map {
                outputQuantization.scale * Float(Int($0) - outputQuantization.zeroPoint)
            }
        case .float32:
            output = [Float32](unsafeData: outputTensor.data) ?? []
        default:
            print("Output tensor data type \(outputTensor.dataType) is unsupported for this example app.")
            return nil
        }

        return Result(time: interval, output: output)
    }
    
    private func convertToFloats(_ byteData: Data) -> Data {
        let bytes = Array<UInt8>(unsafeData: byteData)!
        var floats = [Float]()
        for i in 0..<bytes.count {
            floats.append(Float(bytes[i]) / 255.0 * 2.0 - 1.0)
        }
        //return Data(copyingBufferOf: floats)
        return floats.withUnsafeBufferPointer(Data.init)
    }
    
    private func convertRGBtoGray(_ byteData: Data) -> Data {
        let bytes = Array<UInt8>(unsafeData: byteData)!
        var out = [UInt8]()
        for i in 0..<bytes.count/3 {
            let val = Float(bytes[i*3]) + Float(bytes[i*3+1]) + Float(bytes[i*3+2])
            out.append(UInt8(val/3.0))
        }
        return Data(copyingBufferOf: out)
        //return out.withUnsafeBufferPointer(Data.init)
    }
}

// MARK: - Extensions

extension Data {
    init<T>(copyingBufferOf array: [T]) {
        self = array.withUnsafeBufferPointer(Data.init)
    }
}

extension Array {
  /// Creates a new array from the bytes of the given unsafe data.
  ///
  /// - Warning: The array's `Element` type must be trivial in that it can be copied bit for bit
  ///     with no indirection or reference-counting operations; otherwise, copying the raw bytes in
  ///     the `unsafeData`'s buffer to a new array returns an unsafe copy.
  /// - Note: Returns `nil` if `unsafeData.count` is not a multiple of
  ///     `MemoryLayout<Element>.stride`.
  /// - Parameter unsafeData: The data containing the bytes to turn into an array.
  init?(unsafeData: Data) {
    guard unsafeData.count % MemoryLayout<Element>.stride == 0 else { return nil }
    #if swift(>=5.0)
    self = unsafeData.withUnsafeBytes { .init($0.bindMemory(to: Element.self)) }
    #else
    self = unsafeData.withUnsafeBytes {
      .init(UnsafeBufferPointer<Element>(
        start: $0,
        count: unsafeData.count / MemoryLayout<Element>.stride
      ))
    }
    #endif  // swift(>=5.0)
  }
}
