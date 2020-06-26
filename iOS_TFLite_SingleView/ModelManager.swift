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
import Accelerate

struct Result {
    let time: Double
    let prediction: [Float32]
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

    let batchSize = 1
    let inputChannels = 3
    let inputWidth = 256
    let inputHeight = 256

    let modelFilename = "model"
    let modelExtension = "tflite"

    // MARK: - Private Properties

  /// List of labels from the given labels file.
    //private var labels: [String] = []

  /// TensorFlow Lite `Interpreter` object for performing inference on a given model.
    private var interpreter: Interpreter

  /// Information about the alpha component in RGBA data.
    private let alphaComponent = (baseOffset: 4, moduloRemainder: 3)

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

  // MARK: - Internal Methods

    /// Performs image preprocessing, invokes the `Interpreter`, and processes the inference results.
    func runModel(onFrame pixelBuffer: CVPixelBuffer) -> Result? {

        let sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        assert(sourcePixelFormat == kCVPixelFormatType_32ARGB ||
                 sourcePixelFormat == kCVPixelFormatType_32BGRA ||
                   sourcePixelFormat == kCVPixelFormatType_32RGBA)


        let imageChannels = 4
        assert(imageChannels >= inputChannels)

        // Crops the image to the biggest square in the center and scales it down to model dimensions.
        let scaledSize = CGSize(width: inputWidth, height: inputHeight)
        guard let thumbnailPixelBuffer = pixelBuffer.centerThumbnail(ofSize: scaledSize) else {
          print("Failed to crop the image.")
          return nil
        }

        let interval: TimeInterval
        let outputTensor: Tensor
        do {
          let inputTensor = try interpreter.input(at: 0)

          // Remove the alpha component from the image buffer to get the RGB data.
          guard let rgbData = rgbDataFromBuffer(
            thumbnailPixelBuffer,
            byteCount: batchSize * inputWidth * inputHeight * inputChannels,
            isModelQuantized: inputTensor.dataType == .uInt8
          ) else {
            print("Failed to convert the image buffer to RGB data.")
            return nil
          }

          // Copy the RGB data to the input `Tensor`.
          try interpreter.copy(rgbData, toInputAt: 0)

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

        let results: [Float]
        switch outputTensor.dataType {
        case .uInt8:
          guard let quantization = outputTensor.quantizationParameters else {
            print("No results returned because the quantization values for the output tensor are nil.")
            return nil
          }
          let quantizedResults = [UInt8](outputTensor.data)
          results = quantizedResults.map {
            quantization.scale * Float(Int($0) - quantization.zeroPoint)
          }
        case .float32:
          results = [Float32](unsafeData: outputTensor.data) ?? []
        default:
          print("Output tensor data type \(outputTensor.dataType) is unsupported for this example app.")
          return nil
        }

        return Result(time: interval, prediction: results)
    }

  // MARK: - Private Methods

  /// Returns the RGB data representation of the given image buffer with the specified `byteCount`.
  ///
  /// - Parameters
  ///   - buffer: The pixel buffer to convert to RGB data.
  ///   - byteCount: The expected byte count for the RGB data calculated using the values that the
  ///       model was trained on: `batchSize * imageWidth * imageHeight * componentsCount`.
  ///   - isModelQuantized: Whether the model is quantized (i.e. fixed point values rather than
  ///       floating point values).
  /// - Returns: The RGB data representation of the image buffer or `nil` if the buffer could not be
  ///     converted.
  private func rgbDataFromBuffer(
    _ buffer: CVPixelBuffer,
    byteCount: Int,
    isModelQuantized: Bool
  ) -> Data? {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer {
      CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
    }
    guard let sourceData = CVPixelBufferGetBaseAddress(buffer) else {
      return nil
    }
    
    let width = CVPixelBufferGetWidth(buffer)
    let height = CVPixelBufferGetHeight(buffer)
    let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
    let destinationChannelCount = 3
    let destinationBytesPerRow = destinationChannelCount * width
    
    var sourceBuffer = vImage_Buffer(data: sourceData,
                                     height: vImagePixelCount(height),
                                     width: vImagePixelCount(width),
                                     rowBytes: sourceBytesPerRow)
    
    guard let destinationData = malloc(height * destinationBytesPerRow) else {
      print("Error: out of memory")
      return nil
    }
    
    defer {
        free(destinationData)
    }

    var destinationBuffer = vImage_Buffer(data: destinationData,
                                          height: vImagePixelCount(height),
                                          width: vImagePixelCount(width),
                                          rowBytes: destinationBytesPerRow)

    let pixelBufferFormat = CVPixelBufferGetPixelFormatType(buffer)

    switch (pixelBufferFormat) {
    case kCVPixelFormatType_32BGRA:
        vImageConvert_BGRA8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
    case kCVPixelFormatType_32ARGB:
        vImageConvert_ARGB8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
    case kCVPixelFormatType_32RGBA:
        vImageConvert_RGBA8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
    default:
        // Unknown pixel format.
        return nil
    }

    let byteData = Data(bytes: destinationBuffer.data, count: destinationBuffer.rowBytes * height)
    if isModelQuantized {
        return byteData
    }

    // Not quantized, convert to floats
    let bytes = Array<UInt8>(unsafeData: byteData)!
    var floats = [Float]()
    for i in 0..<bytes.count {
        floats.append(Float(bytes[i]) / 255.0)
    }
    return Data(copyingBufferOf: floats)
  }
}

// MARK: - Extensions

extension Data {
  /// Creates a new buffer by copying the buffer pointer of the given array.
  ///
  /// - Warning: The given array's element type `T` must be trivial in that it can be copied bit
  ///     for bit with no indirection or reference-counting operations; otherwise, reinterpreting
  ///     data from the resulting buffer has undefined behavior.
  /// - Parameter array: An array with elements of type `T`.
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
