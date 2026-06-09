import Foundation

extension String {
    /// Детерминированный FNV-1a хеш для выбора цвета/иконки категории.
    /// `hashValue` использовать нельзя: Swift рандомизирует seed на каждый запуск
    /// процесса, и категории перекрашивались бы при каждом старте приложения.
    var stableHash: Int {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        // Маска до неотрицательного Int — индексация массивов без abs (abs(Int.min) трапается).
        return Int(hash & 0x7fffffffffffffff)
    }
}
