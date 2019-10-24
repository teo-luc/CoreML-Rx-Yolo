import UIKit
import Vision
import AVFoundation
import CoreMedia

import RxSwift
import RxCocoa

class DetectingObjectsViewController: UIViewController {
    
    let disposeBag = DisposeBag()
    var viewModel: DetectingObjectsViewModel!
    var captureService: CaptureService!
    
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var debugImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bind()
    }
    
    // MARK: -
    private func bind() {
        // 1
        let viewWillAppear = self.rx.sentMessage(#selector(self.viewWillAppear(_:))).map { _ in true }
        let appInForceground = NotificationCenter.default.rx.notification(UIApplication.didBecomeActiveNotification).map { _ in true }
        let viewWillDisappear = self.rx.sentMessage(#selector(self.viewWillDisappear(_:))).map { _ in false }
        let appInBackground = NotificationCenter.default.rx.notification(UIApplication.didEnterBackgroundNotification).map { _ in false }
        let trigger = Observable.of(viewWillAppear, viewWillDisappear, appInForceground,  appInBackground).merge().asDriverOnErrorJustComplete()
        
        let input = DetectingObjectsViewModel.Intput(trigger: trigger, screenSize: self.view.bounds.size, captureService: captureService)
        let output = viewModel.transfer(from: input)
        
        // 2
        output.previewLayer.asDriver().drive(onNext: { [unowned self] (layer) in
            guard let previewLayer = layer else { return }
            previewLayer.frame = self.videoPreview.bounds
            self.videoPreview.layer.insertSublayer(previewLayer, at: 0)
        }).disposed(by: disposeBag)
        // 3
        output.boundingBoxes.asDriver().drive(onNext: { [unowned self] (boxes) in
            boxes.forEach { (box) in
                box.addToLayer( self.videoPreview.layer)
            }
        }).disposed(by: disposeBag)
        // 4
        output.timeRate.asDriver().drive(self.timeLabel.rx.text).disposed(by: disposeBag)
        //
        output.isDetecting.drive().disposed(by: disposeBag)
    }
}
