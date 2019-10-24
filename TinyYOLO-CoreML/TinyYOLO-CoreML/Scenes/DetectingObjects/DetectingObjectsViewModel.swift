//
//  DetectingObjectsViewModel.swift
//  TinyYOLO-CoreML
//
//  Created by  on 10/23/19.
//  Copyright © 2019 MachineThink. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

import RxSwift
import RxCocoa

final class DetectingObjectsViewModel: ViewModelType {
    // How many predictions we can do concurrently.
    static let maxInflightBuffers = 10
    // Disable this to see the energy impact of just running the neural net,
    // otherwise it also counts the GPU activity of drawing the bounding boxes.
    static let drawBoundingBoxes = true
    //
    private let yolo = YOLO()
    //
    private var colors: [UIColor] = []
    //
    private var framesDone = 0
    private var frameCapturingStartTime = CACurrentMediaTime()
    //
    private let semaphore = DispatchSemaphore(value: DetectingObjectsViewModel.maxInflightBuffers)
    //
    private var input: Intput!
    
    struct Box {
        let frame: CGRect
        let label: String
        let color: UIColor
    }
    private var boxes = PublishRelay<[Box]>()
    private var frameRateLabel = PublishRelay<String>()
    
    struct Intput {
        let trigger: Driver<Bool>
        let screenSize: CGSize
        let captureService: CaptureService
    }
    
    struct Output {
        let previewLayer: Driver<CALayer?>
        let boundingBoxes: Driver<[Box]>
        let timeRate: Driver<String>
        let isDetecting: Driver<Bool>
    }
    
    
    func transfer(from input: DetectingObjectsViewModel.Intput) -> DetectingObjectsViewModel.Output {
        // 1. init colors
        self.colors = setUpColors()
        // 2
        self.input = input
        // 3
        let previewLayer = self.input.captureService.setup().asDriverOnErrorJustComplete()
        let boundingBoxes = boxes.asDriverOnErrorJustComplete()
        let timeRate = frameRateLabel.asDriver(onErrorJustReturn: "")
        let isDetecting = self.input.trigger.flatMapLatest { (isAppeared) in
            return Observable.of(isAppeared).asDriverOnErrorJustComplete()
        }.do(onNext: {[unowned self] (isAppeared) in
            if (isAppeared) {
                self.input.captureService.resumeCapture()
            } else {
                self.input.captureService.pauseCapture()
            }
        })
        //
        let _ = self.input.captureService
            .startCapture()
            .bind(onNext: { [weak self] (ouput) in
                guard let weakSelf = self, let pixelBuffer = ouput.pixelBuffer else { return }
                weakSelf.prediction(pixelBuffer, weakSelf.input.screenSize)
            })
        //
        return Output(previewLayer: previewLayer,
                      boundingBoxes: boundingBoxes,
                      timeRate: timeRate,
                      isDetecting: isDetecting)
    }
}

// MARK: extension

extension DetectingObjectsViewModel {
    
    private func setUpColors() -> [UIColor] {
        // Make colors for the bounding boxes. There is one color for each class,
        // 20 classes in total.
        var colors = [UIColor]()
        for r: CGFloat in [0.2, 0.4, 0.6, 0.8, 1.0] {
            for g: CGFloat in [0.3, 0.7] {
                for b: CGFloat in [0.4, 0.8] {
                    let color = UIColor(red: r, green: g, blue: b, alpha: 1)
                    colors.append(color)
                }
            }
        }
        return colors
    }
    
    private func measureFPS( framesDone: inout Int, frameCapturingStartTime: inout CFTimeInterval) -> Double {
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
    
    private func boxes(from predictions: [YOLO.Prediction], originSize: CGSize, on screenSize: CGSize) -> [Box] {
        var boxes = [Box]()
        predictions.forEach { (prediction) in
            // The predicted bounding box is in the coordinate space of the input
            // image, which is a square image of 416x416 pixels. We want to show it
            // on the video preview, which is as wide as the screen and has a 16:9
            // aspect ratio. The video preview also may be letterboxed at the top
            // and bottom.
            let img_width: CGFloat = originSize.width
            let img_height: CGFloat = originSize.height
            
            let width: CGFloat = screenSize.width
            let height: CGFloat = img_height * (width/img_width)
            
            let scaleX = width / CGFloat(YOLO.inputWidth)
            let scaleY = height / CGFloat(YOLO.inputHeight)
            let top = (screenSize.height - height) / 2
            
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
            
            boxes.append(Box(frame: rect, label: label, color: color))
        }
        return boxes
    }
    
    func prediction(_ pixelBuffer: CVPixelBuffer, _ screenSize: CGSize) {
        ///
        semaphore.wait()
        ///
        let currentMediaTime = CACurrentMediaTime()
        let pixelBufferSize = CVImageBufferGetEncodedSize(pixelBuffer)
        //
        if let resizedPixelBuffer = resizePixelBuffer(pixelBuffer, width: YOLO.inputWidth, height: YOLO.inputHeight),
            let result = try? self.yolo.predict(image: resizedPixelBuffer),
            let boundingBoxes = result {
            let elapsed = (CACurrentMediaTime() - currentMediaTime)
            //
            if (DetectingObjectsViewModel.drawBoundingBoxes) {
                self.boxes.accept(self.boxes(from: boundingBoxes, originSize: pixelBufferSize, on: screenSize))
            }
            //
            let fps = self.measureFPS(framesDone: &self.framesDone, frameCapturingStartTime: &self.frameCapturingStartTime)
            frameRateLabel.accept(String(format: "Elapsed %.5f seconds - %.2f FPS", elapsed, fps))
        }
        ///
        semaphore.signal()
        ///
    }
}
