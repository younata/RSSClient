import Foundation
import CBGPromise
import Result
import Sinope

// this file was generated by Xcode-Better-Refactor-Tools
// https://github.com/tjarratt/xcode-better-refactor-tools

final class FakeSinopeRepository : Sinope.Repository, Equatable {
    init() {
    }

    var _authToken : String?
    var authToken : String? {
        get {
            return _authToken!
        }
    }

    private(set) var createAccountCallCount : Int = 0
    var createAccountStub : ((String, String) -> (Future<Result<Void, SinopeError>>))?
    private var createAccountArgs : Array<(String, String)> = []
    func createAccountReturns(_ stubbedValues: (Future<Result<Void, SinopeError>>)) {
        self.createAccountStub = {(email: String, password: String) -> (Future<Result<Void, SinopeError>>) in
            return stubbedValues
        }
    }
    func createAccountArgsForCall(_ callIndex: Int) -> (String, String) {
        return self.createAccountArgs[callIndex]
    }
    func createAccount(_ email: String, password: String) -> (Future<Result<Void, SinopeError>>) {
        self.createAccountCallCount += 1
        self.createAccountArgs.append((email, password))
        return self.createAccountStub!(email, password)
    }

    private(set) var loginCallCount : Int = 0
    var loginStub : ((String, String) -> (Future<Result<Void, SinopeError>>))?
    private var loginArgs : Array<(String, String)> = []
    func loginReturns(_ stubbedValues: (Future<Result<Void, SinopeError>>)) {
        self.loginStub = {(email: String, password: String) -> (Future<Result<Void, SinopeError>>) in
            return stubbedValues
        }
    }
    func loginArgsForCall(_ callIndex: Int) -> (String, String) {
        return self.loginArgs[callIndex]
    }
    func login(_ email: String, password: String) -> (Future<Result<Void, SinopeError>>) {
        self.loginCallCount += 1
        self.loginArgs.append((email, password))
        return self.loginStub!(email, password)
    }

    private(set) var loginAuthTokenCallCount : Int = 0
    private var loginAuthTokenArgs : Array<(String)> = []
    func loginAuthTokenArgsForCall(_ callIndex: Int) -> (String) {
        return self.loginAuthTokenArgs[callIndex]
    }
    func login(_ authToken: String) {
        self.loginAuthTokenCallCount += 1
        self._authToken = authToken
        self.loginAuthTokenArgs.append((authToken))
    }

    private(set) var addDeviceTokenCallCount : Int = 0
    var addDeviceTokenStub : ((String) -> (Future<Result<Void, SinopeError>>))?
    private var addDeviceTokenArgs : Array<(String)> = []
    func addDeviceTokenReturns(_ stubbedValues: (Future<Result<Void, SinopeError>>)) {
        self.addDeviceTokenStub = {(token: String) -> (Future<Result<Void, SinopeError>>) in
            return stubbedValues
        }
    }
    func addDeviceTokenArgsForCall(_ callIndex: Int) -> (String) {
        return self.addDeviceTokenArgs[callIndex]
    }
    func addDeviceToken(_ token: String) -> (Future<Result<Void, SinopeError>>) {
        self.addDeviceTokenCallCount += 1
        self.addDeviceTokenArgs.append((token))
        return self.addDeviceTokenStub!(token)
    }

    private(set) var deleteAccountCallCount : Int = 0
    var deleteAccountStub : (() -> (Future<Result<Void, SinopeError>>))?
    func deleteAccountReturns(_ stubbedValues: (Future<Result<Void, SinopeError>>)) {
        self.deleteAccountStub = {() -> (Future<Result<Void, SinopeError>>) in
            return stubbedValues
        }
    }
    func deleteAccount() -> (Future<Result<Void, SinopeError>>) {
        self.deleteAccountCallCount += 1
        return self.deleteAccountStub!()
    }

    private(set) var subscribeCallCount : Int = 0
    var subscribeStub : (([URL]) -> (Future<Result<[URL], SinopeError>>))?
    private var subscribeArgs : Array<([URL])> = []
    func subscribeReturns(_ stubbedValues: (Future<Result<[URL], SinopeError>>)) {
        self.subscribeStub = {(feeds: [URL]) -> (Future<Result<[URL], SinopeError>>) in
            return stubbedValues
        }
    }
    func subscribeArgsForCall(_ callIndex: Int) -> ([URL]) {
        return self.subscribeArgs[callIndex]
    }
    func subscribe(_ feeds: [URL]) -> (Future<Result<[URL], SinopeError>>) {
        self.subscribeCallCount += 1
        self.subscribeArgs.append((feeds as ([URL])))
        return self.subscribeStub!(feeds as [URL])
    }

