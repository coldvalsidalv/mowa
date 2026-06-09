import Foundation

extension String {
    /// Deterministic FNV-1a hash for picking a category color/icon.
    /// `hashValue` cannot be used here: Swift randomizes the seed on every
    /// process launch, so categories would get recolored on each app start.
    var stableHash: Int {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        // Mask to a non-negative Int — array indexing without abs (abs(Int.min) traps).
        return Int(hash & 0x7fffffffffffffff)
    }
}
