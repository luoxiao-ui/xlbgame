import Cocoa

struct GitFileStatus {
    let x: Character
    let y: Character
    let path: String

    var isStaged: Bool { x != " " && x != "?" }
    var isUntracked: Bool { x == "?" && y == "?" }

    var isConflicted: Bool {
        let code = "\(x)\(y)"
        return ["DD", "AU", "UD", "UA", "DU", "AA", "UU"].contains(code)
    }

    var badge: String {
        if isUntracked { return "UNTRACKED" }
        return "\(x)\(y)"
    }
}

struct GitCommitItem {
    let graph: String
    let hash: String
    let date: String
    let author: String
    let refs: String
    let subject: String
}

struct GitOperationState {
    let name: String
    let continueArgs: [String]?
    let abortArgs: [String]?
}

final class CommitGraphView: NSView {
    private let laneColors: [NSColor] = [
        NSColor(calibratedRed: 0.67, green: 0.75, blue: 0.23, alpha: 1),
        NSColor(calibratedRed: 0.41, green: 0.55, blue: 0.94, alpha: 1),
        NSColor(calibratedRed: 0.56, green: 0.48, blue: 0.89, alpha: 1),
        NSColor(calibratedRed: 0.96, green: 0.64, blue: 0.26, alpha: 1),
    ]

    var graphText: String = "" {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let chars = Array(graphText)
        let step: CGFloat = 8
        let centerY = bounds.midY

        func laneColor(_ lane: Int) -> NSColor {
            laneColors[abs(lane) % laneColors.count]
        }

        func drawLine(_ from: NSPoint, _ to: NSPoint, _ color: NSColor, width: CGFloat = 1.2) {
            color.setStroke()
            let p = NSBezierPath()
            p.lineWidth = width
            p.move(to: from)
            p.line(to: to)
            p.stroke()
        }

        for (idx, ch) in chars.enumerated() {
            let lane = idx / 2
            let x = CGFloat(idx) * step + 8
            switch ch {
            case "|":
                drawLine(NSPoint(x: x, y: 2), NSPoint(x: x, y: bounds.height - 2), laneColor(lane))
            case "/":
                drawLine(NSPoint(x: x + 3, y: 2), NSPoint(x: x - 3, y: bounds.height - 2), laneColor(lane))
            case "\\":
                drawLine(NSPoint(x: x - 3, y: 2), NSPoint(x: x + 3, y: bounds.height - 2), laneColor(lane))
            case "_":
                drawLine(NSPoint(x: x - 4, y: centerY), NSPoint(x: x + 4, y: centerY), laneColor(lane))
            case "*":
                let color = laneColor(lane)
                let dotRect = NSRect(x: x - 3.2, y: centerY - 3.2, width: 6.4, height: 6.4)
                color.setFill()
                NSBezierPath(ovalIn: dotRect).fill()
            default:
                continue
            }
        }
    }
}

final class GitService {
    var repoURL: URL?

    func setRepo(_ url: URL) {
        repoURL = url
    }

