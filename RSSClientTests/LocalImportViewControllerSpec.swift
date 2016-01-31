import Quick
import Nimble
import Ra
import Muon
import rNews
import rNewsKit

private func createOPMLWithFeeds(feeds: [(url: String, title: String)], location: String) {
    var opml = "<opml><body>"
    for feed in feeds {
        opml += "<outline xmlURL=\"\(feed.url)\" title=\"\(feed.title)\" type=\"rss\"/>"
    }
    opml += "</body></opml>"

    let path = documentsDirectory().stringByAppendingPathComponent(location)
    do {
        try opml.writeToFile(path, atomically: true, encoding: NSUTF8StringEncoding)
    } catch _ {
    }
}

private func deleteAtLocation(location: String) {
    let path = documentsDirectory().stringByAppendingPathComponent(location)
    do {
        try NSFileManager.defaultManager().removeItemAtPath(path)
    } catch _ {
    }
}

private func createFeed(feed: (url: String, title: String, articles: [String]), location: String) {
    var str = "<rss><channel><title>\(feed.title)</title><link>\(feed.url)</link>"
    for article in feed.articles {
        str += "<item><title>\(article)</title></item>"
    }
    str += "</channel></rss>"

    let path = documentsDirectory().stringByAppendingPathComponent(location)
    do {
        try str.writeToFile(path, atomically: true, encoding: NSUTF8StringEncoding)
    } catch _ {
    }
}

class LocalImportViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: LocalImportViewController! = nil
        var injector: Ra.Injector! = nil

        var navigationController: UINavigationController! = nil

        var tableView: UITableView! = nil

        var dataRepository: FakeDataRepository! = nil
        var opmlService: FakeOPMLService! = nil
        var mainQueue: FakeOperationQueue! = nil
        var backgroundQueue: FakeOperationQueue! = nil
        var themeRepository: FakeThemeRepository! = nil
        var fileManager: FakeFileManager! = nil

        beforeEach {
            injector = Ra.Injector(module: SpecInjectorModule())

            dataRepository = FakeDataRepository()
            injector.bind(FeedRepository.self, toInstance: dataRepository)

            opmlService = FakeOPMLService()
            injector.bind(OPMLService.self, toInstance: opmlService)

            mainQueue = injector.create(kMainQueue) as! FakeOperationQueue
            mainQueue.runSynchronously = true

            backgroundQueue = injector.create(kBackgroundQueue) as! FakeOperationQueue
            backgroundQueue.runSynchronously = true

            themeRepository = FakeThemeRepository()
            injector.bind(ThemeRepository.self, toInstance: themeRepository)

            fileManager = FakeFileManager()
            fileManager.contentsOfDirectories[documentsDirectory() as String] = []
            injector.bind(NSFileManager.self, toInstance: fileManager)

            subject = injector.create(LocalImportViewController)!

            navigationController = UINavigationController(rootViewController: subject)

            expect(subject.view).toNot(beNil())
            tableView = subject.tableViewController.tableView
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("should update the tableView") {
                expect(subject.tableViewController.tableView.backgroundColor).to(equal(themeRepository.backgroundColor))
                expect(subject.tableViewController.tableView.separatorColor).to(equal(themeRepository.textColor))
            }

            it("should update the scroll indicator style") {
                expect(subject.tableViewController.tableView.indicatorStyle).to(equal(themeRepository.scrollIndicatorStyle))
            }

            it("should update the navigation bar background") {
                expect(navigationController.navigationBar.barStyle).to(equal(themeRepository.barStyle))
            }
        }

        it("should have 2 sections") {
            expect(subject.numberOfSectionsInTableView(tableView)).to(equal(2))
        }

        it("should start out with 0 rows in each section") {
            expect(subject.tableView(tableView, numberOfRowsInSection: 0)).to(equal(0))
            expect(subject.tableView(tableView, numberOfRowsInSection: 1)).to(equal(0))
        }

        it("should list OPML first, then RSS feeds") {
            let opmlHeader = subject.tableView(tableView, titleForHeaderInSection: 0)
            let feedHeader = subject.tableView(tableView, titleForHeaderInSection: 1)
            expect(opmlHeader).to(beNil())
            expect(feedHeader).to(beNil())
        }

        sharedExamples("showing explanation message") {
            it("shows the explanationLabel") {
                expect(subject.explanationLabel.superview).toNot(beNil())
            }

            context("when feeds are added") {
                let opmlFeeds : [(url: String, title: String)] = [("http://example.com/feed1", "feed1"), ("http://example.com/feed2", "feed2")]
                let rssFeed : (url: String, title: String, articles: [String]) = ("http://example.com/feed", "feed", ["article1", "article2"])

                beforeEach {
                    createOPMLWithFeeds(opmlFeeds, location: "rnews.opml")
                    createFeed(rssFeed, location: "feed")
                    fileManager.contentsOfDirectories[documentsDirectory() as String] = ["rnews.opml", "feed"]
                    subject.reloadItems()
                }

                afterEach {
                    deleteAtLocation("opml")
                    deleteAtLocation("feed")
                }

                it("removes the explanationLabel from the view hierarchy") {
                    expect(subject.explanationLabel.superview).to(beNil())
                }
            }
        }

        context("when there are no files to list") {
            beforeEach {
                fileManager.contentsOfDirectories[documentsDirectory() as String] = []
                subject.reloadItems()
            }
            itBehavesLike("showing explanation message")
        }

        context("when there is only the rnews.opml file to list") {
            beforeEach {
                fileManager.contentsOfDirectories[documentsDirectory() as String] = ["rnews.opml"]
                subject.reloadItems()
            }
            itBehavesLike("showing explanation message")
        }

        context("when there are multiple files to list") {
            let opmlFeeds : [(url: String, title: String)] = [("http://example.com/feed1", "feed1"), ("http://example.com/feed2", "feed2")]
            let rssFeed : (url: String, title: String, articles: [String]) = ("http://example.com/feed", "feed", ["article1", "article2"])

            beforeEach {
                createOPMLWithFeeds(opmlFeeds, location: "rnews.opml")
                createFeed(rssFeed, location: "feed")
                fileManager.contentsOfDirectories[documentsDirectory() as String] = ["rnews.opml", "feed"]
                subject.reloadItems()
            }

            afterEach {
                deleteAtLocation("opml")
                deleteAtLocation("feed")
            }

            it("does not show the explanationLabel") {
                expect(subject.explanationLabel.superview).to(beNil())
            }
        }

        describe("reloading objects") {
            let opmlFeeds : [(url: String, title: String)] = [("http://example.com/feed1", "feed1"), ("http://example.com/feed2", "feed2")]
            let rssFeed : (url: String, title: String, articles: [String]) = ("http://example.com/feed", "feed", ["article1", "article2"])

            beforeEach {
                createOPMLWithFeeds(opmlFeeds, location: "rnews.opml")
                createFeed(rssFeed, location: "feed")

                fileManager.contentsOfDirectories[documentsDirectory() as String] = ["rnews.opml", "feed"]

                subject.reloadItems()
            }

            afterEach {
                deleteAtLocation("opml")
                deleteAtLocation("feed")
            }

            it("should with 1 row in each section") {
                expect(subject.tableView(tableView, numberOfRowsInSection: 0)).to(equal(1))
                expect(subject.tableView(tableView, numberOfRowsInSection: 1)).to(equal(1))
            }

            it("should now label sections") {
                let opmlHeader = subject.tableView(tableView, titleForHeaderInSection: 0)
                let feedHeader = subject.tableView(tableView, titleForHeaderInSection: 1)
                expect(opmlHeader).to(equal("Feed Lists"))
                expect(feedHeader).to(equal("Individual Feeds"))
            }

            describe("the cell in section 0") {
                var cell : UITableViewCell? = nil
                let indexPath = NSIndexPath(forRow: 0, inSection: 0)
                beforeEach {
                    expect(subject.numberOfSectionsInTableView(tableView)).to(beGreaterThan(indexPath.section))
                    if subject.numberOfSectionsInTableView(tableView) > indexPath.section {
                        expect(subject.tableView(tableView, numberOfRowsInSection: indexPath.section)).to(beGreaterThan(indexPath.row))
                        if subject.tableView(tableView, numberOfRowsInSection: indexPath.section) > indexPath.row {
                            cell = subject.tableView(tableView, cellForRowAtIndexPath: indexPath)
                        }
                    }
                }

                it("should be named for the file name") {
                    expect(cell?.textLabel?.text).to(equal("rnews.opml"))
                }

                it("should list how many feeds are in this opml file") {
                    expect(cell?.detailTextLabel?.text).to(equal("2 feeds"))
                }

                describe("selecting it") {
                    beforeEach {
                        subject.tableView(tableView, didSelectRowAtIndexPath: indexPath)
                    }

                    it("should present an activity indicator") {
                        var indicator : ActivityIndicator? = nil
                        for view in subject.view.subviews {
                            if view is ActivityIndicator {
                                indicator = view as? ActivityIndicator
                                break
                            }
                        }
                        expect(indicator).toNot(beNil())
                        if let activityIndicator = indicator {
                            expect(activityIndicator.message).to(equal("Importing feeds"))
                        }
                    }

                    it("should import the feeds") {
                        let expectedLocation = documentsDirectory().stringByAppendingPathComponent("rnews.opml")
                        expect(opmlService.importOPMLURL).to(equal(NSURL(string: "file://" + expectedLocation)))
                    }

                    describe("when it's done importing the feeds") {
                        beforeEach {
                            opmlService.importOPMLCompletion([])
                        }

                        it("should import the feed") {
                            expect(dataRepository.didUpdateFeeds).to(beTruthy())
                        }

                        describe("when it's done updating the feeds") {
                            beforeEach {
                                dataRepository.updateFeedsCompletion([], [])
                            }

                            it("should remove the activity indicator") {
                                var indicator : ActivityIndicator? = nil
                                for view in subject.view.subviews {
                                    if view is ActivityIndicator {
                                        indicator = view as? ActivityIndicator
                                        break
                                    }
                                }
                                expect(indicator).to(beNil())
                            }
                        }
                    }
                }
            }

            describe("the cell in section 1") {
                var cell : UITableViewCell! = nil
                let indexPath = NSIndexPath(forRow: 0, inSection: 1)
                beforeEach {
                    cell = subject.tableView(tableView, cellForRowAtIndexPath: indexPath)
                }

                it("should be named for the file name") {
                    expect(cell.textLabel?.text).to(equal("feed"))
                }

                it("should list how many articles are in this feed") {
                    expect(cell.detailTextLabel?.text).to(equal("2 articles"))
                }

                describe("selecting it") {
                    beforeEach {
                        subject.tableView(tableView, didSelectRowAtIndexPath: indexPath)
                    }

                    it("should present an activity indicator") {
                        var indicator : ActivityIndicator? = nil
                        for view in subject.view.subviews {
                            if view is ActivityIndicator {
                                indicator = view as? ActivityIndicator
                                break
                            }
                        }
                        expect(indicator).toNot(beNil())
                        if let activityIndicator = indicator {
                            expect(activityIndicator.message).to(equal("Importing feed"))
                        }
                    }

                    it("should create a feed") {
                        expect(dataRepository.didCreateFeed).to(beTruthy())
                    }

                    describe("after the feed is created") {
                        beforeEach {
                            let feed = rNewsKit.Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                            dataRepository.newFeedCallback(feed)
                        }

                        it("should import the feed") {
                            expect(dataRepository.didUpdateFeeds).to(beTruthy())
                        }

                        describe("when it's done importing the feeds") {
                            beforeEach {
                                dataRepository.updateFeedsCompletion([], [])
                            }

                            it("should remove the activity indicator") {
                                expect(subject.view.subviews).toNot(contain(ActivityIndicator.self))
                            }
                        }
                    }
                }
            }
        }
    }
}
