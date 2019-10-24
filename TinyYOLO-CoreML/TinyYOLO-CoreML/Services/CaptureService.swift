//
//  CaptureService.swift
//  TinyYOLO-CoreML
//
//  Created by  on 10/23/19.
//  Copyright © 2019 MachineThink. All rights reserved.
//

import Foundation
import AVFoundation

protocol CaptureService {
    typealias Output = (CaptureService, CVPixelBuffer?, CMTime) -> Void
    // Input
    var desiredFrameRate: Int { get }
    // Setup
    func setup(_ completion: @escaping (CALayer?) -> Void) -> Void
    // Action
    func startCapture(_ completion: @escaping Output) -> Void
    func resumeCapture()
    func pauseCapture()
}
