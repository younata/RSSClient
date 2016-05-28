import UIKit
import Ra
import rNewsKit
import Result

public protocol BackgroundFetchHandler {
    func performFetch(notificationHandler: NotificationHandler,
        notificationSource: LocalNotificationSource,
        completionHandler: (UIBackgroundFetchResult) -> Void)
}

public struct DefaultBackgroundFetchHandler: BackgroundFetchHandler, Injectable {
    private let feedRepository: DatabaseUseCase

    public init(feedRepository: DatabaseUseCase) {
        self.feedRepository = feedRepository
    }

    public init(injector: Injector) {
        self.feedRepository = injector.create(DatabaseUseCase)!
    }

    public func performFetch(notificationHandler: NotificationHandler,
        notificationSource: LocalNotificationSource,
        completionHandler: (UIBackgroundFetchResult) -> Void) {
            let articlesIdentifierPromise = self.feedRepository.feeds().map { result -> [String] in
                if case let Result.Success(feeds) = result {
                    return feeds.reduce([]) {
                        return $0 + $1.articlesArray
                    }.map {
                        return $0.identifier
                    }
                } else {
                    return []
                }
            }

            feedRepository.updateFeeds {newFeeds, errors in
                guard errors.isEmpty else {
                    completionHandler(.Failed)
                    return
                }
                articlesIdentifierPromise.then { originalArticlesList in
                    let currentArticleList: [Article] = newFeeds.reduce([]) { return $0 + Array($1.articlesArray) }
                    guard currentArticleList.count != originalArticlesList.count else {
                        completionHandler(.NoData)
                        return
                    }
                    let filteredArticleList: [Article] = currentArticleList.filter {
                        return !originalArticlesList.contains($0.identifier)
                    }

                    if filteredArticleList.count > 0 {
                        for article in filteredArticleList {
                            notificationHandler.sendLocalNotification(notificationSource, article: article)
                        }
                        completionHandler(.NewData)
                    } else { completionHandler(.NoData) }
                }
            }
    }
}
