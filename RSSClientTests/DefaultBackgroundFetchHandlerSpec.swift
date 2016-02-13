import Quick
import Nimble
import Ra
import rNews
import rNewsKit

class DefaultBackgroundFetchHandlerSpec: QuickSpec {
    override func spec() {
        var injector: Injector! = nil
        var dataRepository: FakeFeedRepository! = nil

        var subject: DefaultBackgroundFetchHandler! = nil

        beforeEach {
            injector = Injector()
            dataRepository = FakeFeedRepository()
            dataRepository.feedsList = []
            injector.bind(FeedRepository.self, toInstance: dataRepository)

            subject = injector.create(DefaultBackgroundFetchHandler)!
        }

        describe("updating feeds") {
            var notificationHandler: FakeNotificationHandler! = nil
            var notificationSource: FakeNotificationSource! = nil
            var fetchResult: UIBackgroundFetchResult? = nil

            beforeEach {
                notificationHandler = FakeNotificationHandler()
                notificationSource = FakeNotificationSource()
                subject.performFetch(notificationHandler, notificationSource: notificationSource, completionHandler: {res in
                    fetchResult = res
                })
            }

            it("should make a network request") {
                expect(dataRepository.didUpdateFeeds).to(beTruthy())
            }

            context("when new articles are found") {
                var articles: [Article] = []
                var feeds: [Feed] = []
                beforeEach {
                    let feed1 = Feed(title: "a", url: nil, summary: "", query: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    let feed2 = Feed(title: "b", url: nil, summary: "", query: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                    let article1 = Article(title: "a", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "a", content: "", read: false, estimatedReadingTime: 0, feed: feed1, flags: [], enclosures: [])
                    let article2 = Article(title: "b", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "b", content: "", read: false, estimatedReadingTime: 0, feed: feed1, flags: [], enclosures: [])
                    let article3 = Article(title: "c", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "c", content: "", read: false, estimatedReadingTime: 0, feed: feed2, flags: [], enclosures: [])
                    let article4 = Article(title: "d", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "d", content: "", read: false, estimatedReadingTime: 0, feed: feed2, flags: [], enclosures: [])

                    feed1.addArticle(article1)
                    feed1.addArticle(article2)
                    feed2.addArticle(article3)
                    feed2.addArticle(article4)

                    feeds = [feed1, feed2]
                    articles = [article1, article2, article3, article4]

                    dataRepository.feedsList = feeds
                    dataRepository.updateFeedsCompletion(feeds, [])
                }

                it("should send local notifications for each new article") {
                    expect(notificationHandler.sendLocalNotificationCallCount) == articles.count
                }

                it("should call the completion handler and indicate that there was new data found") {
                    expect(fetchResult).to(equal(UIBackgroundFetchResult.NewData))
                }
            }

            context("when no new articles are found") {
                beforeEach {
                    dataRepository.updateFeedsCompletion([], [])
                }

                it("should not send any new local notifications") {
                    expect(notificationHandler.sendLocalNotificationCallCount) == 0
                }

                it("should call the completion handler and indicate that there was no new data found") {
                    expect(fetchResult).to(equal(UIBackgroundFetchResult.NoData))
                }
            }

            context("when there is an error updating feeds") {
                beforeEach {
                    dataRepository.updateFeedsCompletion([], [NSError(domain: "", code: 0, userInfo: nil)])
                }

                it("should not send any new local notifications") {
                    expect(notificationSource.scheduledNotes).to(beEmpty())
                }

                it("should call the completion handler and indicate that there was an error") {
                    expect(fetchResult).to(equal(UIBackgroundFetchResult.Failed))
                }
            }
        }
    }
}