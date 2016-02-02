import Quick
import Nimble
import Ra
import rNews
import rNewsKit

private var navController: UINavigationController! = nil
private var feedRepository: FakeFeedRepository! = nil
private var rootViewController: UIViewController! = nil


class FindFeedViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: FindFeedViewController! = nil


        var injector: Ra.Injector! = nil
        var webView: FakeWebView! = nil
        var feedFinder: FakeFeedFinder! = nil
        var urlSession: FakeURLSession! = nil

        var mainQueue: FakeOperationQueue! = nil
        var backgroundQueue: FakeOperationQueue! = nil

        var opmlService: FakeOPMLService! = nil

        var themeRepository: FakeThemeRepository! = nil

        beforeEach {
            injector = Ra.Injector(module: SpecInjectorModule())

            feedFinder = FakeFeedFinder()
            injector.bind(FeedFinder.self, toInstance: feedFinder)

            feedRepository = FakeFeedRepository()
            injector.bind(FeedRepository.self, toInstance: feedRepository)

            urlSession = FakeURLSession()
            injector.bind(NSURLSession.self, toInstance: urlSession)

            mainQueue = FakeOperationQueue()
            injector.bind(kMainQueue, toInstance: mainQueue)

            backgroundQueue = FakeOperationQueue()
            injector.bind(kBackgroundQueue, toInstance: backgroundQueue)

            opmlService = FakeOPMLService()
            injector.bind(OPMLService.self, toInstance: opmlService)

            themeRepository = FakeThemeRepository()
            injector.bind(ThemeRepository.self, toInstance: themeRepository)

            subject = injector.create(FindFeedViewController)!
            webView = FakeWebView()
            subject.webContent = webView

            navController = UINavigationController(rootViewController: subject)

            expect(subject.view).toNot(beNil())
        }

        afterEach {
            objc_removeAssociatedObjects(subject)
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("should update the navigation bar background") {
                expect(subject.navigationController?.navigationBar.barStyle).to(equal(themeRepository.barStyle))
            }

            it("should update the toolbar") {
                expect(subject.navigationController?.toolbar.barStyle).to(equal(themeRepository.barStyle))
            }

            it("should update the webView's background color") {
                expect(subject.webContent.backgroundColor).to(equal(themeRepository.backgroundColor))
            }

            it("should update the scroll indicator style") {
                expect(subject.webContent.scrollView.indicatorStyle).to(equal(themeRepository.scrollIndicatorStyle))
            }
        }

        describe("Looking up feeds on the interwebs") {
            beforeEach {
                subject.navField.text = "example.com"
                subject.textFieldShouldReturn(subject.navField)
            }

            it("should auto-prepend 'http://' if it's not already there") {
                expect(subject.navField.text).to(equal("http://example.com"))
            }

            it("should navigate the webview that url") {
                expect(webView.lastRequestLoaded?.URL).to(equal(NSURL(string: "http://example.com")))
            }
        }

        describe("WKWebView and Delegates") {
            beforeEach {
                webView.fakeUrl = NSURL(string: "https://example.com/feed.xml")
                subject.webView(subject.webContent, didStartProvisionalNavigation: nil)
            }

            let showRootController: (Void) -> (Void) = {
                rootViewController = UIViewController()

                rootViewController.presentViewController(navController, animated: false, completion: nil)
                expect(rootViewController.presentedViewController).toNot(beNil())
            }

            sharedExamples("importing a feed") { (sharedContext: SharedExampleContext) in
                var url: NSURL!

                beforeEach {
                    url = (sharedContext()["url"] as? NSURL) ?? NSURL(string: "https://example.com/feed.xml")!
                }

                it("should create a new feed") {
                    expect(feedRepository.didCreateFeed).to(beTruthy())
                }

                it("should show an indicator that we're doing things") {
                    let indicator = subject.view.subviews.filter {
                        return $0.isKindOfClass(ActivityIndicator.classForCoder())
                        }.first as? ActivityIndicator
                    expect(indicator?.message).to(equal("Loading feed at \(url.absoluteString)"))
                }

                describe("when the feed is created") {
                    var feed: Feed! = nil
                    beforeEach {
                        feed = Feed(title: "", url: NSURL(string: ""), summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                        feedRepository.newFeedCallback(feed)
                    }

                    it("should save the new feed") {
                        let feed = Feed(title: "", url: url, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                        expect(feedRepository.lastSavedFeed).to(equal(feed))
                    }

                    it("should try to update feeds") {
                        expect(feedRepository.didUpdateFeed).to(beTruthy())
                    }

                    describe("when the feeds update") {
                        beforeEach {
                            feed = Feed(title: "", url: url, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                            feedRepository.updateSingleFeedCallback(feed, nil)
                        }

                        it("should remove the indicator") {
                            let indicator = navController.view.subviews.filter {
                                return $0.isKindOfClass(ActivityIndicator.classForCoder())
                                }.first
                            expect(indicator).to(beNil())
                        }

                        it("should dismiss itself") {
                            expect(rootViewController.presentedViewController).to(beNil())
                        }
                    }
                }
            }

            it("should show the loadingBar") {
                expect(subject.loadingBar.hidden).to(beFalsy())
                expect(subject.loadingBar.progress).to(beCloseTo(0))
            }

            it("should disable the addFeedButton") {
                expect(subject.addFeedButton.enabled).to(beFalsy())
            }

            it("should make a separate request to that url") {
                expect(urlSession.lastURL).to(equal(NSURL(string: "https://example.com/feed.xml")))
            }

            context("when that urlSession request succeeds with an rss file") {
                beforeEach {
                    let bundle = NSBundle(forClass: self.classForCoder)
                    let data = NSData(contentsOfFile: bundle.pathForResource("feed", ofType: "rss")!)
                    urlSession.lastCompletionHandler(data, nil, nil)
                }

                it("should add two background operations") {
                    expect(backgroundQueue.operationCount).to(equal(2))
                }

                describe("when the background ops finish") {
                    beforeEach {
                        showRootController()
                        backgroundQueue.runNextOperation()
                        backgroundQueue.runNextOperation()
                        mainQueue.runNextOperation()
                    }

                    it("should present an alert") {
                        expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                        if let alert = subject.presentedViewController as? UIAlertController {
                            expect(alert.title).to(equal("Feed Detected"))
                            expect(alert.message).to(equal("Import Iotlist?"))

                            expect(alert.actions.count).to(equal(2))
                            if let dontsave = alert.actions.first {
                                expect(dontsave.title).to(equal("Don't Import"))
                            }
                            if let save = alert.actions.last {
                                expect(save.title).to(equal("Import"))
                            }
                        }
                    }

                    describe("tapping 'Don't Import'") {
                        beforeEach {
                            if let alert = subject.presentedViewController as? UIAlertController,
                                let action = alert.actions.first {
                                    action.handler()(action)
                            }
                        }

                        it("should dismiss the alert") {
                            expect(subject.presentedViewController).to(beNil())
                        }
                    }

                    describe("tapping 'Import'") {
                        beforeEach {
                            if let alert = subject.presentedViewController as? UIAlertController,
                                let action = alert.actions.last {
                                    action.handler()(action)
                            }
                        }

                        it("should dismiss the alert") {
                            expect(subject.presentedViewController).to(beNil())
                        }

                        itBehavesLike("importing a feed")
                    }
                }
            }

            context("when that urlSession request succeeds with an opml file") {
                beforeEach {
                    let bundle = NSBundle(forClass: self.classForCoder)
                    let data = NSData(contentsOfFile: bundle.pathForResource("test", ofType: "opml")!)
                    urlSession.lastCompletionHandler(data, nil, nil)
                }

                it("should add two background operations") {
                    expect(backgroundQueue.operationCount).to(equal(2))
                }

                describe("when the background ops finish") {
                    beforeEach {
                        showRootController()
                        backgroundQueue.runNextOperation()
                        backgroundQueue.runNextOperation()
                        mainQueue.runNextOperation()
                    }

                    it("should present an alert") {
                        expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                        if let alert = subject.presentedViewController as? UIAlertController {
                            expect(alert.title).to(equal("Feed List Detected"))
                            expect(alert.message).to(equal("Import?"))

                            expect(alert.actions.count).to(equal(2))
                            if let dontsave = alert.actions.first {
                                expect(dontsave.title).to(equal("Don't Import"))
                            }
                            if let save = alert.actions.last {
                                expect(save.title).to(equal("Import"))
                            }
                        }
                    }

                    describe("tapping 'Don't Import'") {
                        beforeEach {
                            if let alert = subject.presentedViewController as? UIAlertController,
                                let action = alert.actions.first {
                                    action.handler()(action)
                            }
                        }

                        it("should dismiss the alert") {
                            expect(subject.presentedViewController).to(beNil())
                        }
                    }

                    describe("tapping 'Import'") {
                        beforeEach {
                            if let alert = subject.presentedViewController as? UIAlertController,
                                let action = alert.actions.last {
                                    action.handler()(action)
                            }
                        }

                        it("should dismiss the alert") {
                            expect(subject.presentedViewController).to(beNil())
                        }

                        it("should show an indicator that we're doing things") {
                            let indicator = subject.view.subviews.filter {
                                return $0.isKindOfClass(ActivityIndicator.classForCoder())
                            }.first as? ActivityIndicator
                            expect(indicator?.message).to(equal("Loading feed list at https://example.com/feed.xml"))
                        }

                        it("should import the opml file") {
                            expect(opmlService.importOPMLURL).to(equal(NSURL(string: "https://example.com/feed.xml")))
                        }

                        describe("when the opml file is imported") {
                            beforeEach {
                                opmlService.importOPMLCompletion([])
                            }

                            it("should remove the indicator") {
                                let indicator = subject.view.subviews.filter {
                                    return $0.isKindOfClass(ActivityIndicator.classForCoder())
                                }.first
                                expect(indicator).to(beNil())
                            }

                            it("should dismiss itself") {
                                expect(rootViewController.presentedViewController).to(beNil())
                            }
                        }
                    }
                }
            }

            context("when that urlSession request succeeds with anything else") {
                beforeEach {
                    let data = "hello world!".dataUsingEncoding(NSUTF8StringEncoding)
                    urlSession.lastCompletionHandler(data, nil, nil)
                }

                it("should add two background operations") {
                    expect(backgroundQueue.operationCount).to(equal(2))
                }

                describe("when the background ops finish") {
                    beforeEach {
                        backgroundQueue.runNextOperation()
                        backgroundQueue.runNextOperation()
                    }

                    it("should do nothing") {
                        expect(mainQueue.operationCount).to(equal(0))
                        expect(subject.presentedViewController).to(beNil())
                    }
                }
            }

            context("when that urlSession request fails") {
                beforeEach {
                    urlSession.lastCompletionHandler(nil, nil, NSError(domain: "", code: 0, userInfo: nil))
                }

                it("should do nothing") {
                    expect(backgroundQueue.operationCount).to(equal(0))
                }
            }

            describe("Failing to load the page") {
                let err = NSError(domain: "", code: 0, userInfo: [:])
                context("before loading the page (network error)") {
                    beforeEach {
                        subject.webView(subject.webContent, didFailProvisionalNavigation: nil, withError: err)
                    }

                    it("should hide the webview") {
                        expect(subject.loadingBar.hidden).to(beTruthy())
                    }
                }

                context("trying to load the content (html rendering error)") {
                    beforeEach {
                        subject.webView(subject.webContent, didFailNavigation: nil, withError: err)
                    }

                    it("should hide the webview") {
                        expect(subject.loadingBar.hidden).to(beTruthy())
                    }
                }
            }

            describe("successfully loading a page") {
                beforeEach {
                    subject.webView(subject.webContent, didFinishNavigation: nil)
                }

                it("should hide the loadingBar") {
                    expect(subject.loadingBar.hidden).to(beTruthy())
                }

                it("should allow the user to reload the page") {
                    expect(subject.navigationItem.rightBarButtonItem).to(equal(subject.reload))
                }

                it("should look for a not-already imported feed linked from the webpage") {
                    expect(feedFinder.didAttemptToFindFeed).to(beTruthy())
                }

                context("when a single feed is found") {
                    beforeEach {
                        feedFinder.findFeedCallback(["https://example.com/feed.xml"])
                    }

                    it("should enable the addFeedButton") {
                        expect(subject.addFeedButton.enabled).to(beTruthy())
                    }

                    describe("tapping on the addFeedButton") {
                        beforeEach {
                            showRootController()
                            subject.addFeedButton.tap()
                        }

                        itBehavesLike("importing a feed")
                    }
                }

                context("when multiple feeds are found") {
                    beforeEach {
                        feedFinder.findFeedCallback(["https://example.com/feed.xml", "https://example.com/feed2.xml"])
                    }

                    it("should enable the addFeedButton") {
                        expect(subject.addFeedButton.enabled).to(beTruthy())
                    }

                    describe("tapping on the addFeedButton") {
                        beforeEach {
                            showRootController()
                            subject.addFeedButton.tap()
                        }

                        it("should bring up a list of available feeds to import") {
                            expect(subject.presentedViewController).to(beAKindOf(UIAlertController.self))
                            if let alertController = subject.presentedViewController as? UIAlertController {
                                expect(alertController.preferredStyle) == UIAlertControllerStyle.ActionSheet
                                expect(alertController.actions.count) == 3

                                guard alertController.actions.count == 3 else { return }

                                let firstAction = alertController.actions[0]
                                expect(firstAction.title) == "feed.xml"

                                let secondAction = alertController.actions[1]
                                expect(secondAction.title) == "feed2.xml"

                                let thirdAction = alertController.actions[2]
                                expect(thirdAction.title) == "Cancel"
                            }
                        }

                        context("tapping on one of the feed actions") {
                            beforeEach {
                                let actions = (subject.presentedViewController as? UIAlertController)?.actions ?? []
                                if actions.count >= 3 {
                                    let action = actions[1]
                                    action.handler()(action)
                                } else {
                                    fail("grr")
                                }
                            }

                            itBehavesLike("importing a feed") {
                                return ["url": NSURL(string: "https://example.com/feed2.xml")!]
                            }
                        }
                    }
                }

                context("when no feeds are found") {
                    beforeEach {
                        feedFinder.findFeedCallback([])
                    }

                    it("should do nothing") {
                        expect(subject.addFeedButton.enabled).to(beFalsy())
                    }
                }
            }
        }
    }
}
