import Observation
import SwiftUI
import UIKit

/// UIKit UITableView is used instead of SwiftUI List because List exhibits a black row
/// rendering bug when a drag-reorder and track advance happen in quick succession.
/// UITableView gives full control over cell reuse and avoids the flicker entirely.
struct QueueView: View {
    @State private var topFade: CGFloat = 0
    @State private var bottomFade: CGFloat = 1

    private let fadeHeight: CGFloat = 40

    var body: some View {
        QueueTableView(topFade: self.$topFade, bottomFade: self.$bottomFade, fadeHeight: self.fadeHeight)
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.black.opacity(1 - self.topFade), .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: self.fadeHeight)

                    Color.black

                    LinearGradient(
                        colors: [.black, .black.opacity(1 - self.bottomFade)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: self.fadeHeight)
                }
            )
            .background(Color.black)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
}

private struct QueueTableView: UIViewControllerRepresentable {
    @Binding var topFade: CGFloat
    @Binding var bottomFade: CGFloat
    let fadeHeight: CGFloat

    func makeUIViewController(context: Context) -> QueueTableViewController {
        let controller = QueueTableViewController()
        controller.onScroll = { [self] offset, contentHeight, containerHeight in
            self.topFade = min(offset / self.fadeHeight, 1)
            let bottomOffset = contentHeight - containerHeight - offset
            self.bottomFade = min(max(bottomOffset, 0) / self.fadeHeight, 1)
        }
        return controller
    }

    func updateUIViewController(_ controller: QueueTableViewController, context: Context) {}
}

@MainActor
final class QueueTableViewController: UITableViewController {
    private let queueManager = TrackQueueManager.shared
    private let playbackService = PlaybackService.shared
    private let cellReuseId = "QueueCell"

    private var displayedEntries: [QueueEntry] = []
    private var observationTask: Task<Void, Never>?

    var onScroll: ((CGFloat, CGFloat, CGFloat) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.backgroundColor = .black
        self.tableView.separatorStyle = .none
        self.tableView.showsVerticalScrollIndicator = false
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: self.cellReuseId)
        self.tableView.isEditing = true
        self.tableView.allowsSelectionDuringEditing = true

        self.displayedEntries = self.computeDisplayEntries()
        self.startObserving()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.scrollToCurrentTrack(animated: false)
    }

    deinit {
        self.observationTask?.cancel()
    }

    private func startObserving() {
        self.observationTask = Task { [weak self] in
            var lastEntryIds: [UUID] = []
            var lastCurrentIndex: Int = -1
            var lastRepeatMode: RepeatMode = .all
            var lastIsPlaying = false
            var lastIsLoading = false

            while !Task.isCancelled {
                guard let self else { return }

                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.queueManager.entries
                        _ = self.queueManager.currentIndex
                        _ = self.queueManager.repeatMode
                        _ = self.playbackService.isPlaying
                        _ = self.playbackService.isLoading
                    } onChange: {
                        continuation.resume()
                    }
                }

                guard !Task.isCancelled else { return }

                let currentEntryIds = self.queueManager.entries.map(\.id)
                let currentIndex = self.queueManager.currentIndex
                let repeatMode = self.queueManager.repeatMode
                let isPlaying = self.playbackService.isPlaying
                let isLoading = self.playbackService.isLoading

                let entriesChanged = currentEntryIds != lastEntryIds
                let indexChanged = currentIndex != lastCurrentIndex
                let repeatChanged = repeatMode != lastRepeatMode
                let playStateChanged = isPlaying != lastIsPlaying || isLoading != lastIsLoading

                if entriesChanged || repeatChanged {
                    lastEntryIds = currentEntryIds
                    lastRepeatMode = repeatMode
                    lastCurrentIndex = currentIndex
                    lastIsPlaying = isPlaying
                    lastIsLoading = isLoading
                    self.reloadData()
                } else if indexChanged {
                    lastCurrentIndex = currentIndex
                    lastIsPlaying = isPlaying
                    lastIsLoading = isLoading
                    self.handleCurrentIndexChange()
                } else if playStateChanged {
                    lastIsPlaying = isPlaying
                    lastIsLoading = isLoading
                    self.refreshVisibleCells()
                }
            }
        }
    }

    private func computeDisplayEntries() -> [QueueEntry] {
        let entries = self.queueManager.entries
        let currentIndex = self.queueManager.currentIndex
        let repeatMode = self.queueManager.repeatMode

        switch repeatMode {
        case .one:
            return self.queueManager.currentEntry.map { [$0] } ?? []
        case .all:
            guard !entries.isEmpty else { return [] }
            return Array(entries[currentIndex...]) + Array(entries[..<currentIndex])
        }
    }

    private func reloadData() {
        self.displayedEntries = self.computeDisplayEntries()
        self.tableView.reloadData()
    }

    private func handleCurrentIndexChange() {
        self.displayedEntries = self.computeDisplayEntries()
        self.tableView.reloadData()
        if !self.displayedEntries.isEmpty {
            self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
        }
    }

    private func refreshVisibleCells() {
        for cell in self.tableView.visibleCells {
            guard let indexPath = self.tableView.indexPath(for: cell) else { continue }
            self.configureCell(cell, at: indexPath)
        }
    }

    private func scrollToCurrentTrack(animated: Bool) {
        guard !self.displayedEntries.isEmpty else { return }
        self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: animated)
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        let contentHeight = scrollView.contentSize.height
        let containerHeight = scrollView.bounds.height
        self.onScroll?(offset, contentHeight, containerHeight)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.displayedEntries.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseId, for: indexPath)
        self.configureCell(cell, at: indexPath)
        return cell
    }

    private func configureCell(_ cell: UITableViewCell, at indexPath: IndexPath) {
        guard indexPath.row < self.displayedEntries.count else { return }
        let entry = self.displayedEntries[indexPath.row]
        let currentId = self.queueManager.currentEntry?.id
        let isCurrent = entry.id == currentId
        let repeatMode = self.queueManager.repeatMode

        let trackRow = TrackRow(
            track: entry.track,
            isSelected: isCurrent,
            isLoading: self.playbackService.isLoading,
            isPlaying: self.playbackService.isPlaying && isCurrent,
            style: .compact,
            onTap: { [weak self] in
                guard let self else { return }
                if repeatMode != .one {
                    self.queueManager.jump(to: entry)
                    self.playbackService.playTrack(entry.track)
                }
            },
            onDeleteTap: entry.userAdded ? { [weak self] in
                guard let self else { return }
                self.queueManager.removeFromQueue(entry)
            } : nil,
            isDeleteDisabled: isCurrent
        )

        cell.contentConfiguration = UIHostingConfiguration { trackRow }
            .background(.black)
            .margins(.all, 0)
        cell.backgroundColor = .black
        cell.selectionStyle = .none
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        self.queueManager.repeatMode != .one && indexPath.row != 0
    }

    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        if proposedDestinationIndexPath.row == 0 {
            return IndexPath(row: 1, section: 0)
        }
        return proposedDestinationIndexPath
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let entry = self.displayedEntries.remove(at: sourceIndexPath.row)
        self.displayedEntries.insert(entry, at: destinationIndexPath.row)
        self.queueManager.applyReorder(self.displayedEntries)
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        .none
    }

    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        false
    }
}
