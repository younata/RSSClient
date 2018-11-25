import Result
import CBGPromise
import RealmSwift

public protocol FeedService {
    func feeds() -> Future<Result<AnyCollection<Feed>, TethysError>>
    func articles(of feed: Feed) -> Future<Result<AnyCollection<Article>, TethysError>>

    func readAll(of feed: Feed) -> Future<Result<Void, TethysError>>
    func remove(feed: Feed) -> Future<Result<Void, TethysError>>
}

struct RealmFeedService: FeedService {
    private let realmProvider: RealmProvider
    private let mainQueue: OperationQueue
    private let workQueue: OperationQueue

    init(realmProvider: RealmProvider, mainQueue: OperationQueue, workQueue: OperationQueue) {
        self.realmProvider = realmProvider
        self.mainQueue = mainQueue
        self.workQueue = workQueue
    }

    func feeds() -> Future<Result<AnyCollection<Feed>, TethysError>> {
        let promise = Promise<Result<AnyCollection<Feed>, TethysError>>()
        self.workQueue.addOperation {
            let feeds = self.realmProvider.realm().objects(RealmFeed.self).sorted(by: { (lhs, rhs) -> Bool in
                let unreadPredicate = NSPredicate(format: "read == false")
                let lhsUnread = lhs.articles.filter(unreadPredicate).count
                let rhsUnread = rhs.articles.filter(unreadPredicate).count
                guard lhsUnread == rhsUnread else {
                    return lhsUnread > rhsUnread
                }
                return (lhs.title ?? "") < (rhs.title ?? "")
            })
            return self.resolve(promise: promise, with: AnyCollection(feeds.map { Feed(realmFeed: $0 )} ))
        }
        return promise.future
    }

    func articles(of feed: Feed) -> Future<Result<AnyCollection<Article>, TethysError>> {
        let promise = Promise<Result<AnyCollection<Article>, TethysError>>()
        self.workQueue.addOperation {
            guard let realmFeed = self.realmFeed(for: feed) else {
                return self.resolve(promise: promise, error: .database(.entryNotFound))
            }

            let articles = realmFeed.articles.sorted(by: [
//                SortDescriptor(keyPath: "updatedAt", ascending: false),
                SortDescriptor(keyPath: "published", ascending: false)
            ])
            return self.resolve(promise: promise, with: AnyCollection(articles.map { Article(realmArticle: $0, feed: nil)} ))
        }
        return promise.future
    }

    func readAll(of feed: Feed) -> Future<Result<Void, TethysError>> {
        let promise = Promise<Result<Void, TethysError>>()
        self.workQueue.addOperation {
            guard let realmFeed = self.realmFeed(for: feed) else {
                return self.resolve(promise: promise, error: .database(.entryNotFound))
            }

            let realm = self.realmProvider.realm()
            realm.beginWrite()

            realmFeed.articles.filter("read == false").forEach { $0.read = true }

            do {
                try realm.commitWrite()
            } catch let exception {
                dump(exception)
                return self.resolve(promise: promise, error: .database(.unknown))
            }

            return self.resolve(promise: promise, with: Void())
        }
        return promise.future
    }

    func remove(feed: Feed) -> Future<Result<Void, TethysError>> {
        let promise = Promise<Result<Void, TethysError>>()

        self.workQueue.addOperation {
            guard let realmFeed = self.realmFeed(for: feed) else {
                return self.resolve(promise: promise, error: .database(.entryNotFound))
            }

            let realm = self.realmProvider.realm()
            realm.beginWrite()

            realm.delete(realmFeed)

            do {
                try realm.commitWrite()
            } catch let exception {
                dump(exception)
                return self.resolve(promise: promise, error: .database(.unknown))
            }

            return self.resolve(promise: promise, with: Void())
        }
        return promise.future
    }

    private func realmFeed(for feed: Feed) -> RealmFeed? {
        return self.realmProvider.realm().object(ofType: RealmFeed.self, forPrimaryKey: feed.identifier)
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
