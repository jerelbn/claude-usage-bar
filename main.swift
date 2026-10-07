import Cocoa

struct Limit { let label: String; let percent: Double; let resets: Date? }

// MARK: - Data

struct E: LocalizedError { let errorDescription: String? }

// Reads the Claude Code login directly via the Security framework, so the Keychain
// access list names this app rather than the generic `security` command-line tool.
// With `interactive` false, a read that would need a Keychain prompt fails instead of showing one,
// so background refreshes never pop up a dialog or pull focus.
func readToken(interactive: Bool) -> Result<String, E> {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "Claude Code-credentials",
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var out: CFTypeRef?
    SecKeychainSetUserInteractionAllowed(interactive)
    let status = SecItemCopyMatching(query as CFDictionary, &out)
    SecKeychainSetUserInteractionAllowed(true)
    switch status {
    case errSecSuccess: break
    case errSecItemNotFound: return .failure(E(errorDescription: "No Claude Code login found. Run `claude` and sign in."))
    case errSecInteractionNotAllowed, errSecAuthFailed, errSecUserCanceled:
        return .failure(E(errorDescription: "Keychain access needed. Click Refresh to allow it."))
    default: return .failure(E(errorDescription: "Keychain error \(status). Click Refresh to retry."))
    }
    guard let data = out as? Data,
          let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let c = o["claudeAiOauth"] as? [String: Any],
          let token = c["accessToken"] as? String else {   // the refresh token in the same item is never used
        return .failure(E(errorDescription: "Couldn't read the Claude Code login. Run `claude` and sign in."))
    }
    // Only Claude Code renews the token, so after a long idle stretch it may simply be stale.
    if let ms = c["expiresAt"] as? Double, Date(timeIntervalSince1970: ms / 1000) < Date() {
        return .failure(E(errorDescription: "Login expired. Open Claude Code to refresh it."))
    }
    return .success(token)
}

// Never follow redirects, so the bearer token can only ever go to the URL we asked for.
final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ s: URLSession, task: URLSessionTask, willPerformHTTPRedirection r: HTTPURLResponse,
                    newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
let session = URLSession(configuration: .ephemeral, delegate: NoRedirect(), delegateQueue: nil)

func parseDate(_ s: String?) -> Date? {
    guard let s = s else { return nil }
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
}

func fetchUsage(interactive: Bool, _ done: @escaping (Result<[Limit], Error>) -> Void) {
    let token: String
    switch readToken(interactive: interactive) {
    case .success(let t): token = t
    case .failure(let e): return done(.failure(e))
    }
    var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!, timeoutInterval: 15)
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
    session.dataTask(with: req) { data, resp, err in
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
        load(interactive: true)   // first launch: let the Keychain prompt appear
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in self?.load(interactive: false) }
        // After sleep the network takes a moment to come back, so wait briefly before refreshing.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { self?.load(interactive: false) }
        }
    }

    // Only a user-initiated refresh may show the Keychain prompt and bring the app forward.
    @objc func refresh() { load(interactive: true) }

    func load(interactive: Bool) {
        // An accessory app is never frontmost, so the Keychain prompt can open behind other windows.
        if interactive { NSApp.activate(ignoringOtherApps: true) }
        fetchUsage(interactive: interactive) { r in DispatchQueue.main.async { self.render(r) } }
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
