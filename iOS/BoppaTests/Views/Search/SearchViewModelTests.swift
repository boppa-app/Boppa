@testable import Boppa
internal import Foundation
import Testing

@MainActor
struct SearchViewModelTests {
    private func makeSource(id: String) throws -> StoredMediaSource {
        let yaml = """
        id: \(id)
        version: "1.0"
        name: \(id)
        url: https://example.com/\(id)
        data: {}
        playback:
          url: https://example.com/\(id)/play
          userScripts: []
        """
        return try StoredMediaSource.fromConfigData(Data(yaml.utf8))
    }

    @Test func selectMediaSourceDoesNotTriggerSearchWhileEditingSearch() throws {
        let vm = SearchViewModel()
        let original = try self.makeSource(id: "original")
        let alternate = try self.makeSource(id: "alternate")
        vm.mediaSources = [original, alternate]
        vm.selectedMediaSource = original
        vm.searchQuery = "test query"

        vm.beginMediaSourceSwitch(isEditingSearch: true)
        vm.selectMediaSource(alternate)

        #expect(vm.selectedMediaSource?.id == alternate.id)
        #expect(vm.isSearching == false)
    }

    @Test func selectMediaSourceDoesNotTriggerSearchWhenQueryEmpty() throws {
        let vm = SearchViewModel()
        let original = try self.makeSource(id: "original")
        let alternate = try self.makeSource(id: "alternate")
        vm.mediaSources = [original, alternate]
        vm.selectedMediaSource = original

        vm.beginMediaSourceSwitch(isEditingSearch: false)
        vm.selectMediaSource(alternate)

        #expect(vm.isSearching == false)
    }

    @Test func cancelRevertsMediaSourceWhenSwitchedWhileEditingSearch() throws {
        let vm = SearchViewModel()
        let original = try self.makeSource(id: "original")
        let alternate = try self.makeSource(id: "alternate")
        vm.mediaSources = [original, alternate]
        vm.selectedMediaSource = original

        vm.beginMediaSourceSwitch(isEditingSearch: true)
        vm.selectMediaSource(alternate)

        #expect(vm.selectedMediaSource?.id == alternate.id)

        vm.cancelMediaSourceSwitchIfNeeded()

        #expect(vm.selectedMediaSource?.id == original.id)
    }

    @Test func cancelKeepsSelectionWhenSwitchedWhileNotEditingSearch() throws {
        let vm = SearchViewModel()
        let original = try self.makeSource(id: "original")
        let alternate = try self.makeSource(id: "alternate")
        vm.mediaSources = [original, alternate]
        vm.selectedMediaSource = original

        vm.beginMediaSourceSwitch(isEditingSearch: false)
        vm.selectMediaSource(alternate)
        vm.cancelMediaSourceSwitchIfNeeded()

        #expect(vm.selectedMediaSource?.id == alternate.id)
    }

    @Test func cancelWithoutPriorSwitchIsNoOp() throws {
        let vm = SearchViewModel()
        let original = try self.makeSource(id: "original")
        vm.mediaSources = [original]
        vm.selectedMediaSource = original

        vm.cancelMediaSourceSwitchIfNeeded()

        #expect(vm.selectedMediaSource?.id == original.id)
    }

    @Test func cancelIsNoOpWhenSourceUnchangedSincePickerOpened() throws {
        let vm = SearchViewModel()
        let original = try self.makeSource(id: "original")
        vm.mediaSources = [original]
        vm.selectedMediaSource = original

        vm.beginMediaSourceSwitch(isEditingSearch: true)
        vm.selectMediaSource(original)
        vm.cancelMediaSourceSwitchIfNeeded()

        #expect(vm.selectedMediaSource?.id == original.id)
    }

    @Test func cancelDoesNotRevertAgainAfterBaselineIsCleared() throws {
        let vm = SearchViewModel()
        let original = try self.makeSource(id: "original")
        let alternate = try self.makeSource(id: "alternate")
        vm.mediaSources = [original, alternate]
        vm.selectedMediaSource = original

        vm.beginMediaSourceSwitch(isEditingSearch: true)
        vm.selectMediaSource(alternate)
        vm.cancelMediaSourceSwitchIfNeeded()

        #expect(vm.selectedMediaSource?.id == original.id)

        vm.selectedMediaSource = alternate
        vm.cancelMediaSourceSwitchIfNeeded()

        #expect(vm.selectedMediaSource?.id == alternate.id)
    }

    @Test func reopeningPickerWithoutCancelingResetsBaselineToLatestSelection() throws {
        let vm = SearchViewModel()
        let a = try self.makeSource(id: "a")
        let b = try self.makeSource(id: "b")
        let c = try self.makeSource(id: "c")
        vm.mediaSources = [a, b, c]
        vm.selectedMediaSource = a

        vm.beginMediaSourceSwitch(isEditingSearch: true)
        vm.selectMediaSource(b)
        vm.beginMediaSourceSwitch(isEditingSearch: true)
        vm.selectMediaSource(c)
        vm.cancelMediaSourceSwitchIfNeeded()

        #expect(vm.selectedMediaSource?.id == b.id)
    }
}
