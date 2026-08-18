import Observation
import SwiftUI
import UIKit

/// UIKit UITableView is used instead of SwiftUI List for two reasons:
/// 1. List exhibits a black row rendering bug when a drag-reorder and track advance happen in
///    quick succession.
/// 2. performBatchUpdates gives full control over row animations. On "previous", the incoming
///    track slides in horizontally rather than flying up from the bottom of the list as SwiftUI
///    would animate a rotation of the underlying array.
struct QueueView: View {
    @State private var topFade: CGFloat = 0
    @State private var bottomFade: CGFloat = 1

    private let fadeHeight: CGFloat = 40

    var body: some View {
        QueueTableView(
            topFade: self.$topFade,
            bottomFade: self.$bottomFade,
            fadeHeight: self.fadeHeight
        )
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
        .background(Color.charcoal)
        .cornerRadius(12)
    }
}

private struct QueueTableView: UIViewControllerRepresentable {
    @Binding var topFade: CGFloat
    @Binding var bottomFade: CGFloat
    let fadeHeight: CGFloat

    func makeUIViewController(context: Context) -> QueueTableViewController {
        let controller = QueueTableViewController()
        controller.onScroll = { [self] topDistance, bottomDistance in
            self.topFade = min(topDistance / self.fadeHeight, 1)
            self.bottomFade = min(bottomDistance / self.fadeHeight, 1)
        }
        return controller
    }

    func updateUIViewController(_ controller: QueueTableViewController, context: Context) {}
}