    private(set) var unsubscribeCallCount : Int = 0
    var unsubscribeStub : (([URL]) -> (Future<Result<[URL], SinopeError>>))?
    private var unsubscribeArgs : Array<([URL])> = []
    func unsubscribeReturns(_ stubbedValues: (Future<Result<[URL], SinopeError>>)) {
        self.unsubscribeStub = {(feeds: [URL]) -> (Future<Result<[URL], SinopeError>>) in
            return stubbedValues
        }
    }
    func unsubscribeArgsForCall(_ callIndex: Int) -> ([URL]) {
        return self.unsubscribeArgs[callIndex]
    }
    func unsubscribe(_ feeds: [URL]) -> (Future<Result<[URL], SinopeError>>) {
        self.unsubscribeCallCount += 1
        self.unsubscribeArgs.append((feeds as ([URL])))
        return self.unsubscribeStub!(feeds as [URL])
    }

    private(set) var subscribedFeedsCallCount : Int = 0
    var subscribedFeedsStub : (() -> (Future<Result<[URL], SinopeError>>))?
    func subscribedFeedsReturns(_ stubbedValues: (Future<Result<[URL], SinopeError>>)) {
        self.subscribedFeedsStub  = {
            return stubbedValues
        }
    }
    func subscribedFeeds() -> Future<Result<[URL], SinopeError>> {
        self.subscribedFeedsCallCount += 1
        return self.subscribedFeedsStub!()
    }

    private(set) var fetchCallCount : Int = 0
    var fetchStub : (([URL: Date]) -> (Future<Result<([Feed]), SinopeError>>))?
    private var fetchArgs : Array<([URL: Date])> = []
    func fetchReturns(_ stubbedValues: (Future<Result<([Feed]), SinopeError>>)) {
        self.fetchStub = {(feeds: [URL: Date]) -> (Future<Result<([Feed]), SinopeError>>) in
            return stubbedValues
        }
    }
    func fetchArgsForCall(_ callIndex: Int) -> ([URL: Date]) {
        return self.fetchArgs[callIndex]
    }
    func fetch(_ feeds: [URL: Date]) -> (Future<Result<([Feed]), SinopeError>>) {
        self.fetchCallCount += 1
        self.fetchArgs.append((feeds as ([URL : Date])))
        return self.fetchStub!(feeds as [URL : Date])
    }

    private(set) var checkCallCount : Int = 0
    var checkStub : ((URL) -> (Future<Result<CheckResult, SinopeError>>))?
    private var checkArgs : Array<(URL)> = []
    func checkReturns(_ stubbedValues: (Future<Result<CheckResult, SinopeError>>)) {
        self.checkStub = {(url: URL) -> (Future<Result<CheckResult, SinopeError>>) in
            return stubbedValues
        }
    }
    func checkArgsForCall(_ callIndex: Int) -> (URL) {
        return self.checkArgs[callIndex]
    }
    func check(_ url: URL) -> Future<Result<CheckResult, SinopeError>> {
        self.checkCallCount += 1
        self.checkArgs.append((url) as (URL))
        return self.checkStub!(url as URL)
    }

    private(set) var markReadCallCount : Int = 0
    var markReadStub : (([URL: Bool]) -> (Future<Result<Void, SinopeError>>))?
    private var markReadArgs : Array<([URL: Bool])> = []
    func markReadReturns(_ stubbedValues: (Future<Result<Void, SinopeError>>)) {
        self.markReadStub = {(articles: [URL: Bool]) -> (Future<Result<Void, SinopeError>>) in
            return stubbedValues
        }
    }
    func markReadArgsForCall(_ callIndex: Int) -> ([URL : Bool]) {
        return self.markReadArgs[callIndex]
    }
    func markRead(articles: [URL : Bool]) -> Future<Result<Void, SinopeError>> {
        self.markReadCallCount += 1
        self.markReadArgs.append(articles)
        return self.markReadStub!(articles)
    }
}

func == (a: FakeSinopeRepository, b: FakeSinopeRepository) -> Bool {
    return a === b
}
