//
//  CaptureService.swift
//  TinyYOLO-CoreML
//
//  Created by  on 10/23/19.
//  Copyright © 2019 MachineThink. All rights reserved.
//

import Foundation
import AVFoundation
import RxSwift

struct Output {
    let pixelBuffer: CVPixelBuffer?
    let time: CMTime
}

protocol CaptureService {    
    // Input
    var desiredFrameRate: Int { get }
    // Setup
    func setup() -> Observable<CALayer?>
    // Action
    func startCapture() -> Observable<Output>
    func resumeCapture()
    func pauseCapture()
}
