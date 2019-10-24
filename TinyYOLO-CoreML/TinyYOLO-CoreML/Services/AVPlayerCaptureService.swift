//
//  AVPlayerCapture.swift
//  TinyYOLO-CoreML
//
//  Created by  on 10/22/19.
//  Copyright © 2019 MachineThink. All rights reserved.
//

import UIKit
import AVFoundation
import RxSwift

public final class AVPlayerCaptureService: NSObject, CaptureService {
    
    // MARK: Private
    
    private var assetURL: URL!
    private var output: AVPlayerItemVideoOutput!
    private var outPutHandler: Output?
    private var queue: DispatchQueue = DispatchQueue(label: "net.machinethink.player-queue")
    private var player: AVPlayer!
    private override init() {}
    
    // MARK: Public
    
    var desiredFrameRate: Int = 30
    
    // MARK: LifeCycles
    
    public init(url: URL) {
        self.assetURL = url
    }
    
    deinit { print(#function) }
    
    // MARK: -
    
    func setup() -> Observable<CALayer?> {
        let layer = Observable<CALayer?>.create { [unowned self] (observer) -> Disposable in
            self.queue.async {
                let layer = AVPlayerLayer.init(player: self.player)
                observer.onNext(layer)
            }
            return Disposables.create()
        }
         // 2
         player = AVPlayer(url: assetURL)
//         // 3
//         output = setupOutput(from: player, frame: desiredFrameRate, queue: queue, using: {[weak self] (time) in
//             guard let weakSelf = self, let callback = weakSelf.outPutHandler else { return }
//             let pixelBuffer = weakSelf.output.pixelBuffer(forItemTime: time)
//             callback(weakSelf, pixelBuffer, time)
//         })
        
        return layer
     }
    
    private func setupOutput(from avPlayer: AVPlayer, frame frameRate: Int, queue: DispatchQueue, using block: @escaping (CMTime) -> Void) -> AVPlayerItemVideoOutput {
        // 1
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let sec = 1.0/Double(frameRate)
        let time = CMTime(seconds: sec, preferredTimescale: timeScale)
        // 2
        avPlayer.addPeriodicTimeObserver(forInterval: time, queue: queue, using: block)
        // 3
        let settings: [String : Any] = [ kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)]
        // 4
        let avOuput = AVPlayerItemVideoOutput(pixelBufferAttributes: settings)
        avOuput.setDelegate(self, queue: queue)
        avPlayer.currentItem?.add(avOuput)
        return avOuput
    }
    
    func startCapture() -> Observable<Output> {
        let ouput = Observable<Output>.create {[unowned self] (observer) -> Disposable in
            self.output = self.setupOutput(from: self.player, frame: self.desiredFrameRate, queue: self.queue, using: {[weak self] (time) in
                guard let weakSelf = self  else { return }
                let pixelBuffer = weakSelf.output.pixelBuffer(forItemTime: time)
                observer.onNext(Output(pixelBuffer: pixelBuffer, time: time))
            })
            return Disposables.create()
        }
        //
        resumeCapture()
        return ouput
    }
    
    func resumeCapture() {
        player.play()
    }
    
    func pauseCapture() {
        player.pause()
    }
    
}

fileprivate extension AVPlayerItemVideoOutput {
    func pixelBuffer(forItemTime: CMTime) -> CVPixelBuffer? {
        return self.copyPixelBuffer(forItemTime: forItemTime, itemTimeForDisplay: nil)
    }
}

extension AVPlayerCaptureService: AVPlayerItemOutputPullDelegate { }
