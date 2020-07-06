//
//  ContentView.swift
//  iOS_TFLite_SingleView
//
//  Created by 横山裕樹 on 2020/06/26.
//  Copyright © 2020 HirokiYokoyama. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var viewModel = ContentViewModel()
    @State private var coordinateConverter: PreviewLayerCoordinateConverter?

    private var bb: CGRect? {
        if let conv = coordinateConverter {
            return viewModel.boundingBox.map(conv.layerRect(fromDeviceRect:))
        } else {
            return nil
        }
    }
    
    var body: some View {
        ZStack {
            PreviewView(session: self.viewModel.cameraManager?.session,
                        coordinateConverter: self.$coordinateConverter)
            .onAppear {
                self.viewModel.cameraManager?.startSession()
            }
            .onDisappear {
                self.viewModel.cameraManager?.stopSession()
            }
            .gesture(
                DragGesture(minimumDistance: 0.0)
                .onChanged { value in
                    if let p = self.coordinateConverter?.devicePoint(fromLayerPoint: value.location) {
                        self.viewModel.tap(p)
                    } else {
                        print("No converter")
                    }
                }
            )
            
            Path { path in
                if let bb = bb {
                    path.addRect(bb)
                }
            }
            .stroke(Color.blue, lineWidth: 2)

            VStack {
                Spacer()
                Text(viewModel.resultText)
                    .foregroundColor(.red)
                    .bold()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
