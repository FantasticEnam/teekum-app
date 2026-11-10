//
//  RelayDiagnosticProviding.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

public protocol RelayDiagnosticsProviding: Actor {
    /// Returns an instantaneous snapshot of mesh performance and relay telemetry.
    func snapshot() async -> RelayTelemetry
    
    /// Records a packet forwarding event.
    func recordForwardEvent(type: PacketType) async
    
    /// Records a packet drop event with specific reason.
    func recordDropEvent(reason: DropReason) async
}
