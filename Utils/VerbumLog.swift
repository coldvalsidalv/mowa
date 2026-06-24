import Foundation

@inline(__always)
func verbumLog(_ message: @autoclosure () -> String) {
#if DEBUG
    print(message())
#endif
}
