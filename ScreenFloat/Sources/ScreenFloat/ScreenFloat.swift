import Cocoa
import HotKey

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var hotKey: HotKey?
    var floatWindows: [FloatWindow] = []
    var lastCaptureScreen: NSScreen?
    var lastCaptureFrame: NSRect?
    var captureWindow: ScreenshotCaptureWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        print("ScreenFloat 已启动")
        // 设置状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "SF"
            button.font = NSFont.boldSystemFont(ofSize: 12)
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "截图 (Cmd+Shift+6)", action: #selector(startScreenshot), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "关闭全部", action: #selector(closeAll), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        
        // 注册全局快捷键 Cmd+Shift+6
        hotKey = HotKey(key: .six, modifiers: [.command, .shift])
        hotKey?.keyDownHandler = { [weak self] in
            self?.startScreenshot()
        }
        
        // 请求屏幕录制权限
        checkScreenRecordingPermission()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
    
    func checkScreenRecordingPermission() {
        // 触发权限请求
        let _ = CGDisplayBounds(CGMainDisplayID())
    }
    
    @objc func startScreenshot() {
        resetCaptureWindow()
        
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        guard let screen = targetScreen else { return }
        lastCaptureScreen = screen
        
        captureWindow = ScreenshotCaptureWindow(screen: screen)
        captureWindow?.onCapture = { [weak self] image in
            self?.resetCaptureWindow()
            DispatchQueue.main.async {
                self?.createFloatWindow(with: image, frame: self?.lastCaptureFrame)
            }
        }
        captureWindow?.onCancel = { [weak self] in
            self?.resetCaptureWindow()
        }
        captureWindow?.makeKeyAndOrderFront(nil)
        captureWindow?.orderFrontRegardless()
    }
    
    func resetCaptureWindow() {
        captureWindow?.orderOut(nil)
        captureWindow?.close()
        captureWindow = nil
    }
    
    func createFloatWindow(with image: NSImage, frame: NSRect?) {
        print("创建悬浮窗口")
        // 使用截图位置作为悬浮窗口位置
        let origin = frame?.origin
        let floatWindow = FloatWindow(image: image, screen: lastCaptureScreen, origin: origin)
        floatWindow.onClose = { [weak self, weak floatWindow] in
            guard let self, let floatWindow else { return }
            self.floatWindows.removeAll { $0 === floatWindow }
        }
        floatWindows.append(floatWindow)
        floatWindow.show()
        print("悬浮窗口已显示")
    }
    
    @objc func closeAll() {
        floatWindows.forEach { $0.close() }
        floatWindows.removeAll()
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - 截图选区窗口
class ScreenshotCaptureWindow: NSWindow {
    var onCapture: ((NSImage) -> Void)?
    var onCancel: (() -> Void)?
    var selectionView: SelectionView!
    var targetScreen: NSScreen
    
    init(screen: NSScreen) {
        self.targetScreen = screen
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.level = .screenSaver
        self.isReleasedWhenClosed = false
        self.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        
        selectionView = SelectionView(frame: self.contentView?.bounds ?? self.frame)
        selectionView.onComplete = { [weak self] rect in
            self?.captureScreen(rect: rect)
        }
        selectionView.onCancel = { [weak self] in
            self?.orderOut(nil)
            self?.close()
            self?.onCancel?()
        }
        self.contentView = selectionView
    }
    
    func captureScreen(rect: CGRect) {
        print("开始截图: \(rect)")
        // 将视图坐标转换为窗口坐标，再转换为屏幕坐标
        let windowRect = selectionView.convert(rect, to: nil)
        let screenRect = convertToScreen(windowRect)
        let captureRect = screenRect.integral
        if captureRect.isNull || captureRect.isEmpty {
            print("截图区域无效")
            onCancel?()
            close()
            return
        }
        print("屏幕坐标: \(captureRect), 屏幕: \(targetScreen.frame)")
        
        // 计算相对于当前屏幕的坐标 (CG坐标系，原点在左下角)
        let screenFrame = targetScreen.frame
        // Cocoa坐标转CG坐标: Y需要翻转
        let relativeX = captureRect.origin.x - screenFrame.origin.x
        let relativeY = screenFrame.height - (captureRect.origin.y - screenFrame.origin.y) - captureRect.height
        let relativeRect = CGRect(
            x: relativeX,
            y: relativeY,
            width: captureRect.width,
            height: captureRect.height
        )
        print("相对于屏幕的坐标(CG): \(relativeRect)")
        
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.lastCaptureFrame = screenRect
            appDelegate.lastCaptureScreen = targetScreen
        }
        
        let onCapture = self.onCapture
        let onCancel = self.onCancel
        let targetScreenID = targetScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()
        
        orderOut(nil)
        close()
        
        DispatchQueue.global(qos: .userInitiated).async { [rect, relativeRect, targetScreenID] in
            // 使用 CGDisplayCreateImage 截取指定屏幕
            guard let imageRef = CGDisplayCreateImage(targetScreenID, rect: relativeRect) else {
                print("截图失败")
                DispatchQueue.main.async {
                    onCancel?()
                }
                return
            }
            
            let rep = NSBitmapImageRep(cgImage: imageRef)
            DispatchQueue.main.async {
                let image = NSImage()
                image.addRepresentation(rep)
                image.size = NSSize(width: rect.width, height: rect.height)
                print("截图成功")
                onCapture?(image)
            }
        }
    }
}

