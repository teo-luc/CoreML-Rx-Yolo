//
//  OfflineMoviesViewController.swift
//  TinyYOLO-CoreML
//
//  Created by Teqnological on 10/22/19.
//  Copyright © 2019 MachineThink. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class OfflineMoviesViewController: UIViewController {

    let disposeBag = DisposeBag()
    //
    var viewModel = OfflineMovieListViewModel()
    //
    @IBOutlet weak var tableView: UITableView!
    //
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //
        VideoProvider.videos.bind(to: tableView.rx.items(cellIdentifier: VideoViewCell.reuseID, cellType: VideoViewCell.self)) { index, model, cell in
            cell.offlineMovieLable.text = model["title"]
        }.disposed(by: disposeBag)
        //
        tableView.rx.itemSelected.asDriver().drive(onNext: {[unowned self] (index) in
            let rawValue = VideoProvider.videos.value[index.row]
            let vc = self.storyboard?.instantiateViewController(ofType: DetectingObjectsViewController.self)
            //
            let url = Bundle.main.url(forResource: rawValue["fileName"], withExtension: nil)
            vc?.captureService = AVPlayerCaptureService(url: url!)
            vc?.viewModel = DetectingObjectsViewModel()
            //
            self.navigationController?.pushViewController(vc!, animated: true)
        }).disposed(by: disposeBag)
    }
}
