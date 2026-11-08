//
//  FriendListViewModel.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 06/11/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class FriendListViewModel {
    private let sessionStore: SessionStore
    var searchQuery = ""

    var filteredMembers: [Member] {
        let search = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let members = sessionStore.members
        return search.isEmpty ? members : members.filter {
            $0.initials.localizedCaseInsensitiveContains(search)
        }
    }

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    static func locationAgeLabel(from date: Date, relativeTo now: Date) -> LocalizedStringResource {
        let age = now.timeIntervalSince(date)
        guard age.isFinite, age >= 0, age < Double(Int.max) else {
            return "Unavailable"
        }

        if age < 60 {
            return "\(Int(age))s ago"
        }
        return "\(Int(age / 60))m ago"
    }
}