    func run(_ args: [String]) throws -> String {
        guard let repoURL else {
            throw NSError(domain: "GitVisualMac", code: 1, userInfo: [NSLocalizedDescriptionKey: "请先选择 Git 仓库目录"])
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + args
        process.currentDirectoryURL = repoURL

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw NSError(
                domain: "GitVisualMac",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: err.isEmpty ? "Git 命令执行失败" : err]
            )
        }
        return out
    }

    func gitDirURL() throws -> URL {
        guard let repoURL else {
            throw NSError(domain: "GitVisualMac", code: 1, userInfo: [NSLocalizedDescriptionKey: "请先选择 Git 仓库目录"])
        }
        let gitDir = try run(["rev-parse", "--git-dir"]).trimmingCharacters(in: .whitespacesAndNewlines)
        if gitDir.hasPrefix("/") {
            return URL(fileURLWithPath: gitDir)
        }
        return repoURL.appendingPathComponent(gitDir)
    }

    func branches() throws -> [String] {
        let result = try run(["branch", "--format=%(refname:short)"])
        return result.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    func remoteBranches() throws -> [String] {
        let result = try run(["branch", "-r", "--format=%(refname:short)"])
        return result
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty && !$0.contains("->") }
    }

    func currentBranch() throws -> String {
        try run(["rev-parse", "--abbrev-ref", "HEAD"]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func commitList(filter: String?) throws -> [GitCommitItem] {
        func parseCommits(from raw: String, fallbackGraph: String?) -> [GitCommitItem] {
            let records = raw.split(separator: "\u{1e}", omittingEmptySubsequences: true)
            var items: [GitCommitItem] = []
            items.reserveCapacity(records.count)

            for recordSub in records {
                let record = String(recordSub)
                let lines = record.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                guard let payloadLine = lines.first(where: { $0.contains("\u{1f}") }) else { continue }
                guard let sep = payloadLine.firstIndex(of: "\u{1f}") else { continue }

                let graphPart = String(payloadLine[..<sep]).trimmingCharacters(in: .newlines)
                let payloadStart = payloadLine.index(after: sep)
                let payload = String(payloadLine[payloadStart...])
                let payloadParts = payload.split(separator: "\u{1f}", omittingEmptySubsequences: false).map(String.init)
                guard payloadParts.count >= 5 else { continue }

                items.append(
                    GitCommitItem(
                        graph: graphPart.isEmpty ? (fallbackGraph ?? "") : graphPart,
                        hash: payloadParts[0],
                        date: payloadParts[1],
                        author: payloadParts[2],
                        refs: payloadParts[3].trimmingCharacters(in: .whitespaces),
                        subject: payloadParts[4].replacingOccurrences(of: "\u{1e}", with: "")
                    )
                )
            }
            return items
        }

        var args = [
            "log", "--graph", "--all", "-n", "500", "--date=format:%Y-%m-%d %H:%M",
            "--pretty=format:%h%x1f%ad%x1f%an%x1f%d%x1f%s%x1e"
        ]
        if let filter, !filter.isEmpty {
            args.append(contentsOf: ["--grep", filter, "--regexp-ignore-case"])
        }

        let raw = try run(args)
        var commits = parseCommits(from: raw, fallbackGraph: nil)
        if !commits.isEmpty {
            return commits
        }

        // Fallback for repos/configs where --graph output breaks machine parsing.
        var fallbackArgs = [
            "log", "--all", "-n", "500", "--date=format:%Y-%m-%d %H:%M",
            "--pretty=format:%h%x1f%ad%x1f%an%x1f%d%x1f%s%x1e"
        ]
        if let filter, !filter.isEmpty {
            fallbackArgs.append(contentsOf: ["--grep", filter, "--regexp-ignore-case"])
        }
        let fallbackRaw = try run(fallbackArgs)
        commits = parseCommits(from: fallbackRaw, fallbackGraph: "*")
        return commits
    }

    func commitGraphText(filter: String?) throws -> String {
        var args = ["log", "--graph", "--decorate", "--oneline", "--all", "-n", "200"]
        if let filter, !filter.isEmpty {
            args.append(contentsOf: ["--grep", filter, "--regexp-ignore-case"])
        }
        return try run(args)
    }

    func commitDetails(hash: String) throws -> String {
        try run(["show", "--stat", "--patch", "--pretty=fuller", hash])
    }

    func compareCommits(base: String, head: String) throws -> String {
        let summary = try run(["log", "--oneline", "--decorate", "\(base)..\(head)"])
        let patch = try run(["diff", "--stat", "--patch", "\(base)..\(head)"])
        return """
        Compare: \(base) -> \(head)

        Commits in range:
        \(summary.isEmpty ? "(none)" : summary)

        Diff:
        \(patch.isEmpty ? "(no diff)" : patch)
        """
    }

    func changedFilesBetween(base: String, head: String) throws -> [String] {
        let raw = try run(["diff", "--name-only", "\(base)..\(head)"])
        return raw.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    func diffFileBetween(base: String, head: String, path: String) throws -> String {
        try run(["diff", "--", "\(base)..\(head)", "--", path])
    }

    func branchRecentLog(branch: String) throws -> String {
        try run(["log", "--oneline", "--decorate", "-n", "30", branch])
    }

    func statusFiles() throws -> [GitFileStatus] {
        let raw = try run(["status", "--porcelain=1"])
        return raw.split(separator: "\n").compactMap { lineSub in
            let line = String(lineSub)
            guard line.count >= 3 else { return nil }
            let chars = Array(line)
            let x = chars[0]
            let y = chars[1]
            let pathStart = line.index(line.startIndex, offsetBy: 3)
            let path = String(line[pathStart...]).trimmingCharacters(in: .whitespaces)
            return GitFileStatus(x: x, y: y, path: path)
        }
    }

    func diff(for file: GitFileStatus) throws -> String {
        if file.isStaged {
            return try run(["diff", "--staged", "--", file.path])
        }
        return try run(["diff", "--", file.path])
    }

    func diff(path: String) throws -> String {
        try run(["diff", "--", path])
    }

    func fileHistory(path: String) throws -> String {
        try run(["log", "--follow", "--date=short", "--pretty=format:%h %ad %an %s", "--", path])
    }

    func blame(path: String) throws -> String {
        try run(["blame", "--date=short", "--", path])
    }

    func stage(file: String) throws { _ = try run(["add", "--", file]) }
    func stageAll() throws { _ = try run(["add", "-A"]) }

    func unstage(file: String) throws { _ = try run(["restore", "--staged", "--", file]) }
    func unstageAll() throws { _ = try run(["restore", "--staged", "."]) }

    func discard(file: String) throws { _ = try run(["restore", "--", file]) }

    func commit(message: String) throws { _ = try run(["commit", "-m", message]) }

    func checkout(branch: String) throws { _ = try run(["checkout", branch]) }
    func checkoutRemote(remote: String) throws {
        do {
            _ = try run(["checkout", "--track", remote])
        } catch {
            _ = try run(["checkout", remote])
        }
    }
    func createBranch(name: String) throws { _ = try run(["checkout", "-b", name]) }
    func createBranch(name: String, from startPoint: String) throws { _ = try run(["checkout", "-b", name, startPoint]) }
    func renameBranch(old: String, new: String) throws { _ = try run(["branch", "-m", old, new]) }
    func deleteBranch(name: String) throws { _ = try run(["branch", "-D", name]) }
    func pushBranch(name: String) throws { _ = try run(["push", "-u", "origin", name]) }
    func merge(branch: String) throws { _ = try run(["merge", "--no-ff", branch]) }
    func rebase(onto branch: String) throws { _ = try run(["rebase", branch]) }

    func cherryPick(hash: String) throws { _ = try run(["cherry-pick", hash]) }
    func revert(hash: String) throws { _ = try run(["revert", "--no-edit", hash]) }

    func reset(to hash: String, mode: String) throws { _ = try run(["reset", mode, hash]) }

    func fetch() throws { _ = try run(["fetch", "--all", "--prune"]) }
    func pull() throws { _ = try run(["pull", "--rebase"]) }
    func push() throws { _ = try run(["push"]) }

    func stashes() throws -> [String] {
        let raw = try run(["stash", "list"])
        return raw.split(separator: "\n").map(String.init)
    }

    func stashPush(message: String?) throws {
        if let message, !message.isEmpty {
            _ = try run(["stash", "push", "-u", "-m", message])
        } else {
            _ = try run(["stash", "push", "-u"])
        }
    }

    func stashApply(ref: String) throws { _ = try run(["stash", "apply", ref]) }
    func stashPop(ref: String) throws { _ = try run(["stash", "pop", ref]) }
    func stashDrop(ref: String) throws { _ = try run(["stash", "drop", ref]) }

    func tags() throws -> [String] {
        let raw = try run(["tag", "--sort=-creatordate"])
        return raw.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    func tagDetails(name: String) throws -> String {
        try run(["show", "--stat", "--pretty=fuller", name])
    }

    func createTag(name: String, target: String) throws { _ = try run(["tag", name, target]) }
    func deleteTag(name: String) throws { _ = try run(["tag", "-d", name]) }

    func aheadBehind(current: String, against branch: String) throws -> String {
        let raw = try run(["rev-list", "--left-right", "--count", "\(current)...\(branch)"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = raw.split(separator: "\t")
        if parts.count == 2 {
            return "\(current) ahead \(parts[0]) / behind \(parts[1]) vs \(branch)"
        }
        return raw
    }

    func resolveConflict(path: String, strategy: String) throws {
        _ = try run(["checkout", strategy, "--", path])
        _ = try run(["add", "--", path])
    }

    func markResolved(path: String) throws {
        _ = try run(["add", "--", path])
    }

    func operationState() throws -> GitOperationState? {
        let gitDir = try gitDirURL()
        let fm = FileManager.default

        let isRebase = fm.fileExists(atPath: gitDir.appendingPathComponent("rebase-merge").path)
            || fm.fileExists(atPath: gitDir.appendingPathComponent("rebase-apply").path)
            || fm.fileExists(atPath: gitDir.appendingPathComponent("REBASE_HEAD").path)
        if isRebase {
            return GitOperationState(name: "Rebase 进行中", continueArgs: ["rebase", "--continue"], abortArgs: ["rebase", "--abort"])
        }

        if fm.fileExists(atPath: gitDir.appendingPathComponent("MERGE_HEAD").path) {
            return GitOperationState(name: "Merge 进行中", continueArgs: ["merge", "--continue"], abortArgs: ["merge", "--abort"])
        }

        if fm.fileExists(atPath: gitDir.appendingPathComponent("CHERRY_PICK_HEAD").path) {
            return GitOperationState(name: "Cherry-pick 进行中", continueArgs: ["cherry-pick", "--continue"], abortArgs: ["cherry-pick", "--abort"])
        }

        if fm.fileExists(atPath: gitDir.appendingPathComponent("REVERT_HEAD").path) {
            return GitOperationState(name: "Revert 进行中", continueArgs: ["revert", "--continue"], abortArgs: ["revert", "--abort"])
        }

        return nil
    }

    func continueOperation(_ state: GitOperationState) throws {
        guard let args = state.continueArgs else { return }
        _ = try run(args)
    }

    func abortOperation(_ state: GitOperationState) throws {
        guard let args = state.abortArgs else { return }
        _ = try run(args)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate, NSMenuDelegate, NSSplitViewDelegate {
    private enum SidebarKind {
        case sectionLocal
        case sectionRemote
        case sectionTag
        case localBranch
        case remoteBranch
        case tag
    }

    private final class SidebarNode: NSObject {
        let kind: SidebarKind
        let title: String
        var children: [SidebarNode]

        init(kind: SidebarKind, title: String, children: [SidebarNode] = []) {
            self.kind = kind
            self.title = title
            self.children = children
        }
    }

    private let git = GitService()

    private var window: NSWindow!
    private var repoLabel = NSTextField(labelWithString: "未选择仓库")
    private var branchPopup = NSPopUpButton()
    private var compareBranchPopup = NSPopUpButton()
    private var stashPopup = NSPopUpButton()
    private var tagPopup = NSPopUpButton()
    private var branchRelationLabel = NSTextField(labelWithString: "")
    private var operationStateLabel = NSTextField(labelWithString: "")
    private var statusHintLabel = NSTextField(labelWithString: "就绪")

    private var graphText = NSTextView()
    private var diffText = NSTextView()
    private var commitInput = NSTextField(string: "")
    private var commitFilterInput = NSSearchField(string: "")
    private var statusTable = NSTableView()
    private var commitTable = NSTableView()
    private var conflictTable = NSTableView()
    private var branchTable = NSOutlineView()
    private var detailsTabView = NSTabView()
    private var compareFileSearch = NSSearchField(string: "")
    private var compareFilesTable = NSTableView()
    private var compareBaseHash: String?
    private var compareHeadHash: String?
    private var compareFiles: [String] = []
    private var filteredCompareFiles: [String] = []
    private var branchContextMenu: NSMenu?
    private var branchMenuRenameItem: NSMenuItem?
    private var branchMenuDeleteItem: NSMenuItem?
    private var branchMenuPushItem: NSMenuItem?
    private weak var mainSplitView: NSSplitView?

    private var files: [GitFileStatus] = []
    private var commits: [GitCommitItem] = []
    private var conflicts: [GitFileStatus] = []
    private var localBranches: [String] = []
    private var remoteBranches: [String] = []
    private var sidebarTags: [String] = []
    private var sidebarRoots: [SidebarNode] = []
    private var showLocalSection = true
    private var showRemoteSection = true
    private var showTagSection = true
    private var currentOperation: GitOperationState?
    private var interactiveControls: [NSControl] = []
    private var actionDepth = 0
    private let workQueue = DispatchQueue(label: "com.gitvisualmac.worker", qos: .userInitiated)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildUI()
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        }
        return true
    }

    private func buildUI() {
        window = NSWindow(
            contentRect: NSRect(x: 80, y: 80, width: 1600, height: 940),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Git Visual Mac"

        let root = NSView(frame: window.contentView!.bounds)
        root.autoresizingMask = [.width, .height]
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(calibratedWhite: 0.96, alpha: 1).cgColor
        window.contentView = root

        let topBar = NSStackView()
        topBar.orientation = .horizontal
        topBar.spacing = 6
        topBar.alignment = .centerY
        topBar.translatesAutoresizingMaskIntoConstraints = false

        let chooseBtn = NSButton(title: "仓库", target: self, action: #selector(selectRepo))
        let refreshBtn = NSButton(title: "刷新", target: self, action: #selector(refreshAll))
        let checkoutBtn = NSButton(title: "切换分支", target: self, action: #selector(checkoutBranch))
        let newBranchBtn = NSButton(title: "新建", target: self, action: #selector(createBranch))
        let mergeBtn = NSButton(title: "合并", target: self, action: #selector(mergeFromSelectedBranch))
        let rebaseBtn = NSButton(title: "变基", target: self, action: #selector(rebaseOntoSelectedBranch))
        let fetchBtn = NSButton(title: "Fetch", target: self, action: #selector(fetchRepo))
        let pullBtn = NSButton(title: "Pull", target: self, action: #selector(pullRepo))
        let pushBtn = NSButton(title: "Push", target: self, action: #selector(pushRepo))

        let commitDetailBtn = NSButton(title: "提交详情", target: self, action: #selector(showSelectedCommitDetail))
        let compareCommitBtn = NSButton(title: "提交对比", target: self, action: #selector(compareSelectedCommits))
        let cherryPickBtn = NSButton(title: "挑拣", target: self, action: #selector(cherryPickSelectedCommit))
        let revertBtn = NSButton(title: "Revert", target: self, action: #selector(revertSelectedCommit))
        let resetSoftBtn = NSButton(title: "软重置", target: self, action: #selector(resetSoftToSelectedCommit))
        let resetMixedBtn = NSButton(title: "混合重置", target: self, action: #selector(resetMixedToSelectedCommit))
        let resetHardBtn = NSButton(title: "硬重置", target: self, action: #selector(resetHardToSelectedCommit))

        let stashSaveBtn = NSButton(title: "暂存", target: self, action: #selector(saveStash))
        let stashApplyBtn = NSButton(title: "应用", target: self, action: #selector(applyStash))
        let stashPopBtn = NSButton(title: "Pop", target: self, action: #selector(popStash))
        let stashDropBtn = NSButton(title: "删除暂存", target: self, action: #selector(dropStash))
        let createTagBtn = NSButton(title: "新建Tag", target: self, action: #selector(createTag))
        let deleteTagBtn = NSButton(title: "删除Tag", target: self, action: #selector(deleteTag))

        compareBranchPopup.target = self
        compareBranchPopup.action = #selector(compareTargetChanged)

        let topButtons = [
            chooseBtn, refreshBtn, checkoutBtn, newBranchBtn, mergeBtn, rebaseBtn,
            fetchBtn, pullBtn, pushBtn, commitDetailBtn, cherryPickBtn, revertBtn,
            resetSoftBtn, resetMixedBtn, resetHardBtn, stashSaveBtn, stashApplyBtn,
            stashPopBtn, stashDropBtn, createTagBtn, deleteTagBtn
        ]
        let sep1 = NSBox()
        sep1.boxType = .separator
        let sep2 = NSBox()
        sep2.boxType = .separator
        let sep3 = NSBox()
        sep3.boxType = .separator

        let iconMap: [(NSButton, String, String)] = [
            (chooseBtn, "folder", "选择仓库"),
            (refreshBtn, "arrow.clockwise", "刷新"),
            (checkoutBtn, "arrow.triangle.branch", "切换分支"),
            (newBranchBtn, "plus", "新建分支"),
            (mergeBtn, "arrow.triangle.merge", "Merge"),
            (rebaseBtn, "point.bottomleft.forward.to.point.topright.scurvepath", "Rebase"),
            (fetchBtn, "arrow.down.circle", "Fetch"),
            (pullBtn, "arrow.down.left.and.arrow.up.right.circle", "Pull"),
            (pushBtn, "arrow.up.circle", "Push"),
            (commitDetailBtn, "doc.text.magnifyingglass", "提交详情"),
            (cherryPickBtn, "wand.and.stars", "Cherry-pick"),
            (revertBtn, "arrow.uturn.backward", "Revert"),
            (resetSoftBtn, "backward.end", "Reset Soft"),
            (resetMixedBtn, "backward.end.alt", "Reset Mixed"),
            (resetHardBtn, "exclamationmark.triangle", "Reset Hard"),
            (stashSaveBtn, "archivebox", "Stash 保存"),
            (stashApplyBtn, "square.and.arrow.down", "Stash Apply"),
            (stashPopBtn, "shippingbox", "Stash Pop"),
            (stashDropBtn, "trash", "Stash Drop"),
            (createTagBtn, "tag", "新建 Tag"),
            (deleteTagBtn, "tag.slash", "删除 Tag")
        ]
        for b in topButtons {
            b.controlSize = .small
            b.bezelStyle = .rounded
            b.imagePosition = .imageLeading
            b.setButtonType(.momentaryPushIn)
        }
        for (button, symbol, tip) in iconMap {
            if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip) {
                button.image = image
                button.contentTintColor = .labelColor
                button.imagePosition = .imageLeading
            }
            button.toolTip = tip
        }

        branchPopup.controlSize = .small
        compareBranchPopup.controlSize = .small
        stashPopup.controlSize = .small
        tagPopup.controlSize = .small

        repoLabel.lineBreakMode = .byTruncatingMiddle
        repoLabel.font = .systemFont(ofSize: 11)
        repoLabel.textColor = .secondaryLabelColor
        repoLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        topBar.addArrangedSubview(chooseBtn)
        topBar.addArrangedSubview(refreshBtn)
        topBar.addArrangedSubview(branchPopup)
        topBar.addArrangedSubview(checkoutBtn)
        topBar.addArrangedSubview(newBranchBtn)
        topBar.addArrangedSubview(compareBranchPopup)
        topBar.addArrangedSubview(sep1)
        topBar.addArrangedSubview(mergeBtn)
        topBar.addArrangedSubview(rebaseBtn)
        topBar.addArrangedSubview(fetchBtn)
        topBar.addArrangedSubview(pullBtn)
        topBar.addArrangedSubview(pushBtn)
        topBar.addArrangedSubview(sep2)
        topBar.addArrangedSubview(commitDetailBtn)
        topBar.addArrangedSubview(compareCommitBtn)
        topBar.addArrangedSubview(cherryPickBtn)
        topBar.addArrangedSubview(revertBtn)
        topBar.addArrangedSubview(resetSoftBtn)
        topBar.addArrangedSubview(resetMixedBtn)
        topBar.addArrangedSubview(resetHardBtn)
        topBar.addArrangedSubview(sep3)
        topBar.addArrangedSubview(stashPopup)
        topBar.addArrangedSubview(stashSaveBtn)
        topBar.addArrangedSubview(stashApplyBtn)
        topBar.addArrangedSubview(stashPopBtn)
        topBar.addArrangedSubview(stashDropBtn)
        topBar.addArrangedSubview(tagPopup)
        topBar.addArrangedSubview(createTagBtn)
        topBar.addArrangedSubview(deleteTagBtn)
        topBar.addArrangedSubview(branchRelationLabel)
        topBar.addArrangedSubview(repoLabel)

        let mainSplit = NSSplitView()
        mainSplit.translatesAutoresizingMaskIntoConstraints = false
        mainSplit.dividerStyle = .thin
        mainSplit.isVertical = true
        mainSplit.delegate = self
        mainSplit.autosaveName = "GitVisualMacMainSplit"

        let sidebarPanel = NSView()
        sidebarPanel.wantsLayer = true
        sidebarPanel.layer?.backgroundColor = NSColor.clear.cgColor
        let sidebarContent = NSView()
        sidebarContent.translatesAutoresizingMaskIntoConstraints = false
        sidebarPanel.addSubview(sidebarContent)

        let iconBar = NSStackView()
        iconBar.orientation = .vertical
        iconBar.spacing = 8
        iconBar.alignment = .centerX
        iconBar.translatesAutoresizingMaskIntoConstraints = false
        iconBar.wantsLayer = true
        iconBar.layer?.backgroundColor = NSColor(calibratedWhite: 0.92, alpha: 1).cgColor
        iconBar.layer?.cornerRadius = 6
        iconBar.edgeInsets = NSEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)

        let iconNames = ["folder", "clock.arrow.circlepath", "arrow.triangle.branch", "tray", "tag", "bolt", "gearshape"]
        for name in iconNames {
            let iv = NSImageView()
            iv.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            iv.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            iv.contentTintColor = .secondaryLabelColor
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.widthAnchor.constraint(equalToConstant: 16).isActive = true
            iv.heightAnchor.constraint(equalToConstant: 16).isActive = true
            iconBar.addArrangedSubview(iv)
        }

        let branchContainer = NSView()
        branchContainer.translatesAutoresizingMaskIntoConstraints = false

        let sidebarTitle = NSTextField(labelWithString: "分支")
        sidebarTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        sidebarTitle.textColor = .secondaryLabelColor
        sidebarTitle.translatesAutoresizingMaskIntoConstraints = false

        let branchCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("branch_name"))
        branchCol.title = "本地分支"
        branchCol.width = 280
        branchTable.addTableColumn(branchCol)
        branchTable.outlineTableColumn = branchCol
        branchTable.delegate = self
        branchTable.dataSource = self
        branchTable.target = self
        branchTable.doubleAction = #selector(checkoutSelectedBranchFromSidebar)
        branchTable.headerView = nil
        branchTable.style = .sourceList
        branchTable.usesAutomaticRowHeights = true
        branchTable.indentationPerLevel = 12

        let branchScroll = NSScrollView()
        branchScroll.documentView = branchTable
        branchScroll.hasVerticalScroller = true
        branchScroll.hasHorizontalScroller = true
        branchScroll.autohidesScrollers = true
        branchScroll.borderType = .bezelBorder
        branchScroll.translatesAutoresizingMaskIntoConstraints = false

        sidebarContent.addSubview(iconBar)
        sidebarContent.addSubview(branchContainer)
        branchContainer.addSubview(sidebarTitle)
        branchContainer.addSubview(branchScroll)

        NSLayoutConstraint.activate([
            sidebarContent.topAnchor.constraint(equalTo: sidebarPanel.topAnchor, constant: 8),
            sidebarContent.leadingAnchor.constraint(equalTo: sidebarPanel.leadingAnchor, constant: 8),
            sidebarContent.trailingAnchor.constraint(equalTo: sidebarPanel.trailingAnchor, constant: -8),
            sidebarContent.bottomAnchor.constraint(equalTo: sidebarPanel.bottomAnchor, constant: -8),

            iconBar.topAnchor.constraint(equalTo: sidebarContent.topAnchor),
            iconBar.leadingAnchor.constraint(equalTo: sidebarContent.leadingAnchor),
            iconBar.bottomAnchor.constraint(equalTo: sidebarContent.bottomAnchor),
            iconBar.widthAnchor.constraint(equalToConstant: 28),

            branchContainer.topAnchor.constraint(equalTo: sidebarContent.topAnchor),
            branchContainer.leadingAnchor.constraint(equalTo: iconBar.trailingAnchor, constant: 8),
            branchContainer.trailingAnchor.constraint(equalTo: sidebarContent.trailingAnchor),
            branchContainer.bottomAnchor.constraint(equalTo: sidebarContent.bottomAnchor),

            sidebarTitle.topAnchor.constraint(equalTo: branchContainer.topAnchor),
            sidebarTitle.leadingAnchor.constraint(equalTo: branchContainer.leadingAnchor),
            sidebarTitle.trailingAnchor.constraint(equalTo: branchContainer.trailingAnchor),

            branchScroll.topAnchor.constraint(equalTo: sidebarTitle.bottomAnchor, constant: 6),
            branchScroll.leadingAnchor.constraint(equalTo: branchContainer.leadingAnchor),
            branchScroll.trailingAnchor.constraint(equalTo: branchContainer.trailingAnchor),
            branchScroll.bottomAnchor.constraint(equalTo: branchContainer.bottomAnchor),
        ])

        let centerPanel = NSStackView()
        centerPanel.orientation = .vertical
        centerPanel.spacing = 8
        centerPanel.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        let commitToolbar = NSStackView()
        commitToolbar.orientation = .horizontal
        commitToolbar.spacing = 6

        commitFilterInput.placeholderString = "文本或哈希"
        let applyFilterBtn = NSButton(title: "筛选", target: self, action: #selector(applyCommitFilter))
        let clearFilterBtn = NSButton(title: "清空", target: self, action: #selector(clearCommitFilter))
        applyFilterBtn.controlSize = .small
        clearFilterBtn.controlSize = .small
        commitToolbar.addArrangedSubview(commitFilterInput)
        commitToolbar.addArrangedSubview(applyFilterBtn)
        commitToolbar.addArrangedSubview(clearFilterBtn)

        let cGraph = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("commit_graph"))
        cGraph.title = "图谱"
        cGraph.width = 94
        let cSubject = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("commit_subject"))
        cSubject.title = "提交信息"
        let cAuthor = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("commit_author"))
        cAuthor.title = "作者"
        cAuthor.width = 110
        let cDate = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("commit_date"))
        cDate.title = "日期时间"
        cDate.width = 148

        commitTable.addTableColumn(cGraph)
        commitTable.addTableColumn(cSubject)
        commitTable.addTableColumn(cAuthor)
        commitTable.addTableColumn(cDate)
        commitTable.delegate = self
        commitTable.dataSource = self
        commitTable.target = self
        commitTable.doubleAction = #selector(showSelectedCommitDetail)
        commitTable.allowsMultipleSelection = true
        commitTable.rowHeight = 24

        let commitScroll = NSScrollView()
        commitScroll.documentView = commitTable
        commitScroll.hasVerticalScroller = true
        commitScroll.borderType = .bezelBorder

        let commitBar = NSStackView()
        commitBar.orientation = .horizontal
        commitBar.spacing = 6
        commitInput.placeholderString = "输入提交信息..."
        let commitBtn = NSButton(title: "Commit", target: self, action: #selector(commitChanges))
        commitBtn.controlSize = .small
        commitBar.addArrangedSubview(commitInput)
        commitBar.addArrangedSubview(commitBtn)

        centerPanel.addArrangedSubview(commitToolbar)
        centerPanel.addArrangedSubview(commitScroll)
        centerPanel.addArrangedSubview(commitBar)

        let rightPanel = NSStackView()
        rightPanel.orientation = .vertical
        rightPanel.spacing = 8
        rightPanel.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        let detailTitle = NSTextField(labelWithString: "变更详情")
        detailTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        detailTitle.textColor = .secondaryLabelColor

        diffText.isEditable = false
        diffText.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        let diffScroll = NSScrollView()
        diffScroll.documentView = diffText
        diffScroll.hasVerticalScroller = true
        diffScroll.borderType = .bezelBorder

        let fileLabel = NSTextField(labelWithString: "工作区文件")
        fileLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        fileLabel.textColor = .secondaryLabelColor

        let colStatus = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        colStatus.title = "状态"
        colStatus.width = 100
        let colPath = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("path"))
        colPath.title = "文件"

        statusTable.addTableColumn(colStatus)
        statusTable.addTableColumn(colPath)
        statusTable.delegate = self
        statusTable.dataSource = self
        statusTable.headerView = NSTableHeaderView()
        statusTable.target = self
        statusTable.doubleAction = #selector(showSelectedDiff)
        statusTable.rowHeight = 22

        let tableScroll = NSScrollView()
        tableScroll.documentView = statusTable
        tableScroll.hasVerticalScroller = true
        tableScroll.borderType = .bezelBorder
        tableScroll.heightAnchor.constraint(equalToConstant: 160).isActive = true

        let fileActions = NSStackView()
        fileActions.orientation = .horizontal
        fileActions.spacing = 6
        let stageBtn = NSButton(title: "Stage", target: self, action: #selector(stageSelected))
        let stageAllBtn = NSButton(title: "All", target: self, action: #selector(stageAll))
        let unstageBtn = NSButton(title: "Unstage", target: self, action: #selector(unstageSelected))
        let unstageAllBtn = NSButton(title: "UnAll", target: self, action: #selector(unstageAll))
        let discardBtn = NSButton(title: "Discard", target: self, action: #selector(discardSelected))
        let diffBtn = NSButton(title: "Diff", target: self, action: #selector(showSelectedDiff))
        let historyBtn = NSButton(title: "History", target: self, action: #selector(showSelectedFileHistory))
        let blameBtn = NSButton(title: "Blame", target: self, action: #selector(showSelectedFileBlame))
        for b in [stageBtn, stageAllBtn, unstageBtn, unstageAllBtn, discardBtn, diffBtn, historyBtn, blameBtn] {
            b.controlSize = .small
            fileActions.addArrangedSubview(b)
        }

        let conflictHeader = NSStackView()
        conflictHeader.orientation = .horizontal
        conflictHeader.spacing = 8

        let conflictLabel = NSTextField(labelWithString: "冲突处理")
        conflictLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        conflictLabel.textColor = .secondaryLabelColor
        operationStateLabel.font = .systemFont(ofSize: 11)
        operationStateLabel.textColor = .secondaryLabelColor

        conflictHeader.addArrangedSubview(conflictLabel)
        conflictHeader.addArrangedSubview(operationStateLabel)

        let conStatus = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("conflict_status"))
        conStatus.title = "冲突"
        conStatus.width = 100
        let conPath = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("conflict_path"))
        conPath.title = "文件"

        conflictTable.addTableColumn(conStatus)
        conflictTable.addTableColumn(conPath)
        conflictTable.delegate = self
        conflictTable.dataSource = self
        conflictTable.headerView = NSTableHeaderView()
        conflictTable.target = self
        conflictTable.rowHeight = 22

        let conflictScroll = NSScrollView()
        conflictScroll.documentView = conflictTable
        conflictScroll.hasVerticalScroller = true
        conflictScroll.borderType = .bezelBorder
        conflictScroll.heightAnchor.constraint(equalToConstant: 120).isActive = true

        let conflictActions = NSStackView()
        conflictActions.orientation = .horizontal
        conflictActions.spacing = 6

        let oursBtn = NSButton(title: "Ours", target: self, action: #selector(resolveWithOurs))
        let theirsBtn = NSButton(title: "Theirs", target: self, action: #selector(resolveWithTheirs))
        let markResolvedBtn = NSButton(title: "已解决", target: self, action: #selector(markConflictResolved))
        let showConflictBtn = NSButton(title: "查看", target: self, action: #selector(showSelectedConflictDiff))
        let continueBtn = NSButton(title: "Continue", target: self, action: #selector(continueCurrentOperation))
        let abortBtn = NSButton(title: "Abort", target: self, action: #selector(abortCurrentOperation))

        for b in [oursBtn, theirsBtn, markResolvedBtn, showConflictBtn, continueBtn, abortBtn] {
            b.controlSize = .small
            conflictActions.addArrangedSubview(b)
        }

        interactiveControls = topButtons
        interactiveControls.append(contentsOf: [
            branchPopup, compareBranchPopup, stashPopup, tagPopup,
            branchTable, commitTable, statusTable, conflictTable,
            commitInput, commitFilterInput, applyFilterBtn, clearFilterBtn, commitBtn, compareCommitBtn,
            stageBtn, stageAllBtn, unstageBtn, unstageAllBtn, discardBtn, diffBtn, historyBtn, blameBtn,
            oursBtn, theirsBtn, markResolvedBtn, showConflictBtn, continueBtn, abortBtn
        ])

        detailsTabView.translatesAutoresizingMaskIntoConstraints = false
        detailsTabView.tabViewType = .topTabsBezelBorder

        let detailTabContainer = NSStackView()
        detailTabContainer.orientation = .vertical
        detailTabContainer.spacing = 8
        detailTabContainer.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        let compareBar = NSStackView()
        compareBar.orientation = .horizontal
        compareBar.spacing = 6
        compareFileSearch.controlSize = .small
        compareFileSearch.placeholderString = "搜索对比文件"
        compareFileSearch.target = self
        compareFileSearch.action = #selector(filterCompareFiles)
        let compareFileBtn = NSButton(title: "查看文件对比", target: self, action: #selector(showSelectedCompareFileDiff))
        compareFileBtn.controlSize = .small
        compareBar.addArrangedSubview(compareFileSearch)
        compareBar.addArrangedSubview(compareFileBtn)

        let compareFileCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("compare_file"))
        compareFileCol.title = "对比文件"
        compareFilesTable.addTableColumn(compareFileCol)
        compareFilesTable.delegate = self
        compareFilesTable.dataSource = self
        compareFilesTable.headerView = nil
        compareFilesTable.target = self
        compareFilesTable.doubleAction = #selector(showSelectedCompareFileDiffFromTable)
        compareFilesTable.rowHeight = 20
        let compareFileScroll = NSScrollView()
        compareFileScroll.documentView = compareFilesTable
        compareFileScroll.hasVerticalScroller = true
        compareFileScroll.borderType = .bezelBorder
        compareFileScroll.heightAnchor.constraint(equalToConstant: 110).isActive = true

        detailTabContainer.addArrangedSubview(detailTitle)
        detailTabContainer.addArrangedSubview(compareBar)
        detailTabContainer.addArrangedSubview(compareFileScroll)
        detailTabContainer.addArrangedSubview(diffScroll)

        interactiveControls.append(contentsOf: [compareFileSearch, compareFilesTable, compareFileBtn])

        let fileTabContainer = NSStackView()
        fileTabContainer.orientation = .vertical
        fileTabContainer.spacing = 8
        fileTabContainer.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        fileTabContainer.addArrangedSubview(fileLabel)
        fileTabContainer.addArrangedSubview(tableScroll)
        fileTabContainer.addArrangedSubview(fileActions)

        let conflictTabContainer = NSStackView()
        conflictTabContainer.orientation = .vertical
        conflictTabContainer.spacing = 8
        conflictTabContainer.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        conflictTabContainer.addArrangedSubview(conflictHeader)
        conflictTabContainer.addArrangedSubview(conflictScroll)
        conflictTabContainer.addArrangedSubview(conflictActions)

        let detailItem = NSTabViewItem(identifier: "detail")
        detailItem.label = "详情"
        detailItem.view = detailTabContainer

        let fileItem = NSTabViewItem(identifier: "files")
        fileItem.label = "文件"
        fileItem.view = fileTabContainer

        let conflictItem = NSTabViewItem(identifier: "conflicts")
        conflictItem.label = "冲突"
        conflictItem.view = conflictTabContainer

        detailsTabView.addTabViewItem(detailItem)
        detailsTabView.addTabViewItem(fileItem)
        detailsTabView.addTabViewItem(conflictItem)
        detailsTabView.selectTabViewItem(detailItem)

        rightPanel.addArrangedSubview(detailsTabView)

        mainSplit.addArrangedSubview(sidebarPanel)
        mainSplit.addArrangedSubview(centerPanel)
        mainSplit.addArrangedSubview(rightPanel)
        mainSplit.setHoldingPriority(.defaultLow, forSubviewAt: 0)
        mainSplit.setHoldingPriority(.defaultHigh, forSubviewAt: 1)
        mainSplit.setHoldingPriority(.defaultLow, forSubviewAt: 2)
        mainSplit.setPosition(420, ofDividerAt: 0)
        mainSplit.setPosition(1120, ofDividerAt: 1)
        mainSplitView = mainSplit

        root.addSubview(topBar)
        root.addSubview(mainSplit)
        root.addSubview(statusHintLabel)

        statusHintLabel.translatesAutoresizingMaskIntoConstraints = false
        statusHintLabel.font = .systemFont(ofSize: 11)
        statusHintLabel.textColor = .secondaryLabelColor
        statusHintLabel.alignment = .left

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
            topBar.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 10),
            topBar.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -10),
            topBar.heightAnchor.constraint(greaterThanOrEqualToConstant: 30),

            mainSplit.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 8),
            mainSplit.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 10),
            mainSplit.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -10),
            mainSplit.bottomAnchor.constraint(equalTo: statusHintLabel.topAnchor, constant: -6),

            statusHintLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            statusHintLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            statusHintLabel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -6),
        ])

        configureContextMenus()
    }
    @objc private func selectRepo() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"

        if panel.runModal() == .OK, let url = panel.url {
            runAction {
                let dotGit = url.appendingPathComponent(".git")
                guard FileManager.default.fileExists(atPath: dotGit.path) else {
                    throw NSError(domain: "GitVisualMac", code: 2, userInfo: [NSLocalizedDescriptionKey: "该目录不是 Git 仓库"])
                }
                git.setRepo(url)
                repoLabel.stringValue = url.path
                refreshAll()
            }
        }
    }

    @objc private func refreshAll() {
        guard git.repoURL != nil else { return }
        let filter = commitFilterInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let ownsBusyState = actionDepth == 0
        if ownsBusyState {
            setUIBusy(true, message: "刷新中...")
        }

        workQueue.async { [weak self] in
            guard let self else { return }
            do {
                let branches = try self.git.branches()
                let current = try self.git.currentBranch()
                let remoteBranches = try self.git.remoteBranches()
                let stashes = try self.git.stashes()
                let tags = try self.git.tags()
                let commits = try self.git.commitList(filter: filter)
                let graph = try self.git.commitGraphText(filter: filter)
                let files = try self.git.statusFiles()
                let conflicts = files.filter { $0.isConflicted }
                let opState = try self.git.operationState()
                let compareCandidates = branches.filter { $0 != current }
                let aheadBehind = try compareCandidates.first.map { try self.git.aheadBehind(current: current, against: $0) } ?? ""

                DispatchQueue.main.async {
                    self.localBranches = branches
                    self.remoteBranches = remoteBranches
                    self.sidebarTags = tags

                    self.branchPopup.removeAllItems()
                    self.branchPopup.addItems(withTitles: branches)
                    self.branchPopup.selectItem(withTitle: current)

                    self.compareBranchPopup.removeAllItems()
                    self.compareBranchPopup.addItems(withTitles: compareCandidates.isEmpty ? ["(无可比较分支)"] : compareCandidates)
                    self.branchRelationLabel.stringValue = aheadBehind

                    self.stashPopup.removeAllItems()
                    self.stashPopup.addItems(withTitles: stashes.isEmpty ? ["(无 stash)"] : stashes)

                    self.tagPopup.removeAllItems()
                    self.tagPopup.addItems(withTitles: tags.isEmpty ? ["(无 tag)"] : tags)
                    self.rebuildSidebarItems(currentBranch: current)

                    self.commits = commits
                    self.commitTable.reloadData()
                    self.graphText.string = graph

                    self.files = files
                    self.statusTable.reloadData()
                    self.conflicts = conflicts
                    self.conflictTable.reloadData()

                    self.currentOperation = opState
                    if let state = opState {
                        self.operationStateLabel.stringValue = "\(state.name) | 冲突数: \(conflicts.count)"
                        self.operationStateLabel.textColor = .systemRed
                    } else {
                        self.operationStateLabel.stringValue = conflicts.isEmpty ? "无进行中的冲突操作" : "检测到冲突文件 \(conflicts.count) 个"
                        self.operationStateLabel.textColor = conflicts.isEmpty ? .secondaryLabelColor : .systemOrange
                    }

                    if ownsBusyState {
                        self.setUIBusy(false, message: "已刷新: 分支 \(branches.count)/远程 \(remoteBranches.count)/Tag \(tags.count)")
                    } else {
                        self.statusHintLabel.stringValue = "已刷新: 分支 \(branches.count)/远程 \(remoteBranches.count)/Tag \(tags.count)"
                        self.statusHintLabel.textColor = .secondaryLabelColor
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    if ownsBusyState {
                        self.setUIBusy(false, message: nil)
                    }
                    self.showError(error)
                }
            }
        }
    }

    @objc private func checkoutSelectedBranchFromSidebar() {
        guard let item = selectedSidebarNode(preferClicked: true) else { return }
        runAction {
            switch item.kind {
            case .localBranch:
                try git.checkout(branch: item.title)
                refreshAll()
            case .remoteBranch:
                try git.checkoutRemote(remote: item.title)
                refreshAll()
            case .tag:
                diffText.string = try git.tagDetails(name: item.title)
            case .sectionLocal:
                showLocalSection.toggle()
                rebuildSidebarItems(currentBranch: try git.currentBranch())
            case .sectionRemote:
                showRemoteSection.toggle()
                rebuildSidebarItems(currentBranch: try git.currentBranch())
            case .sectionTag:
                showTagSection.toggle()
                rebuildSidebarItems(currentBranch: try git.currentBranch())
            }
        }
    }

    private func selectedSidebarNode(preferClicked: Bool) -> SidebarNode? {
        let row: Int
        if preferClicked, branchTable.clickedRow >= 0 {
            row = branchTable.clickedRow
            branchTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        } else {
            row = branchTable.selectedRow
        }
        guard row >= 0 else { return nil }
        return branchTable.item(atRow: row) as? SidebarNode
    }

    private func selectedSidebarBranchItem() -> SidebarNode? {
        guard let item = selectedSidebarNode(preferClicked: true) else { return nil }
        switch item.kind {
        case .localBranch, .remoteBranch: return item
        default: return nil
        }
    }

    @objc private func sidebarCheckoutSelectedBranch() {
        guard let item = selectedSidebarBranchItem() else {
            showMessage("请选择本地或远程分支")
            return
        }
        runAction {
            switch item.kind {
            case .localBranch: try git.checkout(branch: item.title)
            case .remoteBranch: try git.checkoutRemote(remote: item.title)
            default: break
            }
            refreshAll()
        }
    }

    @objc private func sidebarMergeSelectedBranch() {
        guard let item = selectedSidebarBranchItem() else {
            showMessage("请选择本地或远程分支")
            return
        }
        let confirmed = askConfirm(title: "确认合并", message: "将 \(item.title) 合并到当前分支")
        guard confirmed else { return }
        runAction {
            try git.merge(branch: item.title)
            refreshAll()
        }
    }

    @objc private func sidebarRebaseOntoSelectedBranch() {
        guard let item = selectedSidebarBranchItem() else {
            showMessage("请选择本地或远程分支")
            return
        }
        let confirmed = askConfirm(title: "确认变基", message: "当前分支变基到 \(item.title)")
        guard confirmed else { return }
        runAction {
            try git.rebase(onto: item.title)
            refreshAll()
        }
    }

    @objc private func sidebarShowBranchLog() {
        guard let item = selectedSidebarBranchItem() else {
            showMessage("请选择本地或远程分支")
            return
        }
        runAction {
            let log = try git.branchRecentLog(branch: item.title)
            diffText.string = log.isEmpty ? "(该分支暂无提交)" : log
        }
    }

    @objc private func sidebarRenameSelectedBranch() {
        guard let item = selectedSidebarBranchItem(), item.kind == .localBranch else {
            showMessage("请选择本地分支")
            return
        }
        guard let newName = askInput(title: "重命名分支", message: "新分支名", placeholder: item.title) else { return }
        runAction {
            try git.renameBranch(old: item.title, new: newName)
            refreshAll()
        }
    }

    @objc private func sidebarDeleteSelectedBranch() {
        guard let item = selectedSidebarBranchItem(), item.kind == .localBranch else {
            showMessage("请选择本地分支")
            return
        }
        runAction {
            let current = try git.currentBranch()
            if item.title == current {
                showMessage("不能删除当前分支：\(item.title)")
                return
            }
            var riskMessage = ""
            let remoteRef = "origin/\(item.title)"
            if remoteBranches.contains(remoteRef), let aheadBehind = try? git.aheadBehind(current: item.title, against: remoteRef) {
                riskMessage = "\n\n风险提示：\(aheadBehind)"
            }
            let confirmed = askConfirm(title: "确认删除分支", message: "将强制删除本地分支 \(item.title)\(riskMessage)")
            guard confirmed else { return }
            try git.deleteBranch(name: item.title)
            refreshAll()
        }
    }

    @objc private func sidebarCreateBranchFromSelected() {
        guard let item = selectedSidebarBranchItem() else {
            showMessage("请选择本地或远程分支")
            return
        }
        guard let name = askInput(title: "从该分支新建", message: "输入新分支名", placeholder: "feature/new-branch") else { return }
        runAction {
            try git.createBranch(name: name, from: item.title)
            refreshAll()
        }
    }

    @objc private func sidebarPushSelectedBranch() {
        guard let item = selectedSidebarBranchItem(), item.kind == .localBranch else {
            showMessage("请选择本地分支")
            return
        }
        runAction {
            try git.pushBranch(name: item.title)
            refreshAll()
        }
    }

    @objc private func compareTargetChanged() {
        runAction {
            let current = try git.currentBranch()
            guard let against = compareBranchPopup.selectedItem?.title, against != "(无可比较分支)" else {
                branchRelationLabel.stringValue = ""
                return
            }
            branchRelationLabel.stringValue = try git.aheadBehind(current: current, against: against)
        }
    }

    @objc private func applyCommitFilter() {
        refreshAll()
    }

    @objc private func clearCommitFilter() {
        commitFilterInput.stringValue = ""
        refreshAll()
    }

    @objc private func checkoutBranch() {
        guard let name = branchPopup.selectedItem?.title else { return }
        runAction {
            try git.checkout(branch: name)
            refreshAll()
        }
    }

    @objc private func createBranch() {
        guard let name = askInput(title: "新建分支", message: "输入分支名", placeholder: "feature/xxx") else { return }
        runAction {
            try git.createBranch(name: name)
            refreshAll()
        }
    }

    @objc private func mergeFromSelectedBranch() {
        guard let branch = compareBranchPopup.selectedItem?.title, branch != "(无可比较分支)" else { return }
        let confirmed = askConfirm(title: "确认 Merge", message: "将分支 \(branch) merge 到当前分支")
        guard confirmed else { return }
        runAction {
            try git.merge(branch: branch)
            refreshAll()
        }
    }

    @objc private func rebaseOntoSelectedBranch() {
        guard let branch = compareBranchPopup.selectedItem?.title, branch != "(无可比较分支)" else { return }
        let confirmed = askConfirm(title: "确认 Rebase", message: "当前分支 rebase 到 \(branch)")
        guard confirmed else { return }
        runAction {
            try git.rebase(onto: branch)
            refreshAll()
        }
    }

    @objc private func fetchRepo() { runAction { try git.fetch(); refreshAll() } }
    @objc private func pullRepo() { runAction { try git.pull(); refreshAll() } }
    @objc private func pushRepo() { runAction { try git.push(); refreshAll() } }

    @objc private func stageSelected() {
        guard let file = selectedFile() else { return }
        runAction {
            try git.stage(file: file.path)
            refreshAll()
        }
    }

    @objc private func stageAll() {
        runAction {
            try git.stageAll()
            refreshAll()
        }
    }

    @objc private func unstageSelected() {
        guard let file = selectedFile() else { return }
        runAction {
            try git.unstage(file: file.path)
            refreshAll()
        }
    }

    @objc private func unstageAll() {
        runAction {
            try git.unstageAll()
            refreshAll()
        }
    }

    @objc private func discardSelected() {
        guard let file = selectedFile() else { return }
        let confirmed = askConfirm(title: "确认丢弃修改", message: "将丢弃文件改动：\n\(file.path)")
        guard confirmed else { return }
        runAction {
            try git.discard(file: file.path)
            refreshAll()
        }
    }

    @objc private func showSelectedDiff() {
        guard let file = selectedFile() else { return }
        runAction {
            selectDetailsTab("files")
            let patch = try git.diff(for: file)
            diffText.string = patch.isEmpty ? "(无差异)" : patch
        }
    }

    @objc private func showSelectedFileHistory() {
        guard let file = selectedFile() else { return }
        runAction {
            selectDetailsTab("files")
            let content = try git.fileHistory(path: file.path)
            diffText.string = content.isEmpty ? "(该文件暂无历史提交)" : content
        }
    }

    @objc private func showSelectedFileBlame() {
        guard let file = selectedFile() else { return }
        runAction {
            selectDetailsTab("files")
            let content = try git.blame(path: file.path)
            diffText.string = content.isEmpty ? "(无 blame 结果)" : content
        }
    }

    @objc private func commitChanges() {
        let msg = commitInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else {
            showMessage("提交信息不能为空")
            return
        }
        runAction {
            try git.commit(message: msg)
            commitInput.stringValue = ""
            refreshAll()
        }
    }

    @objc private func showSelectedCommitDetail() {
        guard let hash = selectedCommitHash() else {
            showMessage("请先在左侧提交列表中选中 commit")
            return
        }
        runAction {
            selectDetailsTab("detail")
            diffText.string = try git.commitDetails(hash: hash)
        }
    }

    @objc private func compareSelectedCommits() {
        let rows = commitTable.selectedRowIndexes.sorted()
        guard rows.count == 2 else {
            showMessage("请在提交列表中选择 2 条提交进行对比")
            return
        }
        let base = commits[rows[0]].hash
        let head = commits[rows[1]].hash
        runAction {
            selectDetailsTab("detail")
            compareBaseHash = base
            compareHeadHash = head
            compareFiles = try git.changedFilesBetween(base: base, head: head)
            filteredCompareFiles = compareFiles
            compareFileSearch.stringValue = ""
            compareFilesTable.reloadData()
            if !filteredCompareFiles.isEmpty {
                compareFilesTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            }
            diffText.string = try git.compareCommits(base: base, head: head)
        }
    }

    @objc private func filterCompareFiles() {
        let keyword = compareFileSearch.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if keyword.isEmpty {
            filteredCompareFiles = compareFiles
        } else {
            filteredCompareFiles = compareFiles.filter { $0.lowercased().contains(keyword) }
        }
        compareFilesTable.reloadData()
    }

    private func selectedCompareFile() -> String? {
        let row = actionRow(in: compareFilesTable)
        guard row >= 0, row < filteredCompareFiles.count else { return nil }
        return filteredCompareFiles[row]
    }

    @objc private func showSelectedCompareFileDiff() {
        guard let base = compareBaseHash, let head = compareHeadHash else {
            showMessage("请先执行一次两提交对比")
            return
        }
        guard let file = selectedCompareFile() else {
            showMessage("当前没有可查看的对比文件")
            return
        }
        runAction {
            selectDetailsTab("detail")
            let patch = try git.diffFileBetween(base: base, head: head, path: file)
            diffText.string = "File: \(file)\nRange: \(base) -> \(head)\n\n" + (patch.isEmpty ? "(no diff)" : patch)
        }
    }

    @objc private func showSelectedCompareFileDiffFromTable() {
        showSelectedCompareFileDiff()
    }

    @objc private func cherryPickSelectedCommit() {
        guard let hash = selectedCommitHash() else {
            showMessage("请先在提交列表中选中 commit")
            return
        }
        let confirmed = askConfirm(title: "确认 Cherry-pick", message: "将提交 \(hash) cherry-pick 到当前分支")
        guard confirmed else { return }
        runAction {
            try git.cherryPick(hash: hash)
            refreshAll()
        }
    }

    @objc private func revertSelectedCommit() {
        guard let hash = selectedCommitHash() else {
            showMessage("请先在提交列表中选中 commit")
            return
        }
        let confirmed = askConfirm(title: "确认 Revert", message: "将提交 \(hash) 生成反向提交")
        guard confirmed else { return }
        runAction {
            try git.revert(hash: hash)
            refreshAll()
        }
    }

    @objc private func resetSoftToSelectedCommit() { resetSelectedCommit(mode: "--soft", title: "Reset --soft") }
    @objc private func resetMixedToSelectedCommit() { resetSelectedCommit(mode: "--mixed", title: "Reset --mixed") }
    @objc private func resetHardToSelectedCommit() { resetSelectedCommit(mode: "--hard", title: "Reset --hard") }

    private func resetSelectedCommit(mode: String, title: String) {
        guard let hash = selectedCommitHash() else {
            showMessage("请先在提交列表中选中 commit")
            return
        }
        let warning = mode == "--hard" ? "（会丢弃工作区与暂存区变更）" : ""
        let confirmed = askConfirm(title: "确认 \(title)", message: "将当前分支重置到 \(hash) \(warning)")
        guard confirmed else { return }

        runAction {
            try git.reset(to: hash, mode: mode)
            refreshAll()
        }
    }

    @objc private func resolveWithOurs() {
        guard let file = selectedConflictFile() else { return }
        runAction {
            try git.resolveConflict(path: file.path, strategy: "--ours")
            refreshAll()
        }
    }

    @objc private func resolveWithTheirs() {
        guard let file = selectedConflictFile() else { return }
        runAction {
            try git.resolveConflict(path: file.path, strategy: "--theirs")
            refreshAll()
        }
    }

    @objc private func markConflictResolved() {
        guard let file = selectedConflictFile() else { return }
        runAction {
            try git.markResolved(path: file.path)
            refreshAll()
        }
    }

    @objc private func showSelectedConflictDiff() {
        guard let file = selectedConflictFile() else { return }
        runAction {
            selectDetailsTab("conflicts")
            let patch = try git.diff(path: file.path)
            diffText.string = patch.isEmpty ? "(无冲突 diff 输出)" : patch
        }
    }

    @objc private func continueCurrentOperation() {
        guard let state = currentOperation else {
            showMessage("当前没有可继续的操作")
            return
        }
        runAction {
            try git.continueOperation(state)
            refreshAll()
        }
    }

    @objc private func abortCurrentOperation() {
        guard let state = currentOperation else {
            showMessage("当前没有可中止的操作")
            return
        }
        let confirmed = askConfirm(title: "确认 Abort", message: "将中止：\(state.name)")
        guard confirmed else { return }
        runAction {
            try git.abortOperation(state)
            refreshAll()
        }
    }

    @objc private func saveStash() {
        let message = askInput(title: "保存 Stash", message: "输入 stash 描述（可空）", placeholder: "WIP: fix bug")
        runAction {
            try git.stashPush(message: message)
            refreshAll()
        }
    }

    @objc private func applyStash() {
        guard let ref = selectedStashRef() else { return }
        runAction {
            try git.stashApply(ref: ref)
            refreshAll()
        }
    }

    @objc private func popStash() {
        guard let ref = selectedStashRef() else { return }
        runAction {
            try git.stashPop(ref: ref)
            refreshAll()
        }
    }

    @objc private func dropStash() {
        guard let ref = selectedStashRef() else { return }
        let confirmed = askConfirm(title: "确认删除 Stash", message: "将删除 \(ref)")
        guard confirmed else { return }
        runAction {
            try git.stashDrop(ref: ref)
            refreshAll()
        }
    }

    @objc private func createTag() {
        guard let name = askInput(title: "新建 Tag", message: "输入 Tag 名", placeholder: "v1.0.0") else { return }
        let target = selectedCommitHash() ?? "HEAD"
        runAction {
            try git.createTag(name: name, target: target)
            refreshAll()
        }
    }

    @objc private func createTagAtSelectedCommit() {
        guard let hash = selectedCommitHash() else {
            showMessage("请先在提交列表中选中 commit")
            return
        }
        guard let name = askInput(title: "新建 Tag", message: "输入 Tag 名", placeholder: "v1.0.0") else { return }
        runAction {
            try git.createTag(name: name, target: hash)
            refreshAll()
        }
    }

    @objc private func deleteTag() {
        guard let tag = selectedTag(), tag != "(无 tag)" else { return }
        let confirmed = askConfirm(title: "确认删除 Tag", message: "将删除 tag \(tag)")
        guard confirmed else { return }
        runAction {
            try git.deleteTag(name: tag)
            refreshAll()
        }
    }

    private func selectedStashRef() -> String? {
        guard let raw = stashPopup.selectedItem?.title, raw != "(无 stash)" else { return nil }
        if let idx = raw.firstIndex(of: ":") {
            return String(raw[..<idx])
        }
        return raw
    }

    private func selectedTag() -> String? {
        tagPopup.selectedItem?.title
    }

    private func selectedFile() -> GitFileStatus? {
        let row = actionRow(in: statusTable)
        guard row >= 0, row < files.count else { return nil }
        return files[row]
    }

    private func selectedConflictFile() -> GitFileStatus? {
        let row = actionRow(in: conflictTable)
        guard row >= 0, row < conflicts.count else { return nil }
        return conflicts[row]
    }

    private func selectedCommitHash() -> String? {
        let row = actionRow(in: commitTable)
        guard row >= 0, row < commits.count else { return nil }
        return commits[row].hash
    }

    private func actionRow(in table: NSTableView) -> Int {
        let clicked = table.clickedRow
        if clicked >= 0 {
            table.selectRowIndexes(IndexSet(integer: clicked), byExtendingSelection: false)
            return clicked
        }
        if table.selectedRow >= 0 {
            return table.selectedRow
        }
        return table.selectedRowIndexes.first ?? -1
    }

    private func currentCommitFilter() -> String {
        commitFilterInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func highlightedSubject(_ text: String, query: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text)
        guard !query.isEmpty else { return attributed }

        let nsText = text as NSString
        let range = nsText.range(of: query, options: [.caseInsensitive])
        if range.location != NSNotFound {
            attributed.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.35), range: range)
            attributed.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
        }
        return attributed
    }

    private func sidebarDisplayText(for item: SidebarNode) -> String {
        switch item.kind {
        case .sectionLocal, .sectionRemote, .sectionTag:
            let expanded = (item.kind == .sectionLocal && showLocalSection)
                || (item.kind == .sectionRemote && showRemoteSection)
                || (item.kind == .sectionTag && showTagSection)
            let prefix = expanded ? "▾" : "▸"
            return "\(prefix)  \(item.title)"
        case .localBranch:
            return "  \(item.title)"
        case .remoteBranch:
            return "  \(item.title)"
        case .tag:
            return "  #\(item.title)"
        }
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let node = item as? SidebarNode {
            return node.children.count
        }
        return sidebarRoots.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? SidebarNode {
            return node.children[index]
        }
        return sidebarRoots[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? SidebarNode else { return false }
        switch node.kind {
        case .sectionLocal, .sectionRemote, .sectionTag:
            return true
        default:
            return false
        }
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? SidebarNode else { return nil }
        let text = sidebarDisplayText(for: node)
        let cell = NSTextField(labelWithString: text)
        switch node.kind {
        case .sectionLocal, .sectionRemote, .sectionTag:
            cell.font = .systemFont(ofSize: 11, weight: .semibold)
            cell.textColor = .secondaryLabelColor
        case .localBranch:
            cell.font = .systemFont(ofSize: 12, weight: node.title == branchPopup.selectedItem?.title ? .semibold : .regular)
            cell.textColor = .labelColor
        case .remoteBranch:
            cell.font = .systemFont(ofSize: 12)
            cell.textColor = .secondaryLabelColor
        case .tag:
            cell.font = .systemFont(ofSize: 12)
            cell.textColor = .secondaryLabelColor
        }
        return cell
    }

    private func selectDetailsTab(_ id: String) {
        if let item = detailsTabView.tabViewItems.first(where: { ($0.identifier as? String) == id }) {
            detailsTabView.selectTabViewItem(item)
        }
    }

    private func configureContextMenus() {
        let commitMenu = NSMenu(title: "提交操作")
        commitMenu.addItem(withTitle: "提交详情", action: #selector(showSelectedCommitDetail), keyEquivalent: "")
        commitMenu.addItem(withTitle: "对比选中两提交", action: #selector(compareSelectedCommits), keyEquivalent: "")
        commitMenu.addItem(withTitle: "Cherry-pick", action: #selector(cherryPickSelectedCommit), keyEquivalent: "")
        commitMenu.addItem(withTitle: "Revert", action: #selector(revertSelectedCommit), keyEquivalent: "")
        commitMenu.addItem(NSMenuItem.separator())
        commitMenu.addItem(withTitle: "Reset --soft", action: #selector(resetSoftToSelectedCommit), keyEquivalent: "")
        commitMenu.addItem(withTitle: "Reset --mixed", action: #selector(resetMixedToSelectedCommit), keyEquivalent: "")
        commitMenu.addItem(withTitle: "Reset --hard", action: #selector(resetHardToSelectedCommit), keyEquivalent: "")
        commitMenu.addItem(NSMenuItem.separator())
        commitMenu.addItem(withTitle: "新建 Tag 到此提交", action: #selector(createTagAtSelectedCommit), keyEquivalent: "")
        for item in commitMenu.items { item.target = self }
        commitTable.menu = commitMenu

        let fileMenu = NSMenu(title: "文件操作")
        fileMenu.addItem(withTitle: "查看 Diff", action: #selector(showSelectedDiff), keyEquivalent: "")
        fileMenu.addItem(withTitle: "Stage", action: #selector(stageSelected), keyEquivalent: "")
        fileMenu.addItem(withTitle: "Unstage", action: #selector(unstageSelected), keyEquivalent: "")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "History", action: #selector(showSelectedFileHistory), keyEquivalent: "")
        fileMenu.addItem(withTitle: "Blame", action: #selector(showSelectedFileBlame), keyEquivalent: "")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Discard", action: #selector(discardSelected), keyEquivalent: "")
        for item in fileMenu.items { item.target = self }
        statusTable.menu = fileMenu

        let conflictMenu = NSMenu(title: "冲突操作")
        conflictMenu.addItem(withTitle: "查看冲突", action: #selector(showSelectedConflictDiff), keyEquivalent: "")
        conflictMenu.addItem(withTitle: "用 Ours", action: #selector(resolveWithOurs), keyEquivalent: "")
        conflictMenu.addItem(withTitle: "用 Theirs", action: #selector(resolveWithTheirs), keyEquivalent: "")
        conflictMenu.addItem(withTitle: "标记已解决", action: #selector(markConflictResolved), keyEquivalent: "")
        for item in conflictMenu.items { item.target = self }
        conflictTable.menu = conflictMenu

        let branchMenu = NSMenu(title: "分支操作")
        let checkoutItem = branchMenu.addItem(withTitle: "切换到该分支", action: #selector(sidebarCheckoutSelectedBranch), keyEquivalent: "")
        let mergeItem = branchMenu.addItem(withTitle: "合并到当前分支", action: #selector(sidebarMergeSelectedBranch), keyEquivalent: "")
        let rebaseItem = branchMenu.addItem(withTitle: "当前分支变基到该分支", action: #selector(sidebarRebaseOntoSelectedBranch), keyEquivalent: "")
        branchMenu.addItem(NSMenuItem.separator())
        let createFromItem = branchMenu.addItem(withTitle: "从该分支新建分支", action: #selector(sidebarCreateBranchFromSelected), keyEquivalent: "")
        let renameItem = branchMenu.addItem(withTitle: "重命名本地分支", action: #selector(sidebarRenameSelectedBranch), keyEquivalent: "")
        let deleteItem = branchMenu.addItem(withTitle: "删除本地分支", action: #selector(sidebarDeleteSelectedBranch), keyEquivalent: "")
        let pushItem = branchMenu.addItem(withTitle: "推送本地分支", action: #selector(sidebarPushSelectedBranch), keyEquivalent: "")
        branchMenu.addItem(NSMenuItem.separator())
        let logItem = branchMenu.addItem(withTitle: "查看最近提交", action: #selector(sidebarShowBranchLog), keyEquivalent: "")
        for item in branchMenu.items { item.target = self }
        branchMenu.delegate = self
        branchContextMenu = branchMenu
        branchMenuRenameItem = renameItem
        branchMenuDeleteItem = deleteItem
        branchMenuPushItem = pushItem
        checkoutItem.isEnabled = false
        mergeItem.isEnabled = false
        rebaseItem.isEnabled = false
        createFromItem.isEnabled = false
        logItem.isEnabled = false
        branchTable.menu = branchMenu
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu == branchContextMenu else { return }
        guard let node = selectedSidebarNode(preferClicked: true) else {
            for item in menu.items where item.action != nil { item.isEnabled = false }
            return
        }

        let isBranch = node.kind == .localBranch || node.kind == .remoteBranch
        let isLocal = node.kind == .localBranch
        let isCurrentLocal = isLocal && node.title == branchPopup.selectedItem?.title

        for item in menu.items {
            switch item.action {
            case #selector(sidebarCheckoutSelectedBranch),
                 #selector(sidebarMergeSelectedBranch),
                 #selector(sidebarRebaseOntoSelectedBranch),
                 #selector(sidebarCreateBranchFromSelected),
                 #selector(sidebarShowBranchLog):
                item.isEnabled = isBranch
            case #selector(sidebarRenameSelectedBranch),
                 #selector(sidebarDeleteSelectedBranch),
                 #selector(sidebarPushSelectedBranch):
                item.isEnabled = isLocal
            default:
                break
            }
        }
        branchMenuDeleteItem?.isEnabled = isLocal && !isCurrentLocal
    }

    private func rebuildSidebarItems(currentBranch: String?) {
        let localNode = SidebarNode(kind: .sectionLocal, title: "本地", children: localBranches.map { SidebarNode(kind: .localBranch, title: $0) })
        let remoteNode = SidebarNode(kind: .sectionRemote, title: "远程", children: remoteBranches.map { SidebarNode(kind: .remoteBranch, title: $0) })
        let tagNode = SidebarNode(kind: .sectionTag, title: "Tag", children: sidebarTags.map { SidebarNode(kind: .tag, title: $0) })
        sidebarRoots = [localNode, remoteNode, tagNode]
        branchTable.reloadData()

        if showLocalSection { branchTable.expandItem(localNode) } else { branchTable.collapseItem(localNode) }
        if showRemoteSection { branchTable.expandItem(remoteNode) } else { branchTable.collapseItem(remoteNode) }
        if showTagSection { branchTable.expandItem(tagNode) } else { branchTable.collapseItem(tagNode) }

        if let currentBranch {
            for row in 0..<branchTable.numberOfRows {
                if let node = branchTable.item(atRow: row) as? SidebarNode,
                   node.kind == .localBranch,
                   node.title == currentBranch {
                    branchTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                    break
                }
            }
        }
    }

    private func runAction(_ block: () throws -> Void) {
        let isRootAction = actionDepth == 0
        if isRootAction {
            setUIBusy(true, message: "执行中...")
        }

        actionDepth += 1
        var hasError = false
        do {
            try block()
        } catch {
            hasError = true
            showError(error)
        }
        actionDepth -= 1

        if isRootAction {
            setUIBusy(false, message: hasError ? nil : "操作完成 \(timeText())")
        }
    }

    private func setUIBusy(_ busy: Bool, message: String?) {
        for control in interactiveControls {
            control.isEnabled = !busy
        }
        if let message {
            statusHintLabel.stringValue = message
            statusHintLabel.textColor = busy ? .systemBlue : .secondaryLabelColor
        }
        if busy {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func timeText() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: Date())
    }

    private func askInput(title: String, message: String, placeholder: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        let input = NSTextField(string: "")
        input.placeholderString = placeholder
        alert.accessoryView = input
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            let text = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
        return nil
    }

    private func askConfirm(title: String, message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "继续")
        alert.addButton(withTitle: "取消")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func showMessage(_ text: String) {
        let alert = NSAlert()
        alert.messageText = text
        alert.runModal()
        statusHintLabel.stringValue = text
        statusHintLabel.textColor = .systemOrange
    }

    private func showError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
        statusHintLabel.stringValue = "错误: \(error.localizedDescription)"
        statusHintLabel.textColor = .systemRed
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == statusTable { return files.count }
        if tableView == commitTable { return commits.count }
        if tableView == conflictTable { return conflicts.count }
        if tableView == compareFilesTable { return filteredCompareFiles.count }
        return 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == statusTable {
            let item = files[row]
            let id = tableColumn?.identifier.rawValue ?? ""
            let text: String = id == "status" ? item.badge : item.path
            return makeStatusCell(text: text, id: id, item: item)
        }

        if tableView == commitTable {
            let item = commits[row]
            let id = tableColumn?.identifier.rawValue ?? ""
            if id == "commit_graph" {
                let graphView = CommitGraphView(frame: NSRect(x: 0, y: 0, width: tableColumn?.width ?? 94, height: commitTable.rowHeight))
                graphView.graphText = item.graph.replacingOccurrences(of: "\u{1e}", with: "")
                return graphView
            }
            let text: String
            switch id {
            case "commit_date": text = item.date
            case "commit_author": text = item.author
            default:
                text = item.refs.isEmpty ? item.subject : "\(item.subject)  \(item.refs)"
            }
            let cell: NSTextField
            if id == "commit_subject" {
                cell = NSTextField(labelWithAttributedString: highlightedSubject(text, query: currentCommitFilter()))
            } else {
                cell = NSTextField(labelWithString: text)
            }
            cell.lineBreakMode = .byTruncatingTail
            cell.font = .systemFont(ofSize: 12)
            cell.textColor = .labelColor
            return cell
        }

        if tableView == conflictTable {
            let item = conflicts[row]
            let id = tableColumn?.identifier.rawValue ?? ""
            let text = id == "conflict_status" ? item.badge : item.path
            let cell = NSTextField(labelWithString: text)
            cell.lineBreakMode = .byTruncatingMiddle
            cell.font = id == "conflict_status" ? .monospacedSystemFont(ofSize: 11, weight: .semibold) : .monospacedSystemFont(ofSize: 12, weight: .regular)
            cell.textColor = id == "conflict_status" ? .systemRed : .labelColor
            return cell
        }

        if tableView == compareFilesTable {
            let file = filteredCompareFiles[row]
            let cell = NSTextField(labelWithString: file)
            cell.lineBreakMode = .byTruncatingMiddle
            cell.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            return cell
        }

        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }
        if table == branchTable {
            guard let item = selectedSidebarNode(preferClicked: false) else { return }
            switch item.kind {
            case .sectionLocal:
                showLocalSection.toggle()
                rebuildSidebarItems(currentBranch: branchPopup.selectedItem?.title)
            case .sectionRemote:
                showRemoteSection.toggle()
                rebuildSidebarItems(currentBranch: branchPopup.selectedItem?.title)
            case .sectionTag:
                showTagSection.toggle()
                rebuildSidebarItems(currentBranch: branchPopup.selectedItem?.title)
            case .tag:
                runAction { diffText.string = try git.tagDetails(name: item.title) }
            case .localBranch:
                branchPopup.selectItem(withTitle: item.title)
                runAction {
                    let log = try git.branchRecentLog(branch: item.title)
                    diffText.string = log.isEmpty ? "(该分支暂无提交)" : log
                }
            case .remoteBranch:
                runAction {
                    let log = try git.branchRecentLog(branch: item.title)
                    diffText.string = log.isEmpty ? "(该远程分支暂无提交)" : log
                }
            }
        }
        if table == commitTable, let hash = selectedCommitHash() {
            runAction {
                selectDetailsTab("detail")
                diffText.string = try git.commitDetails(hash: hash)
            }
        }
    }

    private func makeStatusCell(text: String, id: String, item: GitFileStatus) -> NSView {
        let cell = NSTextField(labelWithString: text)
        cell.lineBreakMode = .byTruncatingMiddle
        if id == "status" {
            cell.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
            if item.isConflicted { cell.textColor = .systemRed }
            else if item.isUntracked { cell.textColor = .systemOrange }
            else if item.isStaged { cell.textColor = .systemGreen }
            else { cell.textColor = .systemBlue }
        } else {
            cell.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        }
        return cell
    }

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if splitView == mainSplitView, dividerIndex == 0 {
            return 260
        }
        if splitView == mainSplitView, dividerIndex == 1 {
            return 900
        }
        return proposedMinimumPosition
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if splitView == mainSplitView, dividerIndex == 0 {
            return max(360, splitView.bounds.width - 760)
        }
        if splitView == mainSplitView, dividerIndex == 1 {
            return splitView.bounds.width - 320
        }
        return proposedMaximumPosition
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
