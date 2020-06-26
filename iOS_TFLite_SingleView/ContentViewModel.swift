//
//  ContentViewModel.swift
//  iOS_SingleView_1
//
//  Created by 横山裕樹 on 2020/06/09.
//  Copyright © 2020 HirokiYokoyama. All rights reserved.
//

import AVFoundation

class ContentViewModel : NSObject, ObservableObject {
    var cameraManager: CameraManager? = nil
    var modelManager: ModelManager? = nil
    @Published var resultText: String = "NoData"

    override init() {
        super.init()
        modelManager = ModelManager()
        cameraManager = CameraManager(sampleBufferDelegate: self)
    }
}

extension ContentViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        // Converts the CMSampleBuffer to a CVPixelBuffer.
        let pixelBuffer: CVPixelBuffer? = CMSampleBufferGetImageBuffer(sampleBuffer)

        guard let imagePixelBuffer = pixelBuffer else {
            print("Failed to get pixel data.")
            return
        }
        
        DispatchQueue.main.async {
            let result = self.modelManager?.runModel(onFrame: imagePixelBuffer)
            if let result = result {
                let pred = result.prediction
                let time = result.time
                self.resultText = "mean=(\(pred[0]),  \(pred[1]), \(pred[2]))\ntime=\(time)ms"
            } else {
                self.resultText = "No data"
            }
        }
    }
}
