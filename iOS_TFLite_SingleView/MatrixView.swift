//
//  MatrixView.swift
//  ConcreteFlow_iOS
//
//  Created by 横山裕樹 on 2020/07/01.
//  Copyright © 2020 HirokiYokoyama. All rights reserved.
//

import SwiftUI

struct MatrixView: View {
    var rows: Int
    var columns: Int
    // 1: Gray, 3: RGB, 4: ARGB
    var channels: Int
    var elements: [Float]
    var scale: CGFloat = 1.0
    
    var argbData: [UInt8] {
        var data = [UInt8](repeating: 0, count: rows*columns*4)
        guard channels == 1 || channels == 3 || channels == 4 else {
            return data
        }
        
        for i in 0 ..< rows {
            for j in 0 ..< columns {
                let dstInd = i * columns*4 + j*4
                let srcInd = i * columns*channels + j*channels
                var red: Float = 0
                var green: Float = 0
                var blue: Float = 0
                var alpha: Float = 1
                switch channels {
                case 1:
                    red = elements[srcInd]
                    green = elements[srcInd]
                    blue = elements[srcInd]
                case 3:
                    red = elements[srcInd+0]
                    green = elements[srcInd+1]
                    blue = elements[srcInd+2]
                case 4:
                    red = elements[srcInd+0]
                    green = elements[srcInd+1]
                    blue = elements[srcInd+2]
                    alpha = elements[srcInd+3]
                default:
                    return data
                }
                data[dstInd+0] = UInt8(alpha * 255)
                data[dstInd+1] = UInt8(red * 255)
                data[dstInd+2] = UInt8(green * 255)
                data[dstInd+3] = UInt8(blue * 255)
            }
        }
        return data
    }
    
    var body: some View {
        if let image = imageFromARGB(argbData, width: columns, height: rows) {
            return Image(image,
                         scale: 1.0/scale,
                         label: Text("flow"))
        } else {
            return Image("flow")
        }
    }
    
    private func imageFromARGB(_ argbData: [UInt8], width: Int, height: Int) -> CGImage? {
        assert(argbData.count == height * width * 4)

        let data: Data = argbData.withUnsafeBufferPointer {
           return Data(buffer: $0)
        }

        let cfdata = NSData(data: data) as CFData
        guard let provider = CGDataProvider(data: cfdata) else {
           print("CGDataProvider is not supposed to be nil")
           return nil
        }
        let cgimage = CGImage(
           width: width,
           height: height,
           bitsPerComponent: 8,
           bitsPerPixel: 32,
           bytesPerRow: width * 4,
           space: CGColorSpaceCreateDeviceRGB(),
           bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue),
           provider: provider,
           decode: nil,
           shouldInterpolate: true,
           intent: .defaultIntent)
        return cgimage
    }
}

struct MatrixView_Previews: PreviewProvider {
    static var previews: some View {
        MatrixView(rows: 2, columns: 2, channels: 3,
                   elements: [1.0, 0.0, 0.0,
                              0.0, 1.0, 0.0,
                              0.0, 0.0, 1.0,
                              1.0, 1.0, 0.0],
                   scale: 10.0)
    }
}
