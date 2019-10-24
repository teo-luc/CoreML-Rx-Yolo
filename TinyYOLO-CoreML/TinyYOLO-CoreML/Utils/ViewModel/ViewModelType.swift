//
//  ViewModel.swift
//  TinyYOLO-CoreML
//
//  Created by  on 10/22/19.
//  Copyright © 2019 MachineThink. All rights reserved.
//

import Foundation

protocol ViewModelType {
    associatedtype Intput
    associatedtype Output
    
    func transfer(from input: Intput) -> Output
}
