import Foundation

// Focus categories, ported from scattrd
enum AppCategory: Int, CaseIterable {
    case deepWork = 0       // editors, IDEs, design tools, terminals — where real work happens
    case communication = 1  // Slack, Mail, Zoom — necessary but fragmenting
    case distraction = 2    // Twitter/X, Reddit, YouTube — pure attention drains
    case neutral = 3        // unknown apps and sites

    var label: String {
        switch self {
        case .deepWork: return "Deep work"
        case .communication: return "Communication"
        case .distraction: return "Distraction"
        case .neutral: return "Neutral"
        }
    }
}

// Maps an app or web domain to a category. Ported from scattrd's AppCatalog.
enum AppCatalog {

    static func category(bundleID: String?, name: String) -> AppCategory {
        let b = (bundleID ?? "").lowercased()
        let n = name.lowercased()
        func has(_ needles: [String]) -> Bool {
            needles.contains { b.contains($0) || n.contains($0) }
        }

        // Order matters: deep-work check runs first so "Xcode" never trips an "x" rule
        if has(["vscode", "visual studio code", "xcode", "jetbrains", "pycharm",
                "intellij", "webstorm", "goland", "clion", "rubymine",
                "sublime", "cursor", "zed", "nova", "neovim", "vim", "emacs",
                "iterm", "terminal", "warp", "alacritty", "kitty", "ghostty",
                "figma", "sketch", "framer", "obsidian", "logseq",
                "photoshop", "illustrator", "indesign", "affinity",
                "logic", "ableton", "final cut", "davinci", "premiere",
                "blender", "godot", "unity", "unreal"]) {
            return .deepWork
        }
        if has(["slack", "discord", "zoom", "teams", "telegram", "outlook",
                "whatsapp", "facetime", "webex", "skype", "signal"]) {
            return .communication
        }
        // Apple Mail / Messages need exact-ish matches to avoid false hits
        if b == "com.apple.mail" || n == "mail" { return .communication }
        if b == "com.apple.mobilesms" || n == "messages" { return .communication }

        if has(["twitter", "x.com", "tweetbot", "reddit", "tiktok",
                "instagram", "facebook", "youtube", "netflix", "twitch",
                "hbo", "disney"]) {
            return .distraction
        }
        return .neutral
    }

    // Categorizes a browser tab by its domain
    static func categoryForDomain(_ host: String) -> AppCategory {
        let h = host.lowercased()
        // Matches the domain itself or any subdomain of it
        func eq(_ d: String) -> Bool { h == d || h.hasSuffix("." + d) }

        // Communication (specific subdomains first)
        if h == "mail.google.com" || h.hasPrefix("outlook.") || eq("slack.com")
            || eq("discord.com") || h == "web.whatsapp.com" || h == "teams.microsoft.com"
            || h == "calendar.google.com" || eq("messenger.com") || eq("front.com") {
            return .communication
        }
        if eq("twitter.com") || eq("x.com") || eq("reddit.com") || eq("youtube.com")
            || eq("tiktok.com") || eq("instagram.com") || eq("facebook.com") || eq("netflix.com")
            || eq("twitch.tv") || eq("9gag.com") || eq("hulu.com") || eq("primevideo.com")
            || eq("pinterest.com") || eq("threads.net") {
            return .distraction
        }
        if eq("github.com") || eq("gitlab.com") || eq("bitbucket.org") || eq("stackoverflow.com")
            || eq("stackexchange.com") || h == "developer.mozilla.org" || h.contains("readthedocs")
            || eq("figma.com") || eq("codesandbox.io") || eq("replit.com") || eq("notion.so")
            || eq("linear.app") || h.contains("atlassian.net") || eq("vercel.com") || eq("netlify.com")
            || h == "docs.google.com" || h == "colab.research.google.com" || eq("overleaf.com")
            || eq("claude.ai") || h == "chat.openai.com" || eq("chatgpt.com") || eq("leetcode.com")
            || h == "localhost" || h == "127.0.0.1" {
            return .deepWork
        }

        // Heuristic: catch streaming / piracy / gaming / gambling / adult sites
        // by name pattern, since they'll never be in the explicit lists above
        func hasAny(_ needles: [String]) -> Bool { needles.contains { h.contains($0) } }
        if h.hasSuffix(".tv") || hasAny([
            "watch", "movie", "flix", "tube", "anime", "manga", "hentai", "cartoon",
            "putlocker", "123movie", "soap2day", "fmovies", "gomovies", "yesmovies",
            "solarmovie", "primewire", "couchtuner", "lookmovie", "sflix", "hdtoday", "myflixer",
            "porn", "xxx", "xnxx", "xvideos", "redtube", "onlyfans", "nsfw", "camgirl",
            "casino", "gambl", "poker", "slots", "roulette", "bet365", "betting", "sportsbook",
            "game", "gaming",
        ]) {
            return .distraction
        }
        return .neutral
    }
}

// User-defined category overrides, keyed by app name or web host,
// stored in UserDefaults and applied at read time — so they retroactively
// reclassify history without touching stored sessions
enum CategoryOverrides {
    private static let mapKey = "categoryOverrides"

    static var map: [String: Int] {
        get { UserDefaults.standard.object(forKey: mapKey) as? [String: Int] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: mapKey) }
    }

    static func apply(key: String, category: AppCategory) {
        var m = map
        m[key] = category.rawValue
        map = m
    }

    static func remove(key: String) {
        var m = map
        m.removeValue(forKey: key)
        map = m
    }

    static func effectiveCategory(for key: String, default def: AppCategory) -> AppCategory {
        guard let raw = map[key], let cat = AppCategory(rawValue: raw) else { return def }
        return cat
    }
}
