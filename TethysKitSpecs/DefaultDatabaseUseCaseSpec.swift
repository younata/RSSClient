import Quick
import Nimble
@testable import TethysKit
import CBGPromise
import Result
#if os(iOS)
    import CoreSpotlight
    import MobileCoreServices
#endif

class DefaultDatabaseUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: DefaultDatabaseUseCase!

        var mainQueue: FakeOperationQueue!

        var feeds: [TethysKit.Feed] = []
        var feed1: TethysKit.Feed!
        var feed2: TethysKit.Feed!

        var article1: TethysKit.Article!
        var article2: TethysKit.Article!

        var dataSubscriber: FakeDataSubscriber!

        var reachable: FakeReachable!

        var dataServiceFactory: FakeDataServiceFactory!
        var dataService: InMemoryDataService!

        var updateUseCase: FakeUpdateUseCase!

        var databaseMigrator: FakeDatabaseMigrator!

        beforeEach {
            feed1 = TethysKit.Feed(title: "a", url: URL(string: "https://example.com/feed1.feed")!, summary: "",
                tags: ["a", "b", "c", "d"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            article1 = TethysKit.Article(title: "b", link: URL(string: "https://example.com/article1.html")!,
                summary: "<p>Hello world!</p>", authors: [], published: Date(), updatedAt: nil, identifier: "article1",
                content: "", read: false, synced: true, estimatedReadingTime: 0, feed: feed1, flags: [])

            article2 = TethysKit.Article(title: "c", link: URL(string: "https://example.com/article2.html")!,
                summary: "<p>Hello world!</p>", authors: [], published: Date(), updatedAt: nil, identifier: "article2",
                content: "", read: true, synced: true, estimatedReadingTime: 0, feed: feed1, flags: [])

            feed1.addArticle(article1)
            feed1.addArticle(article2)

            feed2 = TethysKit.Feed(title: "e", url: URL(string: "https://example.com/feed2.feed")!, summary: "",
                tags: ["dad"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            feeds = [feed1, feed2]

            reachable = FakeReachable(hasNetworkConnectivity: true)

            mainQueue = FakeOperationQueue()

            dataServiceFactory = FakeDataServiceFactory()
            dataService = InMemoryDataService(mainQueue: mainQueue, searchIndex: FakeSearchIndex())
            dataServiceFactory.currentDataService = dataService

            dataService.feeds = feeds
            dataService.articles = [article1, article2]

            updateUseCase = FakeUpdateUseCase()

            databaseMigrator = FakeDatabaseMigrator()

            subject = DefaultDatabaseUseCase(mainQueue: mainQueue,
                reachable: reachable,
                dataServiceFactory: dataServiceFactory,
                updateUseCase: updateUseCase,
                databaseMigrator: databaseMigrator
            )

            dataSubscriber = FakeDataSubscriber()
            subject.addSubscriber(dataSubscriber)
        }

        afterEach {
            feeds = []
        }

        describe("databaseUpdateAvailable") {
            it("returns false by default") {
                expect(subject.databaseUpdateAvailable()) == false
            }
        }

        describe("as a DataRetriever") {
            describe("allTags") {
                var calledHandler = false
                var calledResults: Result<[String], TethysError>?

                beforeEach {
                    calledHandler = false

                    _ = subject.allTags().then {
                        calledHandler = true
                        calledResults = $0
                    }
                }

                it("should return a list of all tags") {
                    expect(calledHandler) == true
                    expect(calledResults).toNot(beNil())
                    switch calledResults! {
                    case let .success(tags):
                        expect(tags) == ["a", "b", "c", "d", "dad"]
                    case .failure(_):
                        expect(false) == true
                    }

                }
            }

            describe("feeds") {
                var calledHandler = false
                var calledResults: Result<[TethysKit.Feed], TethysError>?

                beforeEach {
                    calledHandler = false

                    _ = subject.feeds().then {
                        calledHandler = true
                        calledResults = $0
                    }
                }

                it("returns the list of all feeds") {
                    expect(calledHandler) == true
                    expect(calledResults).toNot(beNil())
                    switch calledResults! {
                    case let .success(receivedFeeds):
                        expect(receivedFeeds) == feeds
                        for (idx, feed) in feeds.enumerated() {
                            let receivedFeed = receivedFeeds[idx]
                            expect(receivedFeed.articlesArray == feed.articlesArray) == true
                        }
                    case .failure(_):
                        expect(false) == true
                    }
                }
            }
        }

        describe("as a DataWriter") {
            describe("newFeed") {
                var createdFeed: TethysKit.Feed? = nil
                var newFeedFuture: Future<Result<Void, TethysError>>!

                describe("and the user makes a standard feed") {
                    beforeEach {
                        newFeedFuture = subject.newFeed(url: URL(string: "https://example.com/feed")!) {feed in
                            createdFeed = feed
                        }
                    }

                    it("should call back with a created feed") {
                        expect(dataService.feeds).to(contain(createdFeed!))
                        expect(dataService.feeds.count) == 3
                    }

                    it("resolves the future") {
                        expect(newFeedFuture.value?.value).toNot(beNil())
                    }
                }
            }

            describe("deleteFeed") {
                beforeEach {
                    mainQueue.runSynchronously = true
                    _ = subject.deleteFeed(feed1)
                }

                it("should remove the feed from the data service") {
                    expect(dataService.feeds).toNot(contain(feed1))
                }

                it("should inform any subscribers") {
                    expect(dataSubscriber.deletedFeed).to(equal(feed1))
                    expect(dataSubscriber.deletedFeedsLeft).to(equal(1))
                }
            }

            describe("markFeedAsRead") {
                var markedReadFuture: Future<Result<Int, TethysError>>?
                beforeEach {
                    mainQueue.runSynchronously = true
                    markedReadFuture = subject.markFeedAsRead(feed1)
                }

                it("marks every article in the feed as read") {
                    for article in feed1.articlesArray {
                        expect(article.read) == true
                    }
                }

                it("informs any subscribers") {
                    expect(dataSubscriber.markedArticles).toNot(beNil())
                    expect(dataSubscriber.read) == true
                }

                it("resolves the promise with the number of articles marked read") {
                    expect(markedReadFuture?.value).toNot(beNil())
                    let calledResults = markedReadFuture!.value!
                    switch calledResults {
                    case let .success(value):
                        expect(value) == 1
                    case .failure(_):
                        expect(false) == true
                    }
                }
            }

            describe("deleteArticle") {
                var article: TethysKit.Article! = nil

                beforeEach {
                    article = article1

                    _ = subject.deleteArticle(article)
                }

                it("should remove the article from the data service") {
                    expect(dataService.articles).toNot(contain(article))
                }

                it("should inform any subscribes") {
                    expect(dataSubscriber.deletedArticle).to(equal(article))
                }
            }

            describe("markArticle:asRead:") {
                var article: TethysKit.Article! = nil

                beforeEach {
                    article = article1

                    mainQueue.runSynchronously = true
                }

                beforeEach {
                    _ = subject.markArticle(article, asRead: true)
                }

                it("marks the article object as read") {
                    expect(article.read) == true
                }

                it("informs any subscribers") {
                    expect(dataSubscriber.markedArticles).to(equal([article]))
                    expect(dataSubscriber.read) == true
                }
            }

            describe("updateFeed:callback:") {
                var didCallCallback = false
                var callbackError: NSError? = nil
                var feed: TethysKit.Feed! = nil

                var updateFeedsPromise: Promise<Result<Void, TethysError>>!

                beforeEach {
                    didCallCallback = false
                    callbackError = nil

                    feed = feed1

                    updateFeedsPromise = Promise<Result<Void, TethysError>>()
                    updateUseCase.updateFeedsReturns(updateFeedsPromise.future)
                }

                context("when the network is not reachable") {
                    var updatedFeed: TethysKit.Feed? = nil
                    beforeEach {
                        reachable.hasNetworkConnectivity = false

                        subject.updateFeed(feed) {changedFeed, error in
                            didCallCallback = true
                            updatedFeed = changedFeed
                            callbackError = error
                        }
                    }

                    it("should not make an update request") {
                        expect(updateUseCase.updateFeedsCallCount) == 0
                    }

                    it("should call the completion handler without an error and with the original feed") {
                        expect(didCallCallback) == true
                        expect(callbackError).to(beNil())
                        expect(updatedFeed).to(equal(feed))
                    }
                }

                context("when the network is reachable") {
                    beforeEach {
                        subject.updateFeed(feed) {changedFeed, error in
                            didCallCallback = true
                            callbackError = error
                        }
                    }

                    it("should make a request to update the feed") {
                        expect(updateUseCase.updateFeedsCallCount) == 1
                        guard updateUseCase.updateFeedsCallCount == 1 else { return }
                        let args = updateUseCase.updateFeedsArgsForCall(0)
                        expect(args.0) == [feed]
                        expect(args.1 as? [FakeDataSubscriber]) == [dataSubscriber]
                    }

                    context("when the network request succeeds") {
                        beforeEach {
                            updateFeedsPromise.resolve(.success())
                            mainQueue.runNextOperation()
                        }

                        describe("when the last operation completes") {
                            beforeEach {
                                mainQueue.runNextOperation()
                            }

                            it("should inform subscribers that we updated our datastore for that feed") {
                                expect(dataSubscriber.updatedFeeds) == feeds
                            }

                            it("should call the completion handler without an error") {
                                expect(didCallCallback) == true
                                expect(callbackError).to(beNil())
                            }
                        }
                    }

                    context("when the network request fails") {
                        beforeEach {
                            updateFeedsPromise.resolve(.failure(.unknown))
                        }

                        it("adds an operation to the main queue") {
                            expect(mainQueue.operationCount) > 1
                        }

                        describe("when the last operation completes") {
                            beforeEach {
                                while mainQueue.operationCount > 0 {
                                    mainQueue.runNextOperation()
                                }
                            }

                            it("should inform subscribers that we updated our datastore for that feed") {
                                expect(dataSubscriber.updatedFeeds) == []
                            }

                            it("should call the completion handler without an error") {
                                expect(didCallCallback) == true
                                expect(callbackError) == NSError(domain: "TethysError",
                                                                 code: 0,
                                                                 userInfo: [NSLocalizedDescriptionKey: TethysError.unknown.localizedDescription])
                            }
                        }
                    }
                }
            }

            describe("updateFeeds:") {
                var didCallCallback = false
                var callbackErrors: [NSError] = []

                var updateFeedsPromise: Promise<Result<Void, TethysError>>!

                beforeEach {
                    didCallCallback = false
                    callbackErrors = []

                    updateFeedsPromise = Promise<Result<Void, TethysError>>()
                    updateUseCase.updateFeedsReturns(updateFeedsPromise.future)
                }

                context("when there are no feeds in the data store") {
                    beforeEach {
                        dataService.feeds = []
                        subject.updateFeeds {feeds, errors in
                            didCallCallback = true
                            callbackErrors = errors
                        }
                    }

                    it("should call the callback with no errors") {
                        expect(didCallCallback) == true
                        expect(callbackErrors).to(beEmpty())
                    }

                    it("should not inform any subscribers") {
                        expect(dataSubscriber.updatedFeeds).to(beNil())
                    }
                }

                context("when the network is not reachable") {
                    beforeEach {
                        reachable.hasNetworkConnectivity = false

                        didCallCallback = false
                        callbackErrors = []
                        subject.updateFeeds {feeds, errors in
                            didCallCallback = true
                            callbackErrors = errors
                        }
                    }

                    it("should not make any network requests") {
                        expect(updateUseCase.updateFeedsCallCount) == 0
                    }

                    it("should call the completion handler without an error") {
                        expect(didCallCallback) == true
                        expect(callbackErrors).to(equal([]))
                    }

                    it("should not inform any subscribers") {
                        expect(dataSubscriber.updatedFeeds).to(beNil())
                    }
                }

                context("when there are feeds in the data store") {
                    beforeEach {
                        didCallCallback = false
                        callbackErrors = []
                        subject.updateFeeds {feeds, errors in
                            didCallCallback = true
                            callbackErrors = errors
                        }
                    }

                    it("makes a feeds update for every feed in the data store w/ a url") {
                        expect(updateUseCase.updateFeedsCallCount) == 1
                        guard updateUseCase.updateFeedsCallCount == 1 else { return }
                        let args = updateUseCase.updateFeedsArgsForCall(0)
                        expect(args.0) == [feed1, feed2]
                        expect(args.1 as? [FakeDataSubscriber]) == [dataSubscriber]
                    }

                    context("trying to update feeds while a request is still in progress") {
                        var didCallUpdateCallback = false

                        beforeEach {
                            subject.updateFeeds {feeds, errors in
                                didCallUpdateCallback = true
                            }
                        }
                        it("should not make any update requests") {
                            expect(updateUseCase.updateFeedsCallCount) == 1
                        }

                        it("should not immediately call the callback") {
                            expect(didCallUpdateCallback) == false
                        }

                        context("when the original update request finishes") {
                            beforeEach {
                                mainQueue.runSynchronously = true
                                updateFeedsPromise.resolve(.success())
                            }

                            it("should call both completion handlers") {
                                expect(didCallCallback) == true
                                expect(callbackErrors).to(equal([]))
                                expect(didCallUpdateCallback) == true
                            }
                        }
                    }

                    context("when the update request succeeds") {
                        beforeEach {
                            mainQueue.runSynchronously = true
                            updateFeedsPromise.resolve(.success())
                        }

                        it("should call the completion handler without an error") {
                            expect(didCallCallback) == true
                            expect(callbackErrors).to(equal([]))
                        }

                        it("should inform any subscribers") {
                            expect(dataSubscriber.updatedFeeds).toNot(beNil())
                        }
                    }

                    context("when the update request fails") {
                        beforeEach {
                            mainQueue.runSynchronously = true
                            updateFeedsPromise.resolve(.failure(.unknown))
                        }

                        it("should inform subscribers that we updated our datastore for that feed") {
                            expect(dataSubscriber.updatedFeeds) == []
                        }

                        it("should call the completion handler without an error") {
                            expect(didCallCallback) == true
                            expect(callbackErrors) == [NSError(domain: "TethysError",
                                                               code: 0,
                                                               userInfo: [NSLocalizedDescriptionKey: TethysError.unknown.localizedDescription])]
                        }
                    }
                }
            }
        }
    }
}
