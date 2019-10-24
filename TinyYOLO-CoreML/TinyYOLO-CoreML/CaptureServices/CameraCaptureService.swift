//
//  CameraCaptureService.swift
//  TinyYOLO-CoreML
//
//  Created by Teqnological on 10/23/19.
//  Copyright © 2019 MachineThink. All rights reserved.
//

import UIKit
import AVFoundation

final class CameraCaptureService: NSObject, CaptureService {
    
    // MARK: Private
    
    private var outPutHandler: Output?
    private var queue: DispatchQueue = DispatchQueue(label: "net.machinethink.camera-queue")
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    // MARK: Public
    
    var desiredFrameRate: Int = 30
    
    // MARK: LifeCycles
    
    
    // MARK: -
    
    func setup(_ completion: @escaping (CALayer?) -> Void) {
        queue.async {
            let _ = self.setUpCamera(sessionPreset: .medium)
            DispatchQueue.main.async {
                completion(self.previewLayer)
            }
        }
    }
    
    func startCapture(_ completion: @escaping CameraCaptureService.Output) {
        self.outPutHandler = completion
        resumeCapture()
    }
    
    func resumeCapture() {
        if !captureSession.isRunning { captureSession.startRunning() }
    }
    
    func pauseCapture() {
        if captureSession.isRunning { captureSession.stopRunning() }
    }
}

// MARK: SetUpCamera

fileprivate extension CameraCaptureService {
    func setUpCamera(sessionPreset: AVCaptureSession.Preset) -> Bool {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = sessionPreset
        
        guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) else {
            print("Error: no video devices available")
            return false
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            print("Error: could not create AVCaptureDeviceInput")
            return false
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        previewLayer.connection?.videoOrientation = .portrait
        self.previewLayer = previewLayer
        
        let settings: [String : Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA),
        ]
        
        videoOutput.videoSettings = settings
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // We want the buffers to be in portrait orientation otherwise they are
        // rotated by 90 degrees. Need to set this _after_ addOutput()!
        videoOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait
        
        // Based on code from https://github.com/dokun1/Lumina/
        let activeDimensions = CMVideoFormatDescriptionGetDimensions(captureDevice.activeFormat.formatDescription)
        for vFormat in captureDevice.formats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(vFormat.formatDescription)
            let ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
            if let frameRate = ranges.first,
                frameRate.maxFrameRate >= Float64(desiredFrameRate) &&
                    frameRate.minFrameRate <= Float64(desiredFrameRate) &&
                    activeDimensions.width == dimensions.width &&
                    activeDimensions.height == dimensions.height &&
                    CMFormatDescriptionGetMediaSubType(vFormat.formatDescription) == 875704422 { // meant for full range 420f
                do {
                    try captureDevice.lockForConfiguration()
                    captureDevice.activeFormat = vFormat as AVCaptureDevice.Format
                    captureDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(desiredFrameRate))
                    captureDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(desiredFrameRate))
                    captureDevice.unlockForConfiguration()
                    break
                } catch {
                    continue
                }
            }
        }
        print("Camera format:", captureDevice.activeFormat)
        
        captureSession.commitConfiguration()
        return true
    }
}

extension CameraCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        guard let outPutHandler = outPutHandler else { return }
        outPutHandler(self, imageBuffer, timestamp)
    }
}
