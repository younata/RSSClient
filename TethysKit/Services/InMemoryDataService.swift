import CBGPromise
import Result

final class InMemoryDataService: DataService {
    let mainQueue: OperationQueue
    let searchIndex: SearchIndex?

    init(mainQueue: OperationQueue, searchIndex: SearchIndex?) {
        self.mainQueue = mainQueue
        self.searchIndex = searchIndex
    }

    var feeds = [Feed]()
    var articles = [Article]()

    func createFeed(url: URL, callback: @escaping (Feed) -> Void) -> Future<Result<Feed, TethysError>> {
        let feed = Feed(title: "", url: url, summary: "", tags: [], waitPeriod: 0,
                        remainingWait: 0, articles: [], image: nil)
        callback(feed)
        self.feeds.append(feed)
        let promise = Promise<Result<Feed, TethysError>>()
        promise.resolve(.success(feed))
        return promise.future
    }

    func createArticle(url: URL, feed: Feed?, callback: @escaping (Article) -> Void) {
        let article = Article(title: "", link: url, summary: "", authors: [], published: Date(), updatedAt: nil,
                              identifier: "", content: "", read: false, synced: false, feed: feed, flags: [])
        feed?.addArticle(article)
        callback(article)
        self.articles.append(article)
    }

    func findOrCreateFeed(url: URL) -> Future<Feed> {
        let promise = Promise<Feed>()
        if let feed = self.feeds.first(where: { $0.url == url }) {
            promise.resolve(feed)
        } else {
            let feed = Feed(title: "", url: url, summary: "", tags: [], waitPeriod: 0,
                            remainingWait: 0, articles: [], image: nil)
            self.feeds.append(feed)
            promise.resolve(feed)
        }
        return promise.future
    }

    func findOrCreateArticle(feed: Feed, url: URL) -> Future<Article> {
        let promise = Promise<Article>()
        if let article = Array(feed.articlesArray).objectPassingTest({ $0.link == url }) {
            promise.resolve(article)
        } else {
            let article = Article(title: "", link: url, summary: "", authors: [], published: Date(), updatedAt: nil,
                                  identifier: "", content: "", read: false, synced: false, feed: feed, flags: [])
            feed.addArticle(article)
            self.articles.append(article)
            if !self.feeds.contains(feed) {
                self.feeds.append(feed)
            }
            promise.resolve(article)
        }
        return promise.future
    }

    func allFeeds() -> Future<Result<DataStoreBackedArray<Feed>, TethysError>> {
        let promise = Promise<Result<DataStoreBackedArray<Feed>, TethysError>>()
        promise.resolve(.success(DataStoreBackedArray(self.feeds)))
        return promise.future
    }

    func articlesMatchingPredicate(_ predicate: NSPredicate) ->
        Future<Result<DataStoreBackedArray<Article>, TethysError>> {
            let promise = Promise<Result<DataStoreBackedArray<Article>, TethysError>>()
            promise.resolve(.success(DataStoreBackedArray(self.articles.filter({ predicate.evaluate(with: $0) }))))
            return promise.future
    }

    func deleteFeed(_ feed: Feed) -> Future<Result<Void, TethysError>> {
        if let index = self.feeds.index(of: feed) {
            self.feeds.remove(at: index)
        }
        for _ in 0..<feed.articlesArray.count {
            guard let article = feed.articlesArray.first else { break }
            _ = self.deleteArticle(article)
            _ = feed.removeArticle(article)
        }
        let promise = Promise<Result<Void, TethysError>>()
        promise.resolve(.success())
        return promise.future
    }

    func deleteArticle(_ article: Article) -> Future<Result<Void, TethysError>> {
        if let index = self.articles.index(of: article) {
            self.articles.remove(at: index)
        }
        article.feed?.removeArticle(article)
        article.feed = nil
        let promise = Promise<Result<Void, TethysError>>()
        promise.resolve(.success())
        return promise.future
    }

    func batchCreate(feedURLs: [URL], articleURLs: [URL]) ->
        Future<Result<([Feed], [Article]), TethysError>> {
            let promise = Promise<Result<([Feed], [Article]), TethysError>>()
            var feeds: [Feed] = []
            var articles: [Article] = []
            feedURLs.forEach {
                _ = self.createFeed(url: $0) { f in feeds.append(f) }.wait()
            }
            articleURLs.forEach {
                self.createArticle(url: $0, feed: nil) { articles.append($0) }
            }

            let success = Result<([Feed], [Article]), TethysError>(value: (feeds, articles))
            promise.resolve(success)
            return promise.future
    }

    var saveCallCount = 0
    var saveCallArgs: [([Feed], [Article])] = []
    func batchSave(_ feeds: [Feed], articles: [Article]) -> Future<Result<Void, TethysError>> {
        let promise = Promise<Result<Void, TethysError>>()
        promise.resolve(.success())
        self.saveCallCount += 1
        self.saveCallArgs.append((feeds, articles))
        return promise.future
    }

    func deleteEverything() -> Future<Result<Void, TethysError>> {
        self.feeds = []
        self.articles = []

        let promise = Promise<Result<Void, TethysError>>()
        promise.resolve(.success())
        return promise.future
    }
}