private struct QueueRadioStatusRow: View {
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        HStack(spacing: 10) {
            if self.isLoading {
                SpinnerView(tint: .white, lineWidth: 3)
                    .frame(width: 18, height: 18)
            } else if let errorMessage {
                ErrorMessageView(message: errorMessage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
    }
}

@MainActor
final class QueueTableViewController: UITableViewController {
    private let queueManager = TrackQueueManager.shared
    private let playbackService = PlaybackService.shared
    private let radioService = RadioService.shared
    private let cellReuseId = "QueueCell"
    private let statusCellReuseId = "QueueStatusCell"

    private var displayedEntries: [QueueEntry] = []
    private var observationTask: Task<Void, Never>?
    private var directTapPending = false

    var onScroll: ((CGFloat, CGFloat) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.backgroundColor = .charcoal
        self.tableView.separatorStyle = .none
        self.tableView.showsVerticalScrollIndicator = false
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: self.cellReuseId)
        self.tableView.register(
            UITableViewCell.self,
            forCellReuseIdentifier: self.statusCellReuseId
        )
        self.tableView.isEditing = true
        self.tableView.allowsSelectionDuringEditing = true

        self.displayedEntries = self.computeDisplayEntries()
        self.startObserving()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.reloadData()
        self.scrollToCurrentTrack(animated: false)
    }

    deinit {
        self.observationTask?.cancel()
    }

    private func startObserving() {
        self.observationTask = Task { [weak self] in
            var lastEntryIds = TrackQueueManager.shared.activeEntries.map(\.id)
            var lastCurrentIndex = TrackQueueManager.shared.currentIndex
            var lastRepeatMode = TrackQueueManager.shared.repeatMode
            var lastIsPlaying = PlaybackService.shared.isPlaying
            var lastIsLoading = PlaybackService.shared.isLoading
            var lastIsFetchingRadio = RadioService.shared.isFetchingRadio
            var lastRadioError = RadioService.shared.radioError

            while !Task.isCancelled {
                guard let self else { return }

                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.queueManager.entries
                        _ = self.queueManager.shuffledEntries
                        _ = self.queueManager.shuffleMode
                        _ = self.queueManager.currentIndex
                        _ = self.queueManager.repeatMode
                        _ = self.playbackService.isPlaying
                        _ = self.playbackService.isLoading
                        _ = self.radioService.isFetchingRadio
                        _ = self.radioService.radioError
                    } onChange: {
                        continuation.resume()
                    }
                }

                guard !Task.isCancelled else { return }

                let currentEntryIds = self.queueManager.activeEntries.map(\.id)
                let currentIndex = self.queueManager.currentIndex
                let repeatMode = self.queueManager.repeatMode
                let isPlaying = self.playbackService.isPlaying
                let isLoading = self.playbackService.isLoading
                let isFetchingRadio = self.radioService.isFetchingRadio
                let radioError = self.radioService.radioError

                let entriesChanged = currentEntryIds != lastEntryIds
                let indexChanged = currentIndex != lastCurrentIndex
                let repeatChanged = repeatMode != lastRepeatMode
                let playStateChanged = isPlaying != lastIsPlaying || isLoading != lastIsLoading
                let radioStatusChanged = isFetchingRadio != lastIsFetchingRadio || radioError !=
                    lastRadioError

                if entriesChanged || repeatChanged || radioStatusChanged {
                    lastEntryIds = currentEntryIds
                    lastRepeatMode = repeatMode
                    lastCurrentIndex = currentIndex
                    lastIsPlaying = isPlaying
                    lastIsLoading = isLoading
                    lastIsFetchingRadio = isFetchingRadio
                    lastRadioError = radioError
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
        let entries = self.queueManager.activeEntries
        let currentIndex = self.queueManager.currentIndex
        let repeatMode = self.queueManager.repeatMode

        switch repeatMode {
        case .one:
            return self.queueManager.currentEntry.map { [$0] } ?? []
        case .off:
            guard !entries.isEmpty else { return [] }
            return Array(entries[currentIndex...]).filter { $0.track.isMediaSourceEnabled }
        case .all:
            guard !entries.isEmpty else { return [] }
            let reordered = Array(entries[currentIndex...]) + Array(entries[..<currentIndex])
            return reordered.filter { $0.track.isMediaSourceEnabled }
        }
    }

    private func reloadData() {
        self.displayedEntries = self.computeDisplayEntries()
        self.tableView.reloadData()
        self.tableView.layoutIfNeeded()
        self.syncFadeState()
    }

    private func handleCurrentIndexChange() {
        let oldEntries = self.displayedEntries
        let newEntries = self.computeDisplayEntries()

        let wasDirect = self.directTapPending
        self.directTapPending = false

        guard !oldEntries.isEmpty, !newEntries.isEmpty else {
            self.displayedEntries = newEntries
            self.tableView.reloadData()
            self.tableView.layoutIfNeeded()
            self.syncFadeState()
            return
        }

        let oldIndexById = Dictionary(uniqueKeysWithValues: oldEntries.enumerated()
            .map { ($1.id, $0) })
        let oldPositionOfNewTop = newEntries.first.flatMap { oldIndexById[$0.id] }

        self.applyReorderDiff(
            from: oldEntries,
            to: newEntries,
            wasDirect: wasDirect,
            oldPositionOfNewTop: oldPositionOfNewTop
        )
    }

    private func applyReorderDiff(
        from oldEntries: [QueueEntry],
        to newEntries: [QueueEntry],
        wasDirect: Bool,
        oldPositionOfNewTop: Int?
    ) {
        self.displayedEntries = newEntries

        let newIndexById = Dictionary(uniqueKeysWithValues: newEntries.enumerated()
            .map { ($1.id, $0) })
        let oldIdsSet = Set(oldEntries.map(\.id))
        let newIdsSet = Set(newEntries.map(\.id))

        let snapTopToHead = !wasDirect && (oldPositionOfNewTop ?? 0) > 1

        let deletes = oldEntries.enumerated()
            .filter { !newIdsSet.contains($1.id) }
            .map { IndexPath(row: $0.offset, section: 0) }
        let inserts = newEntries.enumerated()
            .filter { !oldIdsSet.contains($1.id) }
            .map { IndexPath(row: $0.offset, section: 0) }

        var regularMoves: [(IndexPath, IndexPath)] = []
        var snapFrom: IndexPath?

        for (oldIdx, entry) in oldEntries.enumerated() {
            guard let newIdx = newIndexById[entry.id], newIdx != oldIdx else { continue }
            if snapTopToHead, newIdx == 0 {
                snapFrom = IndexPath(row: oldIdx, section: 0)
            } else {
                regularMoves.append((
                    IndexPath(row: oldIdx, section: 0),
                    IndexPath(row: newIdx, section: 0)
                ))
            }
        }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.1)
        self.tableView.performBatchUpdates({
            if !deletes.isEmpty { self.tableView.deleteRows(at: deletes, with: .fade) }
            if !inserts.isEmpty { self.tableView.insertRows(at: inserts, with: .fade) }
            for (from, to) in regularMoves {
                self.tableView.moveRow(at: from, to: to)
            }
            if let from = snapFrom {
                self.tableView.deleteRows(at: [from], with: .none)
                self.tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .none)
            }
        }, completion: nil)
        self.refreshVisibleCells()
        self.syncFadeState()
        CATransaction.commit()
    }

