import CBGPromise
import Result

public protocol ArticleService {
    func feed(of article: Article) -> Future<Result<Feed, TethysError>>

    func mark(article: Article, asRead read: Bool) -> Future<Result<Article, TethysError>>

    func authors(of article: Article) -> String

    func date(for article: Article) -> Date
    func estimatedReadingTime(of article: Article) -> TimeInterval

}

import RealmSwift

final class RealmArticleService: ArticleService {
    private let realmProvider: RealmProvider
    private let mainQueue: OperationQueue
    private let workQueue: OperationQueue

    init(realmProvider: RealmProvider, mainQueue: OperationQueue, workQueue: OperationQueue) {
        self.realmProvider = realmProvider
        self.mainQueue = mainQueue
        self.workQueue = workQueue
    }

    func feed(of article: Article) -> Future<Result<Feed, TethysError>> {
        let promise = Promise<Result<Feed, TethysError>>()
        self.workQueue.addOperation {
            guard let feed = self.realmArticle(for: article)?.feed else {
                return self.resolve(promise: promise, error: .database(.entryNotFound))
            }
            return self.resolve(promise: promise, with: Feed(realmFeed: feed))
        }
        return promise.future
    }

    func mark(article: Article, asRead read: Bool) -> Future<Result<Article, TethysError>> {
        let promise = Promise<Result<Article, TethysError>>()
        guard article.read != read else {
            promise.resolve(.success(article))
            return promise.future
        }
        self.workQueue.addOperation {
            guard let realmArticle = self.realmArticle(for: article) else {
                return self.resolve(promise: promise, error: .database(.entryNotFound))
            }
            let realm = self.realmProvider.realm()
            realm.beginWrite()
            realmArticle.read = read
            do {
                try realm.commitWrite()
            } catch let exception {
                dump(exception)
            }
            let feed: Feed?
            if let realmFeed = realmArticle.feed {
                feed = Feed(realmFeed: realmFeed)
            } else {
                feed = nil
            }
            self.resolve(promise: promise, with: Article(realmArticle: realmArticle, feed: feed))
        }
        return promise.future
    }

    func authors(of article: Article) -> String {
        return article.authors.map { $0.description }.joined(separator: ", ")
    }

    func date(for article: Article) -> Date {
        let realmArticle = self.realmArticle(for: article)
        return realmArticle?.updatedAt ?? realmArticle?.published ?? Date()
    }

    func estimatedReadingTime(of article: Article) -> TimeInterval {
        guard let realmArticle = self.realmArticle(for: article) else { return 0 }
        if realmArticle.estimatedReadingTime > 0 {
            return realmArticle.estimatedReadingTime
        }
        let text = realmArticle.content?.optional ?? realmArticle.summary?.optional ?? ""
        let readingTime = estimateReadingTime(text)
        self.saveReadingTime(readingTime, for: article)
        return readingTime
    }

    private func realmArticle(for article: Article) -> RealmArticle? {
        return self.realmProvider.realm().object(ofType: RealmArticle.self, forPrimaryKey: article.identifier)
    }

    private func saveReadingTime(_ readingTime: TimeInterval, for article: Article) {
        self.workQueue.addOperation {
            let realm = self.realmProvider.realm()
            guard let realmArticle = self.realmArticle(for: article) else { return }
            realm.beginWrite()
            realmArticle.estimatedReadingTime = readingTime
            do {
                try realm.commitWrite()
            } catch let exception {
                dump(exception)
            }
        }
    }

    private func resolve<T>(promise: Promise<Result<T, TethysError>>, with value: T? = nil, error: TethysError? = nil) {
        self.mainQueue.addOperation {
            let result: Result<T, TethysError>
            if let value = value {
                result = Result<T, TethysError>.success(value)
            } else if let error = error {
                result = Result<T, TethysError>.failure(error)
            } else {
                fatalError("Called resolve with two nil arguments")
            }

            promise.resolve(result)
        }
    }
}
