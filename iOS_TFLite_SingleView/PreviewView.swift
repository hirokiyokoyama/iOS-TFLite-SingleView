//
//  PreviewView.swift
//  iOS_SingleView_1
//
//  Created by 横山裕樹 on 2020/06/08.
//  Copyright © 2020 HirokiYokoyama. All rights reserved.
//

import SwiftUI
import AVFoundation

struct PreviewLayerCoordinateConverter {
    let layer: AVCaptureVideoPreviewLayer
    
    func devicePoint(fromLayerPoint point: CGPoint) -> CGPoint {
        return layer.captureDevicePointConverted(fromLayerPoint: point)
    }
    
    func layerPoint(fromDevicePoint point: CGPoint) -> CGPoint {
        return layer.layerPointConverted(fromCaptureDevicePoint: point)
    }
    
    func deviceRect(fromLayerRect rect: CGRect) -> CGRect {
        return layer.metadataOutputRectConverted(fromLayerRect: rect)
    }
    
    func layerRect(fromDeviceRect rect: CGRect) -> CGRect {
        return layer.layerRectConverted(fromMetadataOutputRect: rect)
    }
    
    func deviceVector(fromLayerVector vector: CGVector) -> CGVector {
        let origin = layer.captureDevicePointConverted(fromLayerPoint: CGPoint(x: 0, y: 0))
        let point = layer.captureDevicePointConverted(fromLayerPoint: CGPoint(x: vector.dx, y: vector.dy))
        return CGVector(dx: point.x - origin.x, dy: point.y - origin.y)
    }
    
    func layerVector(fromDeviceVector vector: CGVector) -> CGVector {
        let origin = layer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: 0, y: 0))
        let point = layer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: vector.dx, y: vector.dy))
        return CGVector(dx: point.x - origin.x, dy: point.y - origin.y)
    }
}

struct PreviewView: UIViewRepresentable {
    var session: AVCaptureSession?
    @Binding var coordinateConverter: PreviewLayerCoordinateConverter?
    
    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()

        view.session = self.session
        view.previewLayer.connection?.videoOrientation = .portrait
        // Show all pixels
        view.previewLayer.videoGravity = .resizeAspect

        DispatchQueue.main.async {
            self.coordinateConverter = PreviewLayerCoordinateConverter(layer: view.previewLayer)
        }
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
    }
}

struct PreviewView_Previews: PreviewProvider {
    @State static var coordinateConverter: PreviewLayerCoordinateConverter? = nil
    
    static var previews: some View {
        PreviewView(session: AVCaptureSession(), coordinateConverter: $coordinateConverter)
    }
}
