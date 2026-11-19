//
//  ACKSubtype.swift
//  Teekum
//
//  Created by Nicho on 19/11/26.
//

import Foundation

public enum ACKSubtype: UInt8, CaseIterable, Sendable {
    case chat   = 0x01
    case sos    = 0x02
    case follow = 0x03
}
