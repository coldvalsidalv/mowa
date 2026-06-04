import Foundation

enum VerbumConfig {
    /// Базовый URL бэкенда. Меняем только здесь при деплое в прод.
    #if DEBUG
    static let baseURL = "http://localhost:8787"
    #else
    static let baseURL = "https://verbum-backend.YOUR_ACCOUNT.workers.dev"
    #endif

    /// Публичный токен для чтения контента (vocabulary, grammar).
    /// Не является секретом — контент публично доступен по правилам Teenybase.
    static let contentReadToken = ""
}
