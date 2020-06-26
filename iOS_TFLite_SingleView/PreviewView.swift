//
//  PreviewView.swift
//  iOS_SingleView_1
//
//  Created by 横山裕樹 on 2020/06/08.
//  Copyright © 2020 HirokiYokoyama. All rights reserved.
//

import SwiftUI
import AVFoundation

struct PreviewView: UIViewRepresentable {
    var session: AVCaptureSession?
    
    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()

        view.session = self.session
        view.previewLayer.connection?.videoOrientation = .portrait
        view.previewLayer.videoGravity = .resizeAspectFill

        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
    }
}

struct PreviewView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewView(session: AVCaptureSession())
    }
}
