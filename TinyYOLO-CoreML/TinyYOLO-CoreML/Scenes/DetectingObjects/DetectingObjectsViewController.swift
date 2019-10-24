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
    
    private var boxesView: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bind()
    }
    
    // MARK: - Binding
    
    private func bind() {
        // 1
        let input = DetectingObjectsViewModel.Intput(trigger: viewState(),
                                                     screenSize: self.view.bounds.size,
                                                     captureService: captureService)
        let output = viewModel.transfer(from: input)
        // 2
        output.previewLayer.drive(onNext: { [unowned self] (layer) in
            guard let previewLayer = layer else { return }
            previewLayer.frame = self.videoPreview.bounds
            self.videoPreview.layer.insertSublayer(previewLayer, at: 0)
        }).disposed(by: disposeBag)
        // 3
        
        output.boundingBoxes.drive(onNext: { [weak self] (boxes) in
            guard let weakSelf = self else { return }
            weakSelf.showBoxes(boxes)
        }).disposed(by: disposeBag)
        // 4
        output.timeRate.drive(self.timeLabel.rx.text).disposed(by: disposeBag)
        //
        output.isDetecting.drive().disposed(by: disposeBag)
    }
}

// MARK: - ViewStates and AppStates

extension DetectingObjectsViewController {
    private func viewState() -> Driver<Bool> {
        let viewWillAppear = self.rx.sentMessage(#selector(self.viewWillAppear(_:))).map { _ in true }
        let appInForceground = NotificationCenter.default.rx.notification(UIApplication.didBecomeActiveNotification).map { _ in true }
        let viewWillDisappear = self.rx.sentMessage(#selector(self.viewWillDisappear(_:))).map { _ in false }
        let appInBackground = NotificationCenter.default.rx.notification(UIApplication.didEnterBackgroundNotification).map { _ in false }
        return Observable.of(viewWillAppear, viewWillDisappear, appInForceground,  appInBackground).merge().asDriverOnErrorJustComplete()
    }
}

extension DetectingObjectsViewController {
    private func showBoxes(_ boxes: [DetectingObjectsViewModel.Box]) {
        if (self.boxesView != nil) { self.boxesView?.removeFromSuperview() }
        if boxes.count != 0 {
            //
            let boxesView = UIView(frame: self.videoPreview.bounds)
            boxesView.isUserInteractionEnabled = false
            boxesView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            //
            self.videoPreview.addSubview(boxesView)
            //
            boxes.forEach { (box) in
                let boxLayer = BoundingBox()
                boxLayer.addToLayer(boxesView.layer)
                boxLayer.show(frame: box.frame, label: box.label, color: box.color)
            }
            //
            self.boxesView = boxesView
        }
    }
}