// MARK: - 选区视图
class SelectionView: NSView {
    var onComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    var startPoint: NSPoint?
    var currentRect: NSRect?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        
        let rect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        currentRect = rect
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let rect = currentRect else {
            print("没有选区")
            onCancel?()
            return
        }
        print("选区: \(rect)")
        guard rect.width > 5, rect.height > 5 else {
            print("选区太小")
            onCancel?()
            return
        }
        onComplete?(rect)
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onCancel?()
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // 绘制半透明遮罩
        NSColor.black.withAlphaComponent(0.5).setFill()
        dirtyRect.fill()
        
        // 挖空选区
        if let rect = currentRect {
            let path = NSBezierPath(rect: dirtyRect)
            path.append(NSBezierPath(rect: rect))
            path.windingRule = .evenOdd
            path.addClip()
            
            NSColor.black.withAlphaComponent(0.5).setFill()
            dirtyRect.fill()
            
            // 绘制边框
            NSColor.white.setStroke()
            let borderPath = NSBezierPath(rect: rect)
            borderPath.lineWidth = 2
            borderPath.stroke()
        }
    }
}

// MARK: - 悬浮窗口
class FloatWindow: NSWindow {
    var imageView: NSImageView!
    var closeButton: NSButton!
    var scale: CGFloat = 1.0
    var onClose: (() -> Void)?
    
    class FloatContentView: NSView {
        weak var closeButton: NSButton?
        override func hitTest(_ point: NSPoint) -> NSView? {
            if let btn = closeButton, btn.frame.contains(point) {
                return super.hitTest(point)
            }
            return self
        }
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach { removeTrackingArea($0) }
            let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
            addTrackingArea(area)
        }
        var initialMouseLocation: NSPoint?
        var initialWindowOrigin: NSPoint?
        
        override func mouseDown(with event: NSEvent) {
            initialMouseLocation = NSEvent.mouseLocation
            initialWindowOrigin = window?.frame.origin
        }
        
        override func mouseDragged(with event: NSEvent) {
            guard let startMouse = initialMouseLocation,
                  let startWindow = initialWindowOrigin,
                  let window = self.window else { return }
            
            let currentMouse = NSEvent.mouseLocation
            let dx = currentMouse.x - startMouse.x
            let dy = currentMouse.y - startMouse.y
            
            var newOrigin = startWindow
            newOrigin.x += dx
            newOrigin.y += dy
            
            window.setFrameOrigin(newOrigin)
        }
        override func mouseEntered(with event: NSEvent) {
            closeButton?.isHidden = false
        }
        override func mouseExited(with event: NSEvent) {
            closeButton?.isHidden = true
        }
    }
    
    init(image: NSImage, screen: NSScreen?, origin: NSPoint? = nil) {
        let targetScreen = screen ?? NSScreen.main
        let visibleFrame = targetScreen?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let maxWidth = visibleFrame.width * 0.9
        let maxHeight = visibleFrame.height * 0.9
        let scale = min(maxWidth / image.size.width, maxHeight / image.size.height, 1.0)
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        
        // 如果没有指定位置，默认显示在屏幕中心
        let windowOrigin = origin ?? NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2
        )
        
        super.init(
            contentRect: NSRect(origin: windowOrigin, size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.isReleasedWhenClosed = false
        self.isMovableByWindowBackground = true
        
        imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: size.width, height: size.height))
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 8
        imageView.layer?.masksToBounds = true
        imageView.layer?.borderWidth = 2
        imageView.layer?.borderColor = NSColor.white.cgColor
        imageView.layer?.shadowColor = NSColor.black.cgColor
        imageView.layer?.shadowOffset = CGSize(width: 0, height: 2)
        imageView.layer?.shadowRadius = 4
        imageView.layer?.shadowOpacity = 0.3
        
        closeButton = NSButton(frame: NSRect(x: 4, y: size.height - 24, width: 20, height: 20))
        closeButton.title = "×"
        closeButton.bezelStyle = .circular
        closeButton.target = self
        closeButton.action = #selector(closeWindow)
        closeButton.wantsLayer = true
        closeButton.layer?.cornerRadius = 10
        closeButton.layer?.backgroundColor = NSColor.systemRed.cgColor
        closeButton.isHidden = true
        
        let contentView = FloatContentView(frame: NSRect(x: 0, y: 0, width: size.width, height: size.height))
        contentView.closeButton = closeButton
        contentView.addSubview(imageView)
        contentView.addSubview(closeButton)
        self.contentView = contentView
    }
    
    func show() {
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    @objc func closeWindow() {
        close()
    }
    
    override func close() {
        onClose?()
        super.close()
    }
}

// MARK: - 程序入口
@main
struct ScreenFloatApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
