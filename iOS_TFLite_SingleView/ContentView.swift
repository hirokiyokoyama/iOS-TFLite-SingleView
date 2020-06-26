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

    var body: some View {
        ZStack {
            PreviewView(session: viewModel.cameraManager?.session)
                .onAppear {self.viewModel.cameraManager?.startSession()}
                .onDisappear {self.viewModel.cameraManager?.stopSession()}
            Text(viewModel.resultText)
                .foregroundColor(.red)
                .bold()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
