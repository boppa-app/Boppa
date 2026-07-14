import Foundation

@Observable
final class DeepLinkAddMediaSourceRequest {
    static let shared = DeepLinkAddMediaSourceRequest()

    struct Request: Identifiable, Equatable {
        let id = UUID()
        let configUrl: String
    }

    private(set) var pending: Request?

    private init() {}

    func submit(configUrl: String) {
        self.pending = Request(configUrl: configUrl)
    }

    func clear() {
        self.pending = nil
    }
}
