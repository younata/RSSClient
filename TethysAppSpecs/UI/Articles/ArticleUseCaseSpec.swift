import Quick
import Nimble

@testable import TethysKit
import Tethys
import Result
import CBGPromise

class ArticleUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: DefaultArticleUseCase!
        var feedRepository: FakeDatabaseUseCase!
        var themeRepository: ThemeRepository!
        var articleService: FakeArticleService!

        beforeEach {
            feedRepository = FakeDatabaseUseCase()
            themeRepository = ThemeRepository(userDefaults: nil)
            articleService = FakeArticleService()
            subject = DefaultArticleUseCase(
                feedRepository: feedRepository,
                themeRepository: themeRepository,
                articleService: articleService
            )
        }

        describe("-articlesByAuthor:") {
            var receivedArticles: [Article]? = nil

            beforeEach {
                subject.articlesByAuthor(Author(name: "author", email: nil)) {
                    receivedArticles = Array($0)
                }
            }

            it("asks the feed repository for all feeds") {
                expect(feedRepository.feedsPromises.count) == 1
            }

            context("when the feeds promise resolves successfully") {
                let article1 = Article(title: "a", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [Author(name: "author", email: nil)], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, synced: false, feed: nil, flags: [])
                let article2 = Article(title: "b", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [Author(name: "foo", email: nil)], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, synced: false, feed: nil, flags: [])
                let article3 = Article(title: "c", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [Author(name: "author", email: nil)], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, synced: false, feed: nil, flags: [])
                let article4 = Article(title: "d", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [Author(name: "bar", email: nil)], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, synced: false, feed: nil, flags: [])

                let feed1 = Feed(title: "ab", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [article1, article2], image: nil)
                let feed2 = Feed(title: "cd", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [article3, article4], image: nil)
                article1.feed = feed1
                article2.feed = feed1
                article3.feed = feed2
                article4.feed = feed2

                beforeEach {
                    feedRepository.feedsPromises.last?.resolve(.success([feed1, feed2]))
                }

                it("calls the callback with a list of articles from those feeds filtered by article") {
                    expect(receivedArticles) == [article1, article3]
                }
            }

            context("when the feeds promise fails") {
                beforeEach {
                    feedRepository.feedsPromises.last?.resolve(.failure(.unknown))
                }

                it("calls the callback with nothing") {
                    expect(receivedArticles) == []
                }
            }
        }

        describe("-readArticle:") {
            it("marks the article as read if it wasn't already") {
                let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: false, synced: false, feed: nil, flags: [])

                _ = subject.readArticle(article)

                expect(feedRepository.lastArticleMarkedRead) == article
                expect(article.read) == true
            }

            it("doesn't mark the article as read if it already was") {
                let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: true, synced: false, feed: nil, flags: [])

                _ = subject.readArticle(article)

                expect(feedRepository.lastArticleMarkedRead).to(beNil())
            }

            describe("the returned html string") {
                var html: String!

                beforeEach {
                    let article = Article(title: "articleTitle", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "Example Content", read: true, synced: false, feed: nil, flags: [])

                    html = subject.readArticle(article)
                }

                it("is prefixed with the proper css") {
                    let cssURL = Bundle.main.url(forResource: themeRepository.articleCSSFileName, withExtension: "css")!
                    let css = try! String(contentsOf: cssURL)

                    let expectedPrefix = "<html><head>" +
                        "<style type=\"text/css\">\(css)</style>" +
                        "<meta name=\"viewport\" content=\"initial-scale=1.0,maximum-scale=10.0\"/>" +
                        "</head><body>"

                    expect(html.hasPrefix(expectedPrefix)) == true
                }

                it("is postfixed with prismJS") {
                    let prismURL = Bundle.main.url(forResource: "prism.js", withExtension: "html")!
                    let prismJS = try! String(contentsOf: prismURL)
                    expect(html.hasSuffix(prismJS + "</body></html>")) == true
                }

                it("contains the article content") {
                    expect(html).to(contain("Example Content"))
                }

                it("contains the article title") {
                    expect(html).to(contain("<h2>articleTitle</h2>"))
                }

                it("is properly structured") {
                    let cssURL = Bundle.main.url(forResource: themeRepository.articleCSSFileName, withExtension: "css")!
                    let css = try! String(contentsOf: cssURL)

                    let expectedPrefix = "<html><head>" +
                        "<style type=\"text/css\">\(css)</style>" +
                        "<meta name=\"viewport\" content=\"initial-scale=1.0,maximum-scale=10.0\"/>" +
                    "</head><body>"

                    let prismURL = Bundle.main.url(forResource: "prism.js", withExtension: "html")!
                    let prismJS = try! String(contentsOf: prismURL)

                    let expectedPostfix = prismJS + "</body></html>"

                    let expectedHTML = expectedPrefix + "<h2>articleTitle</h2>Example Content" + expectedPostfix

                    expect(html) == expectedHTML
                }
            }
        }

        describe("-toggleArticleRead:") {
            it("marks the article as read if it wasn't already") {
                let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: false, synced: false, feed: nil, flags: [])

                subject.toggleArticleRead(article)

                expect(feedRepository.lastArticleMarkedRead) == article
                expect(article.read) == true
            }

            it("marks the article as unread if it already was") {
                let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: Date(), identifier: "", content: "", read: true, synced: false, feed: nil, flags: [])

                subject.toggleArticleRead(article)

                expect(feedRepository.lastArticleMarkedRead) == article
                expect(article.read) == false
            }
        }
    }
}
