//
//  RouteDiscoveryManaging.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

public protocol RouteDiscoveryManaging: Actor {
    /// Resolves an on-demand route towards target initials in the given session.
    /// If an active unexpired route exists in the routing table, returns it immediately.
    /// Otherwise, initiates an AODV route discovery with rate limiting and timeout.
    func resolveRoute(
        to targetInitials: String,
        session: GroupSession,
        timeout: TimeInterval
    ) async throws -> RouteEntry
    
    /// Forces initiation of route discovery regardless of existing cached routes.
    func initiateDiscovery(
        to targetInitials: String,
        session: GroupSession,
        timeout: TimeInterval
    ) async throws -> RouteEntry
    
    /// Ingests and processes an inbound Route Request packet.
    func handleInboundRouteReq(
        wireData: Data,
        fromPeerId: String,
        session: GroupSession
    ) async throws -> RouteReqHandlingResult
    
    /// Ingests and processes an inbound Route Response packet.
    func handleInboundRouteResp(
        wireData: Data,
        fromPeerId: String,
        session: GroupSession
    ) async throws -> RouteRespHandlingResult
    
    /// Handles neighbor disconnection: invalidates dependent routes.
    func handleNeighborDisconnected(peerId: String) async
    
    /// Invalidates a route towards a specific destination.
    func invalidateRoute(towards targetInitials: String, session: GroupSession?) async
    
    /// Teardown: cancels in-flight discoveries and purges session routes.
    func teardown(sessionId: UInt32?) async
    
    /// Live diagnostics snapshot for HUD or telemetry.
    func diagnosticsSnapshot() async -> RouteDiscoveryDiagnostics
}
