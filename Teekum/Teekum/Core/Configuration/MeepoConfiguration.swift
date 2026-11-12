//
//  MeepoConfiguration.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

/// Centralized Master Configuration Repository for Google Antigravity / TeeKum Festival Mesh.
///
/// Every configurable knob, cadences, network thresholds, hop limits, battery cutoffs,
/// retry parameters, and UI timings are unified in this single file for rapid testing and field tuning.
nonisolated public enum MeepoConfiguration {
    
    // MARK: - 1. Wire Protocol & Network Topology Parameters
    public enum Network {
        /// Strictly fixed 56-byte wire datagram format (invariant across all packet types).
        public static let wirePacketSize: Int = 56
        
        /// Size of cleartext envelope for routing inspection (10 bytes).
        public static let cleartextEnvelopeSize: Int = 10
        
        /// Size of encrypted ChaCha20 / Poly1305 payload (30 bytes).
        public static let encryptedPayloadSize: Int = 30
        
        /// Size of Poly1305 authentication tag (16 bytes).
        public static let authTagSize: Int = 16
        
        /// Size of cryptographic AEAD nonce (12 bytes).
        public static let nonceSize: Int = 12
        
        /// Protocol version (0x01 for Protocol Version 1).
        public static let protocolVersion: UInt8 = 0x01
        
        /// 4-byte domain separation tag used in AEAD nonce construction: 'T', 'K', 'M', '3'.
        public static let protocolDomainTag: [UInt8] = [0x54, 0x4B, 0x4D, 0x33]

        /// Bitmask for canonical 24-bit Session ID values (`0x000000...0xFFFFFF`).
        public static let sessionIdMask: UInt32 = 0x00FFFFFF

        /// Maximum allowable 24-bit Session ID (`0x00FFFFFF` = 16,777,215).
        public static let maxSessionId: UInt32 = 0x00FFFFFF
        
        /// Hard architectural maximum allowable hop limit across the entire mesh (1...15).
        public static let maxHopLimit: UInt8 = 15
        
        /// Hop limit for standard periodic Location Ping packets (Type 0x01) (default: 8).
        public static let defaultHopLimit: UInt8 = 8
        
        /// Dedicated hop limit budget for Chat Messages (Type 0x07) and Delivery ACKs (Type 0x06).
        /// Tuneable independently to control text propagation radius and conserve festival airtime (default: 8).
        public static let chatHopLimit: UInt8 = 8
        
        /// Strict 1-hop limit for Ultra-Wideband token exchange packets (default: 1).
        public static let uwbHopLimit: UInt8 = 1
        
        /// High-reach hop limit for Group Rendezvous / Meeting Point updates (Type 0x03) (default: 15).
        public static let meetingPointHopLimit: UInt8 = 15
        
        /// Maximum-priority hop limit for Emergency SOS siren alerts (Type 0x02) (default: 15).
        public static let sosHopLimit: UInt8 = 15
    }
    
    // MARK: - 2. Broadcast Cadence & Mesh Timing Parameters
    public enum Timing {
        /// Location publishing interval when actively moving with strong nearby peers (default: 4.0s).
        public static let locationMovingInterval: TimeInterval = 4.0
        
        /// Location publishing interval when stationary with nearby peers (default: 20.0s).
        public static let locationStationaryInterval: TimeInterval = 20.0
        
        /// Accelerated publishing interval when links degrade or peers become distant (default: 2.0s).
        public static let distantPeerInterval: TimeInterval = 2.0
        
        /// Throttled publishing interval in Festival Survival Mode (<20% battery) (default: 60.0s).
        public static let survivalInterval: TimeInterval = 60.0
        
        /// RSSI threshold (dBm) below which a link is deemed weak/distant (default: -75 dBm).
        public static let distantRSSIThreshold: Int8 = -75
        
        /// GPS distance threshold (meters) beyond which a peer is treated as distant (default: 30.0m).
        public static let distantDistanceThresholdMeters: Double = 30.0
        
        /// Elapsed seconds of inactivity before a member is marked Stale (default: 30.0s).
        public static let stalePeerThreshold: TimeInterval = 30.0
        
        /// Elapsed seconds of inactivity before a member is marked Offline (default: 180.0s).
        public static let offlinePeerThreshold: TimeInterval = 180.0
        
        /// Direct neighbor heartbeat cadence (default: 2.0s).
        public static let neighborHeartbeatInterval: TimeInterval = 2.0
        
        /// Timeout to prune dead direct neighbor connections (default: 6.0s).
        public static let neighborPruneThreshold: TimeInterval = 6.0
        
        /// AODV routing table entry validity time-to-live (default: 30.0s).
        public static let routingTableTTL: TimeInterval = 30.0
        
        /// Minimum interval between route requests (RREQ) to prevent mesh flooding (default: 10.0s).
        public static let rreqRateLimitInterval: TimeInterval = 10.0
        
        /// Timeout waiting for Route Response (RREP) before retrying (default: 1.5s).
        public static let rreqRetryTimeout: TimeInterval = 1.5
        
        /// Maximum route discovery retries (default: 2).
        public static let rreqMaxRetries: Int = 2
        
        /// Maximum ordinary packet relay forwarding rate (packets/second, default: 2.0).
        public static let ordinaryRelayRateLimit: Double = 8.0
        
        /// Burst token bucket capacity for ordinary packet relaying (default: 4.0).
        public static let ordinaryRelayBurstCapacity: Double = 4.0
        
        /// Urgent SOS packet forwarding rate (packets/second, default: 4.0).
        public static let urgentSOSRateLimit: Double = 4.0
        
        /// Maximum entries preserved in the LRU duplicate suppression cache (default: 1024).
        public static let seenPacketCacheCapacity: Int = 1024
        
        /// Priority outbox queue buffer capacity (default: 64 packets).
        public static let outboxQueueCapacity: Int = 64
        
        /// Maximum retry attempts for outbox transmissions (default: 2 retries = 3 total attempts).
        public static let outboxMaxRetries: Int = 2
        
        /// Initial backoff delay for outbox retries (default: 0.25s).
        public static let outboxBackoffInitialDelay: TimeInterval = 0.25
        
        /// Multiplier for exponential backoff between retries (default: 2.0).
        public static let outboxBackoffMultiplier: Double = 2.0
    }
    
    // MARK: - 3. Chat Messaging Parameters
    public enum Chat {
        public static let carryFastRetryInterval: TimeInterval = 2.0
        public static let carryFastAttemptLimit: Int = 3
        public static let carrySlowRetryInterval: TimeInterval = 30.0
        /// Maximum chat messages held strictly in ephemeral RAM (purged on exit) (default: 50).
        public static let maxHistory: Int = 50
        
        /// Anti-spam client-side cooldown interval between outgoing messages (default: 3.0s).
        public static let cooldownDuration: TimeInterval = 3.0
        
        /// ACK confirmation timeout window before marking a recipient as timed out (default: 15.0s).
        public static let deliveryTimeout: TimeInterval = 15.0
        
        /// Maximum automated retries for unacknowledged messages (default: 2 retries = 3 attempts).
        public static let maxRetries: Int = 2
        
        /// Initial backoff delay for chat message retries (default: 0.5s).
        public static let backoffInitialDelay: TimeInterval = 0.5
        
        /// Multiplier for exponential backoff on unacknowledged chat retries (default: 1.5).
        public static let backoffMultiplier: Double = 1.5
        
        /// Maximum UTF-8 byte boundary for chat text (strictly 20 bytes).
        public static let maxPayloadBytes: Int = 20
    }
    
    // MARK: - 4. Emergency SOS Parameters
    public enum SOS {
        /// Continuous press-and-hold duration required to trigger emergency alarm (default: 3.0s).
        public static let holdDuration: TimeInterval = 1.5
        
        /// Inactivity stillness duration before triggering pre-alarm warning countdown (default: 180.0s = 3 minutes).
        public static let inactivityStillnessDuration: TimeInterval = 180.0
        
        /// Pre-alarm silent haptic warning countdown duration before broadcasting auto-SOS (default: 30.0s).
        public static let inactivityWarningCountdown: TimeInterval = 30.0
        
        /// Acceleration variance threshold (in g) above which device is considered in physical motion (default: 0.15g).
        public static let inactivityMotionThreshold: Double = 0.15
    }
    
    // MARK: - 5. Group Rendezvous / Meeting Point Parameters
    public enum Rendezvous {
        /// Proximity radius in meters for automatic arrival detection (default: 25.0m).
        public static let defaultArrivalRadiusMeters: Double = 25.0
        
        /// Duration past scheduled meetup time before rendezvous auto-clears (default: 3600.0s = 1 hour).
        public static let autoExpirationSeconds: TimeInterval = 3600.0
        
        /// 1-tap quick preset offsets in minutes.
        public static let presetMinutes: [Int] = [0, 15, 30, 60]
    }
    
    // MARK: - 6. Battery & Survival Mode Parameters
    public enum Battery {
        /// Battery percentage threshold triggering Festival Survival Mode (default: 20%).
        public static let survivalThresholdPercent: UInt8 = 20
        
        /// Default duration for Lock Screen Timed Relay mode (default: 1800s = 30 minutes).
        public static let timedRelayDefaultDuration: TimeInterval = 1800.0
    }
    
    // MARK: - 7. Tactical Radar & Directional Navigation Parameters
    public enum Navigation {
        /// Outer polar boundary radius rendered on Tactical Radar (default: 60.0m).
        public static let tacticalRadarRangeMeters: Double = 60.0
        
        /// Proximity threshold where Tactical Radar transitions to Ultra-Wideband (default: 6.0m).
        public static let uwbTransitionDistanceMeters: Double = 6.0
        
        /// Maximum physical range of Apple Ultra-Wideband U1/U2 chips (default: 8.0m).
        public static let uwbMaxRangingDistanceMeters: Double = 8.0
        
        /// Inactivity timeout before an idle UWB session is torn down to preserve battery (default: 30.0s).
        public static let uwbSessionTimeoutSeconds: Double = 30.0
        
        /// Field of view angle for attendee heading vision cones on map (default: 50.0 degrees).
        public static let visionConeFOV: Double = 50.0
    }
}
