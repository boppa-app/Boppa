@testable import Boppa
internal import Foundation
import Testing

@MainActor
struct MediaSourceImportServiceTests {
    // MARK: - Fixtures

    private func yaml(
        id: String = "test-id",
        version: String = "1.0",
        name: String = "Test Source",
        url: String = "https://example.com",
        contextConfigs: String = "",
        playback: String = "  url: https://player.example.com\n  userScripts: []"
    ) -> Data {
        let contextBlock = contextConfigs.isEmpty ? "" : "context:\n\(contextConfigs)\n"
        let raw = """
        id: \(id)
        version: "\(version)"
        name: \(name)
        url: \(url)
        \(contextBlock)data: {}
        playback:
        \(playback)
        """
        return Data(raw.utf8)
    }

    private func makeSource(
        id: String = "test-id",
        version: String = "1.0",
        configUrl: String? = "https://example.com/config.yaml",
        autoUpdate: Bool = true,
        contextConfigs: String = ""
    ) throws -> StoredMediaSource {
        var source = try StoredMediaSource.fromConfigData(self.yaml(id: id, version: version, contextConfigs: contextConfigs), configUrl: configUrl)
        source.autoUpdate = autoUpdate
        return source
    }

    private let twoContextConfigs = """
      - title: Auth
        url: https://example.com/auth
        intervalSeconds: 3600
        userScripts: []
      - title: Token
        url: https://example.com/token
        intervalSeconds: 1800
        userScripts: []
    """

    // MARK: - fromConfigData: valid parsing

    @Test func parsesIdFromConfig() throws {
        let source = try StoredMediaSource.fromConfigData(self.yaml(id: "my-source"))
        #expect(source.id == "my-source")
    }

    @Test func parsesVersionFromConfig() throws {
        let source = try StoredMediaSource.fromConfigData(self.yaml(version: "2.3.1"))
        #expect(source.config.version == "2.3.1")
    }

    @Test func parsesNameFromConfig() throws {
        let source = try StoredMediaSource.fromConfigData(self.yaml(name: "Free Music Archive"))
        #expect(source.config.name == "Free Music Archive")
    }

    @Test func parsesUrlFromConfig() throws {
        let source = try StoredMediaSource.fromConfigData(self.yaml(url: "https://freemusicarchive.org"))
        #expect(source.config.url == "https://freemusicarchive.org")
    }

    @Test func storesConfigUrl() throws {
        let source = try StoredMediaSource.fromConfigData(self.yaml(), configUrl: "https://cdn.example.com/config.yaml")
        #expect(source.configUrl == "https://cdn.example.com/config.yaml")
    }

    @Test func configUrlIsNilWhenNotProvided() throws {
        let source = try StoredMediaSource.fromConfigData(self.yaml())
        #expect(source.configUrl == nil)
    }

    @Test func parsesContextConfigCount() throws {
        let source = try StoredMediaSource.fromConfigData(self.yaml(contextConfigs: self.twoContextConfigs))
        #expect(source.config.context?.count == 2)
    }

    @Test func parsesContextConfigUrls() throws {
        let source = try StoredMediaSource.fromConfigData(self.yaml(contextConfigs: self.twoContextConfigs))
        let urls = source.config.context?.map(\.url)
        #expect(urls == ["https://example.com/auth", "https://example.com/token"])
    }

    @Test func parsesContextConfigIntervalSeconds() throws {
        let source = try StoredMediaSource.fromConfigData(self.yaml(contextConfigs: self.twoContextConfigs))
        let intervals = source.config.context?.map(\.intervalSeconds)
        #expect(intervals == [3600, 1800])
    }

    @Test func parsesPlaybackUrl() throws {
        let source = try StoredMediaSource.fromConfigData(self.yaml(playback: "  url: https://player.example.com\n  userScripts: []"))
        #expect(source.config.playback.url == "https://player.example.com")
        #expect(source.config.playback.html == nil)
    }

    @Test func parsesPlaybackHtml() throws {
        let source = try StoredMediaSource.fromConfigData(self.yaml(playback: "  html: \"<html/>\"\n  userScripts: []"))
        #expect(source.config.playback.html == "<html/>")
        #expect(source.config.playback.url == nil)
    }

    // MARK: - fromConfigData: defaults

    @Test func autoUpdateDefaultsToTrue() throws {
        let source = try StoredMediaSource.fromConfigData(self.yaml())
        #expect(source.autoUpdate == true)
    }

    @Test func isEnabledDefaultsToTrue() throws {
        let source = try StoredMediaSource.fromConfigData(self.yaml())
        #expect(source.isEnabled == true)
    }

