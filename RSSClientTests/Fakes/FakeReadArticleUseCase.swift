import rNewsKit
import rNews

// this file was generated by Xcode-Better-Refactor-Tools
// https://github.com/tjarratt/xcode-better-refactor-tools

class FakeReadArticleUseCase : ReadArticleUseCase {
    init() {
    }

    private(set) var readArticleCallCount : Int = 0
    var readArticleStub : ((Article) -> (String))?
    private var readArticleArgs : Array<(Article)> = []
    func readArticleReturns(stubbedValues: (String)) {
        self.readArticleStub = {(article: Article) -> (String) in
            return stubbedValues
        }
    }
    func readArticleArgsForCall(callIndex: Int) -> (Article) {
        return self.readArticleArgs[callIndex]
    }
    func readArticle(article: Article) -> (String) {
        self.readArticleCallCount++
        self.readArticleArgs.append((article))
        return self.readArticleStub!(article)
    }

    private(set) var userActivityForArticleCallCount : Int = 0
    var userActivityForArticleStub : ((Article) -> (NSUserActivity))?
    private var userActivityForArticleArgs : Array<(Article)> = []
    func userActivityForArticleReturns(stubbedValues: (NSUserActivity)) {
        self.userActivityForArticleStub = {(article: Article) -> (NSUserActivity) in
            return stubbedValues
        }
    }
    func userActivityForArticleArgsForCall(callIndex: Int) -> (Article) {
        return self.userActivityForArticleArgs[callIndex]
    }
    func userActivityForArticle(article: Article) -> (NSUserActivity) {
        self.userActivityForArticleCallCount++
        self.userActivityForArticleArgs.append((article))
        return self.userActivityForArticleStub!(article)
    }

    private(set) var toggleArticleReadCallCount : Int = 0
    private var toggleArticleReadArgs : Array<(Article)> = []
    func toggleArticleReadArgsForCall(callIndex: Int) -> (Article) {
        return self.toggleArticleReadArgs[callIndex]
    }
    func toggleArticleRead(article: Article) {
        self.toggleArticleReadCallCount++
        self.toggleArticleReadArgs.append((article))
    }

    static func reset() {
    }
}