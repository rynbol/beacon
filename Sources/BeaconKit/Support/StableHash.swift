import Foundation

/// FNV-1a, 64-bit.
///
/// Swift's own `Hasher` is seeded per process, so it produces a different value
/// on every launch and on every device. The planner uses hashes to break ties,
/// and those tie-breaks have to be reproducible across launches and across the
/// iPhone and the Mac — so the hash has to be written out by hand.
public enum StableHash {
    public static func u64(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}
