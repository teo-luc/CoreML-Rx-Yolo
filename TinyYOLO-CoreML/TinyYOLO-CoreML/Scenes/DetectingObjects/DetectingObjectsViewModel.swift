//
//  DetectingObjectsViewModel.swift
//  TinyYOLO-CoreML
//
//  Created by Teqnological on 10/23/19.
//  Copyright © 2019 MachineThink. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

import RxSwift
import RxCocoa

final class DetectingObjectsViewModel: ViewModelType {
    // How many predictions we can do concurrently.
    static let maxInflightBuffers = 2
    // true: use Vision to drive Core ML, false: use plain Core ML
    static let useVision = false
    // Disable this to see the energy impact of just running the neural net,
    // otherwise it also counts the GPU activity of drawing the bounding boxes.
    static let drawBoundingBoxes = true
    static var inflightBuffer = 0
    
    private let yolo = YOLO()
    private var colors: [UIColor] = []
    private var framesDone = 0
    private var frameCapturingStartTime = CACurrentMediaTime()
    private let semaphore = DispatchSemaphore(value: DetectingObjectsViewModel.maxInflightBuffers)
    
    
    private var input: Intput!
    private var output = Output()
    
    
    struct Intput {
        let trigger: Driver<Bool>
        let screenSize: CGSize
        let captureService: CaptureService
    }
    
    struct Output {
        var previewLayer: BehaviorRelay<CALayer?>!
        var boundingBoxes: BehaviorRelay<[BoundingBox]>!
        var timeRate: BehaviorRelay<String>!
        var isDetecting: Driver<Bool>!
    }
    
    
    func transfer(from input: DetectingObjectsViewModel.Intput) -> DetectingObjectsViewModel.Output {
        // 1
        self.input = input
        self.input.captureService.setup { [unowned self] (layer) in self.output.previewLayer.accept(layer) }
        self.input.captureService.startCapture {[weak self] (captureService, pixelBuffer, time) in
            if let pixelBuffer = pixelBuffer {
                self?.prediction(pixelBuffer)
            }
        }
        // 2
        self.output.previewLayer = BehaviorRelay(value: nil)
        self.output.boundingBoxes = BehaviorRelay(value: self.setUpBoundingBoxes())
        self.output.timeRate = BehaviorRelay(value: "")
        self.output.isDetecting = self.input.trigger.flatMapLatest { (isAppeared) in
            return Observable.of(isAppeared).asDriverOnErrorJustComplete()
        }.do(onNext: {[unowned self] (isAppeared) in
            if (isAppeared) {
                self.input.captureService.resumeCapture()
            } else {
                self.input.captureService.pauseCapture()
            }
        })
        //
        return self.output
    }
}

// MARK: extension

fileprivate extension DetectingObjectsViewModel {
    
    func setUpBoundingBoxes() -> [BoundingBox] {
        var boundingBoxes = [BoundingBox]()
        for _ in 0..<YOLO.maxBoundingBoxes {
            boundingBoxes.append(BoundingBox())
        }
        
        // Make colors for the bounding boxes. There is one color for each class,
        // 20 classes in total.
        for r: CGFloat in [0.2, 0.4, 0.6, 0.8, 1.0] {
            for g: CGFloat in [0.3, 0.7] {
                for b: CGFloat in [0.4, 0.8] {
                    let color = UIColor(red: r, green: g, blue: b, alpha: 1)
                    colors.append(color)
                }
            }
        }
        
        return boundingBoxes
    }
    
    func measureFPS() -> Double {
        // Measure how many frames were actually delivered per second.
        framesDone += 1
        let frameCapturingElapsed = CACurrentMediaTime() - frameCapturingStartTime
        let currentFPSDelivered = Double(framesDone) / frameCapturingElapsed
        if frameCapturingElapsed > 1 {
            framesDone = 0
            frameCapturingStartTime = CACurrentMediaTime()
        }
        return currentFPSDelivered
    }
    
    func show(predictions: [YOLO.Prediction], originSize: CGSize) {
        let boundingBoxes = self.output.boundingBoxes.value
        for i in 0..<boundingBoxes.count {
            if i < predictions.count {
                let prediction = predictions[i]
                
                // The predicted bounding box is in the coordinate space of the input
                // image, which is a square image of 416x416 pixels. We want to show it
                // on the video preview, which is as wide as the screen and has a 16:9
                // aspect ratio. The video preview also may be letterboxed at the top
                // and bottom.
                let img_width: CGFloat = /*view.bounds.width*/originSize.width
                let img_height: CGFloat = /*width * 16 / 9*/originSize.height
                
                let width: CGFloat = self.input.screenSize.width
                let height: CGFloat = img_height * (width/img_width)
                
                let scaleX = width / CGFloat(YOLO.inputWidth)
                let scaleY = height / CGFloat(YOLO.inputHeight)
                let top = (self.input.screenSize.height - height) / 2
                
                // Translate and scale the rectangle to our own coordinate system.
                var rect = prediction.rect
                rect.origin.x *= scaleX
                rect.origin.y *= scaleY
                rect.origin.y += top
                rect.size.width *= scaleX
                rect.size.height *= scaleY
                
                // Show the bounding box.
                let label = String(format: "%@ %.1f", labels[prediction.classIndex], prediction.score * 100)
                let color = colors[prediction.classIndex]
                boundingBoxes[i].show(frame: rect, label: label, color: color)
            } else {
                boundingBoxes[i].hide()
            }
        }
    }
    
    func showOnMainThread(_ boundingBoxes: [YOLO.Prediction], originSize: CGSize, _ elapsed: CFTimeInterval) {
        if DetectingObjectsViewModel.drawBoundingBoxes {
            DispatchQueue.main.async {
                self.show(predictions: boundingBoxes, originSize: originSize)
                let fps = self.measureFPS()
                self.output.timeRate.accept(String(format: "Elapsed %.5f seconds - %.2f FPS", elapsed, fps))
            }
        }
    }
    
    
    func prediction(_ pixelBuffer: CVPixelBuffer) {
        //
        let currentMediaTime = CACurrentMediaTime()
        print("currentMediaTime = \(currentMediaTime) START")
        self.semaphore.wait()
        //
        print("currentMediaTime = \(currentMediaTime) PROCES")
        let pixelBufferSize = CVImageBufferGetEncodedSize(pixelBuffer)
        if let resizedPixelBuffer = resizePixelBuffer(pixelBuffer, width: YOLO.inputWidth, height: YOLO.inputHeight),
            let result = try? self.yolo.predict(image: resizedPixelBuffer),
            let boundingBoxes = result {
            print("currentMediaTime = \(boundingBoxes.count) boxes")
            let elapsed = (CACurrentMediaTime() - currentMediaTime)
            self.showOnMainThread(boundingBoxes, originSize: pixelBufferSize, elapsed)
        }
        print("currentMediaTime = \(currentMediaTime) DONE")
        //
        self.semaphore.signal()
        //
    }
    
}
