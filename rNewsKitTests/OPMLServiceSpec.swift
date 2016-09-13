import Quick
import Nimble
import CoreData
import Ra
import Lepton
@testable import rNewsKit

class OPMLServiceSpec: QuickSpec {
    override func spec() {
        var subject: OPMLService!

        var dataRepository: FakeDefaultDatabaseUseCase!
        var importQueue: FakeOperationQueue!
        var mainQueue: FakeOperationQueue!

        var dataServiceFactory: FakeDataServiceFactory!
        var dataService: InMemoryDataService!

        beforeEach {
            importQueue = FakeOperationQueue()
            importQueue.runSynchronously = true

            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true

            dataService = InMemoryDataService(mainQueue: mainQueue, searchIndex: FakeSearchIndex())

            dataServiceFactory = FakeDataServiceFactory()
            dataServiceFactory.currentDataService = dataService

            let accountRepository = FakeAccountRepository()
            accountRepository.backendRepositoryReturns(nil)

            dataRepository = FakeDefaultDatabaseUseCase(
                mainQueue: mainQueue,
                reachable: nil,
                dataServiceFactory: dataServiceFactory,
                updateUseCase: FakeUpdateUseCase(),
                databaseMigrator: FakeDatabaseMigrator(),
                accountRepository: accountRepository
            )

            let injector = Injector()
            injector.bind(string: kMainQueue, toInstance: mainQueue)
            injector.bind(string: kBackgroundQueue, toInstance: importQueue)
            injector.bind(kind: DefaultDatabaseUseCase.self, toInstance: dataRepository)

            subject = OPMLService(injector: injector)
        }

        describe("Importing OPML Files") {
            var feeds: [Feed] = []
            beforeEach {
                let opmlUrl = Bundle(for: self.classForCoder).url(forResource: "test", withExtension: "opml")!

                subject.importOPML(opmlUrl) {otherFeeds in
                    feeds = otherFeeds
                }
            }

            it("makes a request to the datarepository for the list of all feeds") {
                expect(dataRepository.feedsPromises.count) == 1
            }

            context("when the feeds promise succeeds") {
                beforeEach {
                    let previouslyImportedFeed = Feed(title: "imported",
                        url: URL(string: "http://example.com/previouslyImportedFeed")!, summary: "",
                        tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    dataRepository.feedsPromises.first?.resolve(.success([previouslyImportedFeed]))
                }

                it("tells the data repository to update the feeds") {
                    expect(dataRepository.didUpdateFeeds) == true
                }

                describe("when the data repository finishes") {
                    beforeEach {
                        dataRepository.updateFeedsCompletion(dataService.feeds, [])
                    }

                    it("returns a list of feeds imported") {
                        expect(feeds.count).to(equal(2))
                        guard feeds.count == 2 else {
                            return
                        }
                        feeds.sort { $0.title < $1.title }
                        let first = feeds[0]
                        expect(first.url).to(equal(URL(string: "http://example.com/feedWithTag")))

                        let second = feeds[1]
                        expect(second.url).to(equal(URL(string: "http://example.com/feedWithTitle")))
                    }
                }
            }

            context("when the feeds promise fails") {
                // TODO: Implement case when feeds promise fails
            }
        }

        describe("Writing OPML Files") {
            beforeEach {
                subject.writeOPML()
            }

            afterEach {
                let fileManager = FileManager.default
                let file = documentsDirectory() + "/rnews.opml"
                let _ = try? fileManager.removeItem(atPath: file)
            }

            it("makes a request to the datarepository for the list of all feeds") {
                expect(dataRepository.feedsPromises.count) == 1
            }

            context("when the feeds promise succeeds") {
                beforeEach {
                    let feed1 = Feed(title: "a", url: URL(string: "http://example.com/feed")!, summary: "",
                        tags: ["a", "b", "c"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    let feed3 = Feed(title: "e", url: URL(string: "http://example.com/otherfeed")!, summary: "",
                        tags: ["dad"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    dataRepository.feedsPromises.first?.resolve(.success([feed1, feed3]))
                }

                it("should write an OPML file to ~/Documents/rnews.opml") {
                    let fileManager = FileManager.default
                    let file = documentsDirectory() + "/rnews.opml"
                    expect(fileManager.fileExists(atPath: file)) == true

                    let text = (try? String(contentsOfFile: file, encoding: String.Encoding.utf8)) ?? ""

                    let parser = Lepton.Parser(text: text)

                    var testItems: [Lepton.Item] = []

                    _ = parser.success {items in
                        testItems = items
                        expect(items.count).to(equal(2))
                        if (items.count != 2) {
                            return
                        }
                        let a = items[0]
                        expect(a.title).to(equal("a"))
                        expect(a.tags).to(equal(["a", "b", "c"]))
                        let c = items[1]
                        expect(c.title).to(equal("e"))
                        expect(c.tags).to(equal(["dad"]))
                    }
                    
                    parser.main()
                    
                    expect(testItems).toNot(beEmpty())
                }
            }

            context("when the feeds promise fails") {
                // TODO: Implement case when feeds promise fails
            }
        }

        describe("When feeds change") {
            beforeEach {
                for subscriber in dataRepository.subscribers {
                    subscriber.didUpdateFeeds([])
                }
            }

            afterEach {
                let fileManager = FileManager.default
                let file = documentsDirectory() + "/rnews.opml"
                let _ = try? fileManager.removeItem(atPath: file)
            }

            it("makes a request to the datarepository for the list of all feeds") {
                expect(dataRepository.feedsPromises.count) == 1
            }

            context("when the feeds promise succeeds") {
                beforeEach {
                    let feed1 = Feed(title: "a", url: URL(string: "http://example.com/feed")!, summary: "",
                        tags: ["a", "b", "c"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    let feed3 = Feed(title: "e", url: URL(string: "http://example.com/otherfeed")!, summary: "",
                        tags: ["dad"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                    dataRepository.feedsPromises.first?.resolve(.success([feed1, feed3]))
                }

                it("should write an OPML file to ~/Documents/rnews.opml") {
                    let fileManager = FileManager.default
                    let file = documentsDirectory() + "/rnews.opml"
                    expect(fileManager.fileExists(atPath: file)) == true

                    guard let text = try? String(contentsOfFile: file, encoding: String.Encoding.utf8) else { return }

                    let parser = Lepton.Parser(text: text)

                    var testItems: [Lepton.Item] = []

                    _ = parser.success {items in
                        testItems = items
                        expect(items.count).to(equal(2))
                        if (items.count != 2) {
                            return
                        }
                        let a = items[0]
                        expect(a.title).to(equal("a"))
                        expect(a.tags).to(equal(["a", "b", "c"]))
                        let c = items[1]
                        expect(c.title).to(equal("e"))
                        expect(c.tags).to(equal(["dad"]))
                    }
                    
                    parser.main()
                    
                    expect(testItems).toNot(beEmpty())
                }
            }

            context("when the feeds promise fails") {
                beforeEach {
                    dataRepository.feedsPromises.first?.resolve(.failure(.unknown))
                }

                it("doesn't write anything to disk") {
                    let fileManager = FileManager.default
                    let file = documentsDirectory() + "/rnews.opml"
                    expect(fileManager.fileExists(atPath: file)) == false
                }
            }
        }
    }
}