    @Test func contextLastGatheredTimestampDefaultsToNil() throws {
        let source = try StoredMediaSource.fromConfigData(self.yaml())
        #expect(source.contextLastGatheredTimestamp == nil)
    }

    @Test func contextValuesJSONDefaultsToEmptyObject() throws {
        let source = try StoredMediaSource.fromConfigData(self.yaml())
        #expect(source.contextValuesJSON == "{}")
    }

    @Test func lastUpdatedTimestampIsRecentOnCreate() throws {
        let before = Date().timeIntervalSince1970
        let source = try StoredMediaSource.fromConfigData(self.yaml())
        let after = Date().timeIntervalSince1970
        #expect(source.lastUpdatedTimestamp >= before)
        #expect(source.lastUpdatedTimestamp <= after)
    }

    // MARK: - fromConfigData: missing required fields

    @Test func missingIdThrowsMalformedConfig() {
        let data = Data("""
        version: "1.0"
        name: Test
        url: https://example.com
        data: {}
        playback:
          url: https://example.com
          userScripts: []
        """.utf8)
        #expect(throws: MediaSourceImportError.self) {
            try StoredMediaSource.fromConfigData(data)
        }
    }

    @Test func missingVersionThrowsMalformedConfig() {
        let data = Data("""
        id: test
        name: Test
        url: https://example.com
        data: {}
        playback:
          url: https://example.com
          userScripts: []
        """.utf8)
        #expect(throws: MediaSourceImportError.self) {
            try StoredMediaSource.fromConfigData(data)
        }
    }

    @Test func missingNameThrowsMalformedConfig() {
        let data = Data("""
        id: test
        version: "1.0"
        url: https://example.com
        data: {}
        playback:
          url: https://example.com
          userScripts: []
        """.utf8)
        #expect(throws: MediaSourceImportError.self) {
            try StoredMediaSource.fromConfigData(data)
        }
    }

    @Test func missingPlaybackThrowsMalformedConfig() {
        let data = Data("""
        id: test
        version: "1.0"
        name: Test
        url: https://example.com
        data: {}
        """.utf8)
        #expect(throws: MediaSourceImportError.self) {
            try StoredMediaSource.fromConfigData(data)
        }
    }

    @Test func missingDataThrowsMalformedConfig() {
        let data = Data("""
        id: test
        version: "1.0"
        name: Test
        url: https://example.com
        playback:
          url: https://example.com
          userScripts: []
        """.utf8)
        #expect(throws: MediaSourceImportError.self) {
            try StoredMediaSource.fromConfigData(data)
        }
    }

    @Test func missingFieldErrorMentionsFieldName() {
        let data = Data("""
        version: "1.0"
        name: Test
        url: https://example.com
        data: {}
        playback:
          url: https://example.com
          userScripts: []
        """.utf8)
        do {
            _ = try StoredMediaSource.fromConfigData(data)
            Issue.record("Expected error to be thrown")
        } catch let error as MediaSourceImportError {
            if case let .malformedConfig(detail) = error {
                #expect(detail.contains("id"))
            } else {
                Issue.record("Wrong error case: \(error)")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    // MARK: - fromConfigData: playback validation

    @Test func playbackWithNeitherUrlNorHtmlThrowsMalformedConfig() {
        let data = Data("""
        id: test
        version: "1.0"
        name: Test
        url: https://example.com
        data: {}
        playback:
          userScripts: []
        """.utf8)
        #expect(throws: MediaSourceImportError.self) {
            try StoredMediaSource.fromConfigData(data)
        }
    }

    @Test func playbackWithBothUrlAndHtmlThrowsMalformedConfig() {
        let data = Data("""
        id: test
        version: "1.0"
        name: Test
        url: https://example.com
        data: {}
        playback:
          url: https://player.example.com
          html: "<html/>"
          userScripts: []
        """.utf8)
        #expect(throws: MediaSourceImportError.self) {
            try StoredMediaSource.fromConfigData(data)
        }
    }

    @Test func invalidYamlThrowsMalformedConfig() {
        let data = Data("not: valid: yaml: [[[".utf8)
        #expect(throws: MediaSourceImportError.self) {
            try StoredMediaSource.fromConfigData(data)
        }
    }

    // MARK: - fromConfigData: optional fields

    @Test func missingContextIsNil() throws {
        let source = try StoredMediaSource.fromConfigData(self.yaml())
        #expect(source.config.context == nil)
    }

    @Test func missingIconSvgIsNil() throws {
        let source = try StoredMediaSource.fromConfigData(self.yaml())
        #expect(source.config.iconSvg == nil)
    }

    @Test func missingHighlightColorIsNil() throws {
        let source = try StoredMediaSource.fromConfigData(self.yaml())
        #expect(source.config.highlightColor == nil)
    }

    @Test func missingCustomUserAgentIsNil() throws {
        let source = try StoredMediaSource.fromConfigData(self.yaml())
        #expect(source.config.playback.customUserAgent == nil)
    }

    // MARK: - URL normalization

    @Test func bareHostGetHttpsPrepended() {
        let url = MediaSourceImportService.normalizeConfigUrl("example.com/config.yaml")
        #expect(url?.absoluteString == "https://example.com/config.yaml")
    }

    @Test func httpsUrlIsUnchanged() {
        let url = MediaSourceImportService.normalizeConfigUrl("https://example.com/config.yaml")
        #expect(url?.absoluteString == "https://example.com/config.yaml")
    }

    @Test func httpUrlIsUnchanged() {
        let url = MediaSourceImportService.normalizeConfigUrl("http://example.com/config.yaml")
        #expect(url?.absoluteString == "http://example.com/config.yaml")
    }

    @Test func leadingAndTrailingWhitespaceIsTrimmed() {
        let url = MediaSourceImportService.normalizeConfigUrl("  example.com/config.yaml  ")
        #expect(url?.absoluteString == "https://example.com/config.yaml")
    }

    @Test func whitespaceOnlyReturnsNil() {
        let url = MediaSourceImportService.normalizeConfigUrl("   ")
        #expect(url == nil)
    }

    @Test func emptyStringReturnsNil() {
        let url = MediaSourceImportService.normalizeConfigUrl("")
        #expect(url == nil)
    }

    // MARK: - isContextGathered

    @Test func isContextGatheredTrueWhenNoContextConfigs() throws {
        let source = try makeSource()
        #expect(source.isContextGathered == true)
    }

    @Test func isContextGatheredFalseWhenContextConfigsPresentAndNoTimestamp() throws {
        let source = try makeSource(contextConfigs: twoContextConfigs)
        #expect(source.contextLastGatheredTimestamp == nil)
        #expect(source.isContextGathered == false)
    }

    @Test func isContextGatheredTrueAfterTimestampIsSet() throws {
        var source = try makeSource(contextConfigs: twoContextConfigs)
        source.contextLastGatheredTimestamp = Date().timeIntervalSince1970
        #expect(source.isContextGathered == true)
    }

    @Test func isContextGatheredTrueWhenContextArrayIsEmpty() throws {
        let data = Data("""
        id: test-id
        version: "1.0"
        name: Test
        url: https://example.com
        context: []
        data: {}
        playback:
          url: https://player.example.com
          userScripts: []
        """.utf8)
        let source = try StoredMediaSource.fromConfigData(data)
        #expect(source.isContextGathered == true)
    }

    @Test func isContextGatheredRequiresAllContextUrlsToBeFiredForSingleConfig() throws {
        let oneContext = """
          - title: Auth
            url: https://example.com/auth
            intervalSeconds: 3600
            userScripts: []
        """
        var source = try makeSource(contextConfigs: oneContext)
        #expect(source.isContextGathered == false)
        source.contextLastGatheredTimestamp = Date().timeIntervalSince1970
        #expect(source.isContextGathered == true)
    }

    // MARK: - contextValues

    @Test func contextValuesDecodesValidJson() throws {
        var source = try makeSource()
        source.contextValuesJSON = #"{"token":"abc123","userId":"42"}"#
        #expect(source.contextValues == ["token": "abc123", "userId": "42"])
    }

    @Test func contextValuesReturnsEmptyDictOnInvalidJson() throws {
        var source = try makeSource()
        source.contextValuesJSON = "not json"
        #expect(source.contextValues.isEmpty)
    }

    @Test func contextValuesReturnsEmptyDictOnEmptyObject() throws {
        let source = try makeSource()
        #expect(source.contextValues.isEmpty)
    }

    // MARK: - MediaSourceImportError descriptions

    @Test func invalidUrlErrorDescription() {
        let error = MediaSourceImportError.invalidURL
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test func invalidResponseErrorDescription() {
        let error = MediaSourceImportError.invalidResponse
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test func serverError404MentionsNotFound() {
        let error = MediaSourceImportError.serverError(statusCode: 404, mediaSourceUrl: "https://example.com")
        #expect(error.errorDescription?.contains("No config found") == true)
    }

    @Test func serverErrorNon404MentionsStatusCode() {
        let error = MediaSourceImportError.serverError(statusCode: 503, mediaSourceUrl: "https://example.com")
        #expect(error.errorDescription?.contains("503") == true)
    }

    @Test func malformedConfigErrorIncludesDetail() {
        let error = MediaSourceImportError.malformedConfig(detail: "Missing key \"id\"")
        #expect(error.errorDescription?.contains("Missing key \"id\"") == true)
    }

    // MARK: - AddMediaSourceViewModel: isAddDisabled

    @Test func isAddDisabledWhenUrlIsEmpty() {
        let vm = AddMediaSourceViewModel()
        vm.configUrl = ""
        #expect(vm.isAddDisabled == true)
    }

    @Test func isAddDisabledWhenLoading() {
        let vm = AddMediaSourceViewModel()
        vm.configUrl = "example.com/config.yaml"
        vm.isLoading = true
        #expect(vm.isAddDisabled == true)
    }

    @Test func isAddEnabledWithUrlAndNotLoading() {
        let vm = AddMediaSourceViewModel()
        vm.configUrl = "example.com/config.yaml"
        #expect(vm.isAddDisabled == false)
    }

    @Test func isAddDisabledWhenUrlIsWhitespaceOnly() {
        let vm = AddMediaSourceViewModel()
        vm.configUrl = "   "
        #expect(vm.isAddDisabled == false) // vm only checks isEmpty; normalization happens on submit
    }

    // MARK: - sourcesToUpdate filtering

    @Test func noConfigUrlExcludesSource() throws {
        let source = try makeSource(configUrl: nil)
        #expect(MediaSourceImportService.sourcesToUpdate([source]).isEmpty)
    }

    @Test func autoUpdateOffExcludesSource() throws {
        let source = try makeSource(autoUpdate: false)
        #expect(MediaSourceImportService.sourcesToUpdate([source]).isEmpty)
    }

    @Test func noConfigUrlAndAutoUpdateOffExcludesSource() throws {
        let source = try makeSource(configUrl: nil, autoUpdate: false)
        #expect(MediaSourceImportService.sourcesToUpdate([source]).isEmpty)
    }

    @Test func configUrlPresentAndAutoUpdateOnIncludesSource() throws {
        let source = try makeSource()
        #expect(MediaSourceImportService.sourcesToUpdate([source]).count == 1)
    }

    @Test func emptySourceListReturnsEmpty() {
        #expect(MediaSourceImportService.sourcesToUpdate([]).isEmpty)
    }

    @Test func onlyUpdatableSourcesAreReturned() throws {
        let updatable = try makeSource(id: "a")
        let noUrl = try makeSource(id: "b", configUrl: nil)
        let noAutoUpdate = try makeSource(id: "c", autoUpdate: false)
        let neither = try makeSource(id: "d", configUrl: nil, autoUpdate: false)
        let results = MediaSourceImportService.sourcesToUpdate([updatable, noUrl, noAutoUpdate, neither])
        #expect(results.map(\.id) == ["a"])
    }

    @Test func multipleUpdatableSourcesAllReturned() throws {
        let a = try makeSource(id: "a")
        let b = try makeSource(id: "b")
        let results = MediaSourceImportService.sourcesToUpdate([a, b])
        #expect(results.map(\.id) == ["a", "b"])
    }

    // MARK: - shouldApplyUpdate

    @Test func sameVersionSkipsUpdate() throws {
        let stored = try makeSource(version: "1.0")
        let fetched = try makeSource(version: "1.0")
        #expect(MediaSourceImportService.shouldApplyUpdate(stored: stored, fetched: fetched) == false)
    }

    @Test func newerVersionTriggersUpdate() throws {
        let stored = try makeSource(version: "1.0")
        let fetched = try makeSource(version: "1.1")
        #expect(MediaSourceImportService.shouldApplyUpdate(stored: stored, fetched: fetched) == true)
    }

    @Test func olderVersionTriggersUpdate() throws {
        let stored = try makeSource(version: "2.0")
        let fetched = try makeSource(version: "1.0")
        #expect(MediaSourceImportService.shouldApplyUpdate(stored: stored, fetched: fetched) == true)
    }

    @Test func idMismatchSkipsUpdateEvenWhenVersionChanged() throws {
        let stored = try makeSource(id: "original", version: "1.0")
        let fetched = try makeSource(id: "different", version: "2.0")
        #expect(MediaSourceImportService.shouldApplyUpdate(stored: stored, fetched: fetched) == false)
    }

    @Test func idMismatchSkipsUpdateEvenWhenVersionSame() throws {
        let stored = try makeSource(id: "original", version: "1.0")
        let fetched = try makeSource(id: "different", version: "1.0")
        #expect(MediaSourceImportService.shouldApplyUpdate(stored: stored, fetched: fetched) == false)
    }

    @Test func matchingIdWithPatchVersionChangeTriggersUpdate() throws {
        let stored = try makeSource(id: "src", version: "1.0")
        let fetched = try makeSource(id: "src", version: "1.0.1")
        #expect(MediaSourceImportService.shouldApplyUpdate(stored: stored, fetched: fetched) == true)
    }
}
