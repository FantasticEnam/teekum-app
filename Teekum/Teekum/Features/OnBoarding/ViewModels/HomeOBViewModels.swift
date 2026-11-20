//
//  HomeOBViewModels.swift
//  Teekum
//
//  Created by Ari Hasan on 19/11/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class HomeOBViewModels {
    enum Step: Hashable {
        case nickname
        case groupAction
        case groupName
        case primaryAction
    }

    private let defaults: UserDefaults?
    private let nicknameTipSeenKey = "com.teekum.hasSeenNicknameTip"

    private(set) var step: Step?

    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
    }

    func showIfNeeded() {
        guard defaults?.bool(forKey: nicknameTipSeenKey) != true else { return }
        defaults?.set(true, forKey: nicknameTipSeenKey)
        step = .nickname
    }

    func advance(showsGroupName: Bool) {
        switch step {
        case .nickname:
            step = .groupAction
        case .groupAction:
            step = showsGroupName ? .groupName : .primaryAction
        case .groupName:
            step = .primaryAction
        case .primaryAction, nil:
            step = nil
        }
    }

    func dismiss() {
        step = nil
    }
}