    private func refreshVisibleCells() {
        for cell in self.tableView.visibleCells {
            guard let indexPath = self.tableView.indexPath(for: cell) else { continue }
            if indexPath.row >= self.displayedEntries.count {
                self.configureStatusCell(cell)
            } else {
                self.configureCell(cell, at: indexPath)
            }
        }
    }

    private var isRadioStatusRowVisible: Bool {
        self.queueManager.shuffleMode == .radio
            && (self.radioService.isFetchingRadio || self.radioService.radioError != nil)
    }

    private func scrollToCurrentTrack(animated: Bool) {
        guard !self.displayedEntries.isEmpty else { return }
        self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: animated)
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.syncFadeState()
    }

    private func syncFadeState() {
        let offset = self.tableView.contentOffset.y + self.tableView.adjustedContentInset.top
        let contentHeight = self.tableView.contentSize.height
        let containerHeight = self.tableView.bounds.height
        let bottomDistance = max(contentHeight - containerHeight - offset, 0)
        self.onScroll?(max(offset, 0), bottomDistance)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.displayedEntries.count + (self.isRadioStatusRowVisible ? 1 : 0)
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        if indexPath.row >= self.displayedEntries.count {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: self.statusCellReuseId,
                for: indexPath
            )
            self.configureStatusCell(cell)
            return cell
        }
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
                    self.directTapPending = true
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
            .background(Color.charcoal)
            .margins(.all, 0)
        cell.backgroundColor = .charcoal
        cell.selectionStyle = .none
    }

    private func configureStatusCell(_ cell: UITableViewCell) {
        let statusRow = QueueRadioStatusRow(
            isLoading: self.radioService.isFetchingRadio,
            errorMessage: self.radioService.isFetchingRadio ? nil : self.radioService.radioError
        )
        cell.contentConfiguration = UIHostingConfiguration { statusRow }
            .background(Color.charcoal)
            .margins(.all, 0)
        cell.backgroundColor = .charcoal
        cell.selectionStyle = .none
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        self.queueManager.repeatMode != .one && indexPath.row != 0 && indexPath.row < self
            .displayedEntries.count
    }

    override func tableView(
        _ tableView: UITableView,
        targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
        toProposedIndexPath proposedDestinationIndexPath: IndexPath
    ) -> IndexPath {
        if proposedDestinationIndexPath.row == 0 {
            return IndexPath(row: 1, section: 0)
        }
        if proposedDestinationIndexPath.row >= self.displayedEntries.count {
            return IndexPath(row: max(self.displayedEntries.count - 1, 0), section: 0)
        }
        return proposedDestinationIndexPath
    }

    override func tableView(
        _ tableView: UITableView,
        moveRowAt sourceIndexPath: IndexPath,
        to destinationIndexPath: IndexPath
    ) {
        let entry = self.displayedEntries.remove(at: sourceIndexPath.row)
        self.displayedEntries.insert(entry, at: destinationIndexPath.row)
        self.queueManager.applyReorder(self.displayedEntries)
    }

    override func tableView(
        _ tableView: UITableView,
        editingStyleForRowAt indexPath: IndexPath
    ) -> UITableViewCell.EditingStyle {
        .none
    }

    override func tableView(
        _ tableView: UITableView,
        shouldIndentWhileEditingRowAt indexPath: IndexPath
    ) -> Bool {
        false
    }
}
