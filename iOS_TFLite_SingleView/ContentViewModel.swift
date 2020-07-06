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
    var frameGrabber: FrameGrabber
    var processingQueue: DispatchQueue
    @Published var boundingBox: CGRect?
    @Published var resultText: String = "Initializing"

    override init() {
        modelManager = ModelManager()
        frameGrabber = FrameGrabber(batchSize: 1)
        cameraManager = CameraManager(sampleBufferDelegate: frameGrabber)
        processingQueue = DispatchQueue(label: "InferenceQueue")
        super.init()

        if let shape = modelManager?.inputShape {
            print(shape)
            frameGrabber.destinationSize = CGSize(width: shape[2], height: shape[1])
            startProcessing()
        }
    }
    
    func tap(_ p: CGPoint) {
        guard let frameSize = frameGrabber.frameSize else { return }
        guard let shape = modelManager?.inputShape else { return }

        let cx = p.x * frameSize.width
        let cy = p.y * frameSize.height
        
        let w = CGFloat(shape[2])
        let h = CGFloat(shape[1])
        let x = cx - w/2
        let y = cy - h/2
        frameGrabber.boundingBox = CGRect(
            x: x,
            y: y,
            width: w,
            height: h)
        boundingBox = CGRect(
            x: x/frameSize.width,
            y: y/frameSize.height,
            width: w/frameSize.width,
            height: h/frameSize.height)
    }
    
    func processBatch(_ batch: [Data]) {
        guard let dim = frameGrabber.frameSize else {
            print("frameSize is not available.")
            return
        }
        
        let result = self.modelManager?.runModel(
            onFrame: batch[0])
        DispatchQueue.main.async {
            if let result = result {
                let output = result.output
                let time = result.time
                
                self.resultText = "output=\(output), time=\(time)ms"
            } else {
                self.resultText = "No data"
            }
        }
    }
    
    func startProcessing() {
        processingQueue.async { [weak self] in
            guard let _self = self else { return }
            
            let batch = _self.frameGrabber.waitForBatch()
            _self.processBatch(batch)
            _self.startProcessing()
        }
    }
}
