import Foundation

enum MontraAPIConfig {
    private static let defaultBaseURLs = [
        "http://localhost:8080",
        "http://127.0.0.1:8080"
    ]

    static func url(for path: String) -> URL? {
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"

        for baseURL in candidateBaseURLs {
            if let url = URL(string: normalizedPath, relativeTo: baseURL)?.absoluteURL {
                return url
            }
        }

        return nil
    }

    static var candidateBaseURLs: [URL] {
        var rawValues: [String] = []

        if let envURL = ProcessInfo.processInfo.environment["MONTRA_API_BASE_URL"], !envURL.isEmpty {
            rawValues.append(envURL)
        }

        if
            let infoURL = Bundle.main.object(forInfoDictionaryKey: "MONTRA_API_BASE_URL") as? String,
            !infoURL.isEmpty
        {
            rawValues.append(infoURL)
        }

        rawValues.append(contentsOf: defaultBaseURLs)

        var seen = Set<String>()
        var urls: [URL] = []

        for rawValue in rawValues {
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted, let url = URL(string: trimmed) else {
                continue
            }
            urls.append(url)
        }

        return urls
    }
}

enum LiveDataConnectivityProbe {
    private static let probePaths = [
        "/health",
        "/api/health",
        "/api/ping",
        "/"
    ]

    static func detect(timeout: TimeInterval = 4.0) async -> Bool {
        for baseURL in MontraAPIConfig.candidateBaseURLs {
            if await probeBaseURL(baseURL, timeout: timeout) {
                return true
            }
        }
        return false
    }

    private static func probeBaseURL(_ baseURL: URL, timeout: TimeInterval) async -> Bool {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = timeout
        sessionConfig.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: sessionConfig)

        for path in probePaths {
            guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
                continue
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = timeout

            do {
                let (_, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    return true
                }

                if (200...499).contains(httpResponse.statusCode) {
                    return true
                }
            } catch {
                continue
            }
        }

        return false
    }
}