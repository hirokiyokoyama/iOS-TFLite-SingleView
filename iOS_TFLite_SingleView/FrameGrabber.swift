//
//  FrameGrabber.swift
//  ConcreteFlow_iOS
//
//  Created by 横山裕樹 on 2020/07/01.
//  Copyright © 2020 HirokiYokoyama. All rights reserved.
//

import AVFoundation
import Accelerate

class FrameGrabber: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var frameSize: CGSize?
    var lastCaptureTime: Date?
    //var onBatchReady: (([Data])->())?
    var boundingBox: CGRect?
    var destinationSize: CGSize?

    var batchSize: Int
    var maxBufferSize: Int
    private var buffer: [Data] = .init()
    private var bufferQueue: DispatchQueue
    private var bufferSemaphore: DispatchSemaphore
    
    init(batchSize: Int, maxBufferSize: Int = 128) {
        self.batchSize = batchSize
        self.maxBufferSize = maxBufferSize
        bufferQueue = DispatchQueue(label: "FrameGrabber.bufferQueue")
        bufferSemaphore = DispatchSemaphore(value: 0)
    }
    
    func getBatch() -> [Data]? {
        return bufferQueue.sync {
            let prefix = buffer.prefix(batchSize)
            if prefix.count < batchSize {
                return nil
            }
            buffer.removeFirst()
            return prefix.map { $0 }
        }
    }
    
    func waitForBatch() -> [Data] {
        while true {
            bufferSemaphore.wait()
            if let batch = getBatch() {
                return batch
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        let captureTime = Date()
        if let last = lastCaptureTime {
            let interval = captureTime.timeIntervalSince(last) * 1000
            print("Frame interval: \(Int(interval))ms")
        }
        lastCaptureTime = captureTime

        // Converts the CMSampleBuffer to a CVPixelBuffer.
        let pixelBuffer: CVPixelBuffer? = CMSampleBufferGetImageBuffer(sampleBuffer)

        guard let imagePixelBuffer = pixelBuffer else {
            print("Failed to get pixel data.")
            return
        }
        
        let width = CVPixelBufferGetWidth(imagePixelBuffer)
        let height = CVPixelBufferGetHeight(imagePixelBuffer)
        frameSize = CGSize(width: CGFloat(width), height: CGFloat(height))

        guard let bb = boundingBox else { return }
        guard let size = destinationSize else { return }

        let _rgbData = rgbDataFromBuffer(imagePixelBuffer,
                                        bounds: bb,
                                        size: size)
        
        guard let rgbData = _rgbData else { return }
        bufferQueue.sync {
            buffer.append(rgbData)
            if buffer.count > maxBufferSize {
                buffer.removeFirst()
            }
        }
        bufferSemaphore.signal()
        //if let onBatchReady = self.onBatchReady {
        //    onBatchReady(buffer)
        //}
    }

    private func rgbDataFromBuffer(
      _ buffer: CVPixelBuffer,
      bounds: CGRect,
      size: CGSize
    ) -> Data? {
      CVPixelBufferLockBaseAddress(buffer, .readOnly)
      defer {
        CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
      }

      let pixelBufferFormat = CVPixelBufferGetPixelFormatType(buffer)
      assert(pixelBufferFormat == kCVPixelFormatType_32BGRA)

      let originX = Int(bounds.origin.x)
      let originY = Int(bounds.origin.y)
      let sourceChannels = 4
      let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
      let cropBytesPerRow = sourceChannels * Int(size.width)
      let destinationChannels = 3
      let destinationBytesPerRow = destinationChannels * Int(size.width)

      guard let sourceData = CVPixelBufferGetBaseAddress(buffer)?.advanced(
          by: originY * sourceBytesPerRow + originX * sourceChannels) else {
        return nil
      }
      
      var sourceBuffer = vImage_Buffer(data: sourceData,
                                       height: vImagePixelCount(bounds.size.height),
                                       width: vImagePixelCount(bounds.size.width),
                                       rowBytes: sourceBytesPerRow)
      
      guard let cropData = malloc(Int(size.height) * cropBytesPerRow) else {
        print("Error: out of memory")
        return nil
      }
      defer {
          free(cropData)
      }
      
      var cropBuffer = vImage_Buffer(data: cropData,
                                     height: vImagePixelCount(size.height),
                                     width: vImagePixelCount(size.width),
                                     rowBytes: cropBytesPerRow)
      
      let scaleError = vImageScale_ARGB8888(&sourceBuffer, &cropBuffer, nil, vImage_Flags(0))
      guard scaleError == kvImageNoError else {
        return nil
      }

      guard let destinationData = malloc(Int(size.height) * destinationBytesPerRow) else {
        print("Error: out of memory")
        return nil
      }
      defer {
          free(destinationData)
      }

      var destinationBuffer = vImage_Buffer(data: destinationData,
                                            height: vImagePixelCount(size.height),
                                            width: vImagePixelCount(size.width),
                                            rowBytes: destinationBytesPerRow)

      let convertError = vImageConvert_BGRA8888toRGB888(&cropBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
      guard convertError == kvImageNoError else {
          return nil
      }

      let byteData = Data(bytes: destinationBuffer.data, count: destinationBuffer.rowBytes * Int(size.height))
      return byteData
    }
}
