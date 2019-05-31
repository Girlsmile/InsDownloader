//
//  FunctionHelper.swift
//  FakeText
//
//  Created by 古智鹏 on 2019/3/21.
//  Copyright © 2019 古智鹏. All rights reserved.
//

import Foundation

typealias AnalysisResultcompletion = (AnalysisResult, [InsMedia]?) -> Void

func delay(after: Double, execute: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(
        deadline: .now() + after,
        execute: execute
    )
}


