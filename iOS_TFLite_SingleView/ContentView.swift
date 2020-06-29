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
    @State private var dragLocation = CGPoint()

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                PreviewView(session: self.viewModel.cameraManager?.session)
                .onAppear {
                    self.viewModel.cameraManager?.startSession()
                }
                .onDisappear {
                    self.viewModel.cameraManager?.stopSession()
                }
                .gesture(
                    DragGesture(minimumDistance: 0.0)
                    .onChanged { value in
                        let p = CGPoint(
                            x: value.location.x/geometry.size.width,
                            y: value.location.y/geometry.size.height)
                        self.viewModel.tap(p)
                    }
                )
            }
                
            VStack {
                Text(viewModel.resultText)
                    .foregroundColor(.red)
                    .bold()
                Text(viewModel.tapText)
                    .foregroundColor(.blue)
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
