import Foundation

/// Makes the same UUID from the same text, every time.
///
/// Used to give each planned reminder alarm a predictable AlarmKit ID, so
/// re-planning can tell "already scheduled" from "new" without extra storage.
/// Based on two FNV-1a hashes — fine for identifiers, NOT for security.
public enum StableID {
    public static func uuid(from text: String) -> UUID {
        let bytes = Array(text.utf8)
        let high = fnv1a(bytes, seed: 0xcbf2_9ce4_8422_2325)
        let low = fnv1a(bytes, seed: 0x8422_2325_cbf2_9ce4)

        var raw = [UInt8](repeating: 0, count: 16)
        for index in 0..<8 {
            raw[index] = UInt8(truncatingIfNeeded: high >> (56 - 8 * UInt64(index)))
            raw[index + 8] = UInt8(truncatingIfNeeded: low >> (56 - 8 * UInt64(index)))
        }
        raw[6] = (raw[6] & 0x0F) | 0x50 // version 5 style
        raw[8] = (raw[8] & 0x3F) | 0x80 // RFC 4122 variant

        return UUID(uuid: (
            raw[0], raw[1], raw[2], raw[3], raw[4], raw[5], raw[6], raw[7],
            raw[8], raw[9], raw[10], raw[11], raw[12], raw[13], raw[14], raw[15]
        ))
    }

    private static func fnv1a(_ bytes: [UInt8], seed: UInt64) -> UInt64 {
        var hash = seed
        for byte in bytes {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}
