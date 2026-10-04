import Cocoa

struct Limit { let label: String; let percent: Double; let resets: Date? }

// MARK: - Data

func readToken() -> String? {
    let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    p.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
    let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
    guard (try? p.run()) != nil else { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
    guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let c = o["claudeAiOauth"] as? [String: Any] else { return nil }
    return c["accessToken"] as? String
}

func parseDate(_ s: String?) -> Date? {
    guard let s = s else { return nil }
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
}

func fetchUsage(_ done: @escaping (Result<[Limit], Error>) -> Void) {
    struct E: LocalizedError { let errorDescription: String? }
    guard let token = readToken() else { return done(.failure(E(errorDescription: "No Claude Code login found. Run `claude` and sign in."))) }
    var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!, timeoutInterval: 15)
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
    URLSession.shared.dataTask(with: req) { data, resp, err in
        if let err = err { return done(.failure(err)) }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200, let data = data, let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return done(.failure(E(errorDescription: code == 401 ? "Login expired. Open Claude Code to refresh it." : "Usage request failed (HTTP \(code))")))
        }
        func limit(_ key: String, _ label: String) -> Limit? {
            guard let d = o[key] as? [String: Any], let u = d["utilization"] as? Double else { return nil }
            return Limit(label: label, percent: u, resets: parseDate(d["resets_at"] as? String))
        }
        done(.success([limit("five_hour", "Current session"), limit("seven_day", "This week"),
                       limit("seven_day_opus", "Opus (week)"), limit("seven_day_sonnet", "Sonnet (week)")].compactMap { $0 }))
    }.resume()
}

// MARK: - UI

func color(_ pct: Double) -> NSColor { .systemBlue }

func resetText(_ d: Date?) -> String {
    guard let d = d else { return "" }
    let f = DateFormatter()
    f.dateFormat = d.timeIntervalSinceNow < 20 * 3600 ? "h:mm a" : "EEEE h:mm a"
    return "Resets " + f.string(from: d)
}

final class BarView: NSView {
    let limit: Limit
    init(_ l: Limit) { limit = l; super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 52)) }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ r: NSRect) {
        let small: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
        let main: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor]
        let pct = "\(Int(limit.percent.rounded()))% used" as NSString
        (limit.label as NSString).draw(at: NSPoint(x: 14, y: 32), withAttributes: main)
        let w = pct.size(withAttributes: small).width
        pct.draw(at: NSPoint(x: 266 - w, y: 33), withAttributes: small)
        let track = NSRect(x: 14, y: 22, width: 252, height: 6)
        NSColor.quaternaryLabelColor.setFill(); NSBezierPath(roundedRect: track, xRadius: 3, yRadius: 3).fill()
        var fill = track; fill.size.width = max(6, track.width * CGFloat(min(limit.percent, 100) / 100))
        color(limit.percent).setFill(); NSBezierPath(roundedRect: fill, xRadius: 3, yRadius: 3).fill()
        (resetText(limit.resets) as NSString).draw(at: NSPoint(x: 14, y: 5), withAttributes: small)
    }
}

func iconImage(_ session: Double, _ week: Double) -> NSImage {
    let w: CGFloat = 36, h: CGFloat = 4
    let img = NSImage(size: NSSize(width: w, height: 12), flipped: false) { _ in
        for (i, p) in [session, week].enumerated() {   // session on top, week below
            let track = NSRect(x: 0, y: CGFloat(7 - i * 7) + 0.5, width: w, height: h)
            let shape = NSBezierPath(roundedRect: track, xRadius: h / 2, yRadius: h / 2)
            NSColor.white.withAlphaComponent(0.25).setFill(); shape.fill()
            NSGraphicsContext.saveGraphicsState(); shape.addClip()   // exact-width fill, clipped to the rounded track
            var f = track; f.size.width = max(1.5, w * CGFloat(min(p, 100) / 100))
            NSColor.systemBlue.setFill(); NSBezierPath(rect: f).fill()
            NSGraphicsContext.restoreGraphicsState()
        }
        return true
    }
    img.isTemplate = false
    return img
}

class App: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var timer: Timer?

    func applicationDidFinishLaunching(_ n: Notification) {
        item.button?.title = "Claude …"
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in self?.refresh() }
    }

    @objc func refresh() {
        fetchUsage { r in DispatchQueue.main.async { self.render(r) } }
    }

    func render(_ r: Result<[Limit], Error>) {
        let m = NSMenu()
        switch r {
        case .success(let limits):
            let s = limits.first { $0.label == "Current session" }?.percent ?? 0
            let w = limits.first { $0.label == "This week" }?.percent ?? 0
            item.button?.image = iconImage(s, w)
            item.button?.imagePosition = .imageOnly
            item.button?.title = ""
            for l in limits {
                let mi = NSMenuItem(); mi.view = BarView(l); m.addItem(mi)
            }
        case .failure(let e):
            item.button?.image = nil
            item.button?.imagePosition = .noImage
            item.button?.title = "⚠︎"
            m.addItem(withTitle: e.localizedDescription, action: nil, keyEquivalent: "")
        }
        m.addItem(.separator())
        m.addItem(withTitle: "Refresh", action: #selector(refresh), keyEquivalent: "r").target = self
        m.addItem(withTitle: "Open usage page", action: #selector(openPage), keyEquivalent: "").target = self
        m.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = m
    }
    @objc func openPage() { NSWorkspace.shared.open(URL(string: "https://claude.ai/settings/usage")!) }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
