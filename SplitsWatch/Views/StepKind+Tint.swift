//
//  StepKind+Tint.swift
//  SplitsWatch
//
//  iPhone의 StepBadge와 같은 색. 워치는 늘 어두워서 에셋의 다크 값이 쓰인다.
//

import SwiftUI

extension StepKind {
    var tint: Color {
        switch self {
        case .run, .warmup: Color("Run")
        case .rest, .cooldown: Color("Rest")
        }
    }
}
