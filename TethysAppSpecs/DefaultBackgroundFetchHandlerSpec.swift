import Quick
import Nimble
import Tethys
import TethysKit

class DefaultBackgroundFetchHandlerSpec: QuickSpec {
    override func spec() {
        var dataRepository: FakeDatabaseUseCase! = nil

        var subject: DefaultBackgroundFetchHandler! = nil

        beforeEach {
            dataRepository = FakeDatabaseUseCase()
            subject = DefaultBackgroundFetchHandler(feedRepository: dataRepository)
        }

        describe("updating feeds") {
            var fetchResult: UIBackgroundFetchResult? = nil

            beforeEach {
                subject.performFetch { res in
                    fetchResult = res
                }
            }

            it("should make a network request") {
                expect(dataRepository.didUpdateFeeds) == true
            }

            it("makes a request for the list of feeds") {
                expect(dataRepository.feedsPromises.count) == 1
            }

            context("when the feeds list comes back and new articles are found") {
                var articles: [Article] = []
                var feeds: [Feed] = []
                beforeEach {
                    let feed1 = Feed(title: "a", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    let feed2 = Feed(title: "b", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                    let article1 = Article(title: "a", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "a", content: "", read: false, synced: false, feed: feed1, flags: [])
                    let article2 = Article(title: "b", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "b", content: "", read: false, synced: false, feed: feed1, flags: [])
                    let article3 = Article(title: "c", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "c", content: "", read: false, synced: false, feed: feed2, flags: [])
                    let article4 = Article(title: "d", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "d", content: "", read: false, synced: false, feed: feed2, flags: [])

                    feed1.addArticle(article1)
                    feed1.addArticle(article2)
                    feed2.addArticle(article3)
                    feed2.addArticle(article4)

                    feeds = [feed1, feed2]
                    articles = [article1, article2, article3, article4]

                    dataRepository.feedsPromises.last?.resolve(.success([]))

                    dataRepository.updateFeedsCompletion(feeds, [])
                }

                it("should call the completion handler and indicate that there was new data found") {
                    expect(fetchResult).to(equal(UIBackgroundFetchResult.newData))
                }
            }

            context("when no new articles are found") {
                beforeEach {
                    dataRepository.feedsPromises.last?.resolve(.success([]))
                    dataRepository.updateFeedsCompletion([], [])
                }

                it("should call the completion handler and indicate that there was no new data found") {
                    expect(fetchResult).to(equal(UIBackgroundFetchResult.noData))
                }
            }

            context("when there is an error updating feeds") {
                beforeEach {
                    dataRepository.feedsPromises.last?.resolve(.success([]))
                    dataRepository.updateFeedsCompletion([], [NSError(domain: "", code: 0, userInfo: nil)])
                }

                it("should call the completion handler and indicate that there was an error") {
                    expect(fetchResult).to(equal(UIBackgroundFetchResult.failed))
                }
            }

            context("when the feeds request has an issue") { // TODO!

            }
        }
    }
}
