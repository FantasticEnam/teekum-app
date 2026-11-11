//
//  OrbitModal.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 08/11/26.
//

enum OrbitModal: Identifiable, Hashable {
    case friends
    case mapPoint
    case settings
    case invite
    case finder(String)

    var id: Self { self }
}
