import Foundation

struct CategoryStorage: RawRepresentable, Codable {
    var items: [String]
    
    init() { self.items = [] }
    init(items: [String]) { self.items = items }
    
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([String].self, from: data)
        else { return nil }
        self.items = result
    }
    
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(items),
              let result = String(data: data, encoding: .utf8)
        else { return "[]" }
        return result
    }
}
