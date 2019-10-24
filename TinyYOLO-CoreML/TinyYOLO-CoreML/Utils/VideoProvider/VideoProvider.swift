//
//  VideoProvider.swift
//  TinyYOLO-CoreML
//
//  Created by  on 10/22/19.
//  Copyright © 2019 MachineThink. All rights reserved.
//

import Foundation
import RxCocoa

enum VideoProvider {}

extension VideoProvider {
    static let videos = BehaviorRelay(value: [
        [
            "title": "End Game – Marvel Studio -Trailer",
            "fileName": "Marvel_Studios_Endgame.mp4"
        ],
        [
            "title": "Days Gone – Story Trailer",
            "fileName": "Days_Gone.mp4"
        ],
        [
            "title": "God of War 4 – Trailer",
            "fileName": "God_of_War.mp4"
        ]
    ])

}

