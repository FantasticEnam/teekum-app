//
//  PacketCodec.swift
//  Teekum
//
//  Created by Nicho on 08/11/26.
//

import Foundation
import CoreLocation

// MARK: - Authoritative Packet Codec

/// Authoritative utility for encoding, decoding, quantizing, and validating 56-byte wire datagrams.
public enum PacketCodec: Sendable {
    
    public static let coordinateScalingFactor: Double = 1_000_000.0
    
    // MARK: - Geographic Quantization (~11cm Resolution)
    
    /// Quantizes a latitude or longitude degree into a signed 32-bit big-endian integer.
    public static func quantizeCoordinateDegrees(_ degrees: CLLocationDegrees) -> Int32 {
        Int32((degrees * coordinateScalingFactor).rounded())
    }
    
    /// Dequantizes a signed 32-bit integer back to high-precision double degrees.
    public static func dequantizeCoordinate(latitudeRaw: Int32, longitudeRaw: Int32) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: Double(latitudeRaw) / coordinateScalingFactor,
            longitude: Double(longitudeRaw) / coordinateScalingFactor
        )
    }
    
    // MARK: - Compass Heading Quantization (0..<360 Degrees -> 0..255)
    
    /// Quantizes compass heading (0..<360 degrees) into a single byte.
    public static func quantizeHeading(_ heading: CLLocationDirection) -> UInt8 {
        let normalized = (heading.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        return UInt8(min(255, max(0, Int((normalized * 255.0 / 360.0).rounded()))))
    }
    
    /// Reconstructs compass heading in degrees from a quantized 1-byte value.
    public static func dequantizeHeading(_ byte: UInt8) -> CLLocationDirection {
        Double(byte) * 360.0 / 255.0
    }
    
    // MARK: - Timestamp Quantization (Unix Epoch Seconds)
    
    public static func quantizeTimestamp(_ date: Date) -> UInt32 {
        UInt32(max(0, date.timeIntervalSince1970))
    }
    
    public static func dequantizeTimestamp(_ epochSeconds: UInt32) -> Date {
        Date(timeIntervalSince1970: TimeInterval(epochSeconds))
    }
    
    // MARK: - 10-Byte Cleartext Envelope Serialization
    
    public static func encodeEnvelope(_ envelope: CleartextEnvelope) -> Data {
        var writer = PacketWriter(capacity: PacketConstants.cleartextEnvelopeSize)
        
        // Byte 0: version (high 4 bits) | type (low 4 bits)
        let byte0 = ((envelope.version & 0x0F) << 4) | (envelope.type.rawValue & 0x0F)
        writer.writeUInt8(byte0)
        
        // Byte 1: hopLimit
        writer.writeUInt8(envelope.hopLimit)
        
        // Byte 2: hopCount
        writer.writeUInt8(envelope.hopCount)
        
        // Bytes 3..5: 24-bit session ID
        writer.writeUInt24BigEndian(UInt32(envelope.sessionId))
        
        // Bytes 6..9: 32-bit sequence number
        writer.writeUInt32BigEndian(envelope.sequenceNumber)
        
        return writer.data
    }
    
    public static func decodeEnvelope(from data: Data) throws -> CleartextEnvelope {
        guard data.count >= PacketConstants.cleartextEnvelopeSize else {
            throw PacketCodecError.bufferUnderflow
        }
        
        var reader = PacketReader(data: data)
        let byte0 = try reader.readUInt8()
        let version = (byte0 >> 4) & 0x0F
        guard version == PacketConstants.protocolVersion else {
            throw PacketCodecError.unsupportedVersion(version)
        }
        
        let typeRaw = byte0 & 0x0F
        guard let type = PacketType(rawValue: typeRaw) else {
            throw PacketCodecError.unknownPacketType(typeRaw)
        }
        
        let hopLimit = try reader.readUInt8()
        guard hopLimit >= 1 else {
            throw PacketCodecError.invalidHopLimit(hopLimit)
        }
        
        let hopCount = try reader.readUInt8()
        guard hopCount <= hopLimit else {
            throw PacketCodecError.hopCountExceededLimit(count: hopCount, limit: hopLimit)
        }
        
        let sid24 = try reader.readUInt24BigEndian()
        let sessionId = UInt16(sid24 & 0xFFFF)
        let sequenceNumber = try reader.readUInt32BigEndian()
        
        return CleartextEnvelope(
            version: version,
            type: type,
            hopLimit: hopLimit,
            hopCount: hopCount,
            sessionId: sessionId,
            sequenceNumber: sequenceNumber
        )
    }
    
    // MARK: - 56-Byte Wire Packet Slicing
    
    public static func assembleWirePacket(
        envelope: CleartextEnvelope,
        ciphertext: Data,
        authTag: Data
    ) throws -> Data {
        guard ciphertext.count == PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.invalidPacketSize(expected: PacketConstants.encryptedPayloadSize, actual: ciphertext.count)
        }
        guard authTag.count == PacketConstants.authTagSize else {
            throw PacketCodecError.invalidPacketSize(expected: PacketConstants.authTagSize, actual: authTag.count)
        }
        
        var writer = PacketWriter(capacity: PacketConstants.wirePacketSize)
        writer.writeBytes(encodeEnvelope(envelope))
        writer.writeBytes(ciphertext)
        writer.writeBytes(authTag)
        return writer.data
    }
    
    public static func disassembleWirePacket(_ data: Data) throws -> RawWirePacket {
        guard data.count == PacketConstants.wirePacketSize else {
            throw PacketCodecError.invalidPacketSize(expected: PacketConstants.wirePacketSize, actual: data.count)
        }
        
        let envData = data.subdata(in: 0..<PacketConstants.cleartextEnvelopeSize)
        let ciphertext = data.subdata(in: PacketConstants.cleartextEnvelopeSize..<(PacketConstants.cleartextEnvelopeSize + PacketConstants.encryptedPayloadSize))
        let authTag = data.subdata(in: (PacketConstants.cleartextEnvelopeSize + PacketConstants.encryptedPayloadSize)..<PacketConstants.wirePacketSize)
        
        let envelope = try decodeEnvelope(from: envData)
        return RawWirePacket(envelope: envelope, ciphertext: ciphertext, authTag: authTag)
    }
}
