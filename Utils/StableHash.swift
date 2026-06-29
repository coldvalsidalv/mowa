import Foundation

// hashValue нельзя: Swift рандомизирует seed на каждый запуск процесса.
func stableHashOf(_ s: String) -> Int {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in s.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x100000001b3
    }
    // Маска до неотрицательного Int — индексация массивов без abs (abs(Int.min) трапается).
    return Int(hash & 0x7fffffffffffffff)
}

extension String {
    var stableHash: Int { stableHashOf(self) }
}
