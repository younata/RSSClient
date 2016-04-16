import Foundation
import CoreData
import CBGPromise
@testable import rNewsKit

class FakeDataRepository : DataRepository {
    var databaseUpdateIsAvailable = false
    override func databaseUpdateAvailable() -> Bool {
        return self.databaseUpdateIsAvailable
    }

    var performDatabaseUpdatesProgress: (Double -> Void)? = nil
    var performDatabaseUpdatesCallback: (Void -> Void)? = nil
    override func performDatabaseUpdates(progress: Double -> Void, callback: Void -> Void) {
        self.performDatabaseUpdatesProgress = progress
        self.performDatabaseUpdatesCallback = callback
    }

    var subscribers = Array<DataSubscriber>()
    override func addSubscriber(subscriber: DataSubscriber) {
        self.subscribers.append(subscriber)
    }

    var lastSavedFeed: Feed? = nil
    override func saveFeed(feed: Feed) {
        lastSavedFeed = feed
    }

    var lastDeletedFeed: Feed? = nil
    override func deleteFeed(feed: Feed) {
        lastDeletedFeed = feed
    }

    var lastFeedMarkedRead: Feed? = nil
    var lastMarkedReadPromise: Promise<Int>? = nil
    override func markFeedAsRead(feed: Feed) -> Future<Int> {
        lastFeedMarkedRead = feed
        self.lastMarkedReadPromise = Promise<Int>()
        return self.lastMarkedReadPromise!.future
    }

    var tagsList: [String] = []
    override func allTags(callback: ([String]) -> (Void)) {
        callback(tagsList)
    }

    var feedsList: [Feed] = []
    override func feeds(callback: ([Feed]) -> (Void)) {
        return callback(feedsList)
    }

    var articlesList: [Article] = []
    override func articlesMatchingQuery(query: String, callback: ([Article]) -> (Void)) {
        return callback(articlesList)
    }

    var lastArticleMarkedRead: Article? = nil
    override func markArticle(article: Article, asRead read: Bool) {
        lastArticleMarkedRead = article
        article.read = read
    }

    var lastDeletedArticle: Article? = nil
    override func deleteArticle(article: Article) {
        lastDeletedArticle = article
        article.feed?.removeArticle(article)
        article.feed = nil
    }

    var didUpdateFeeds = false
    var updateFeedsCompletion: ([Feed], [NSError]) -> (Void) = {_ in }
    override func updateFeeds(callback: ([Feed], [NSError]) -> (Void)) {
        didUpdateFeeds = true
        updateFeedsCompletion = callback
    }
}