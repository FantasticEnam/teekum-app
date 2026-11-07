//
//  PairingViewModel.swift
//  Teekum
//
//  Created by Ari Hasan on 05/11/26.
//

import Observation

@MainActor
@Observable
final class PairingViewModel {
    var form = PairingForm() {
        didSet {
            if form != oldValue { isShowingQR = false }
        }
    }
    var mode: PairingMode = .create
    private(set) var isShowingQR = false

    var canPerformPrimaryAction: Bool {
        mode == .create ? form.canGenerateQR : form.hasValidInitials
    }

    func showQRPreview() {
        guard mode == .create, form.canGenerateQR else { return }
        isShowingQR = true
    }
}
