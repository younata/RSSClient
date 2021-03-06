import TethysKit

// this file was generated by Xcode-Better-Refactor-Tools
// https://github.com/tjarratt/xcode-better-refactor-tools

class FakeAnalytics : Analytics, Equatable {
    init() {
    }

    private(set) var logEventCallCount : Int = 0
    private var logEventArgs : Array<(String, [String: String]?)> = []
    func logEventArgsForCall(_ callIndex: Int) -> (String, [String: String]?) {
        return self.logEventArgs[callIndex]
    }
    func logEvent(_ event: String, data: [String: String]?) {
        self.logEventCallCount += 1
        self.logEventArgs.append((event, data))
    }

    static func reset() {
    }
}

func == (a: FakeAnalytics, b: FakeAnalytics) -> Bool {
    return a === b
}
