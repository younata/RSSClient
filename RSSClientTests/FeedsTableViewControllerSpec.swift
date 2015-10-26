import Quick
import Nimble
import Ra
import rNews
import BreakOutToRefresh
import rNewsKit

class FeedsTableViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: FeedsTableViewController! = nil
        var injector : Injector? = nil
        var dataReadWriter: FakeDataReadWriter! = nil
        var navigationController: UINavigationController! = nil
        var themeRepository: FakeThemeRepository! = nil

        var feed1: Feed! = nil
        var feed2: Feed! = nil

        var feeds: [Feed] = []

        beforeEach {
            injector = Injector()

            dataReadWriter = FakeDataReadWriter()
            injector?.bind(DataRetriever.self, to: dataReadWriter)
            injector?.bind(DataWriter.self, to: dataReadWriter)

            themeRepository = FakeThemeRepository()
            injector?.bind(ThemeRepository.self, to: themeRepository)

            injector?.bind(kBackgroundQueue, to: FakeOperationQueue())

            subject = injector?.create(FeedsTableViewController.self) as? FeedsTableViewController

            navigationController = UINavigationController(rootViewController: subject)

            feed1 = Feed(title: "a", url: NSURL(string: "http://example.com/feed"), summary: "", query: nil,
                tags: ["a", "b", "c"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
            feed2 = Feed(title: "d", url: nil, summary: "", query: "article.read == false;", tags: [],
                waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            feeds = [feed1, feed2]

            dataReadWriter.feedsList = feeds

            expect(subject.view).toNot(beNil())
            subject.viewWillAppear(false)
        }

        describe("listening to theme repository updates") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("should update the tableView") {
                expect(subject.tableView.backgroundColor).to(equal(themeRepository.backgroundColor))
                expect(subject.tableView.separatorColor).to(equal(themeRepository.textColor))
            }

            it("should update the navigation bar background") {
                expect(subject.navigationController?.navigationBar.barStyle).to(equal(UIBarStyle.Black))
            }

            it("should update the searchbar bar style") {
                expect(subject.searchBar.barStyle).to(equal(UIBarStyle.Black))
                expect(subject.searchBar.backgroundColor).to(equal(themeRepository.backgroundColor))
            }

            it("should update the drop down menu") {
                expect(subject.dropDownMenu.buttonBackgroundColor).to(equal(themeRepository.tintColor))
                expect(subject.dropDownMenu.backgroundColor).to(equal(themeRepository.backgroundColor.colorWithAlphaComponent(0.5)))
            }

            it("should update the refreshView background color") {
                expect(subject.refreshView.scenebackgroundColor).to(equal(themeRepository.backgroundColor))
            }
        }

        context("when there are no feeds to display") {
            beforeEach {
                feeds = []

                dataReadWriter.feedsList = feeds

                expect(subject.view).toNot(beNil())
                subject.viewWillAppear(false)
            }

            it("should show the onboarding view") {
                expect(subject.onboardingView.superview).toNot(beNil())
            }

            context("when feeds are added") {
                beforeEach {
                    feeds = [feed1, feed2]

                    dataReadWriter.feedsList = feeds
                    subject.searchBar.delegate?.searchBar?(subject.searchBar, textDidChange: "") // just to trigger a reload
                }

                it("should not show the onboarding view") {
                    expect(subject.onboardingView.superview).to(beNil())
                }
            }
        }

        context("when there are feeds to display") {
            beforeEach {
                feeds = [feed1, feed2]

                dataReadWriter.feedsList = feeds

                expect(subject.view).toNot(beNil())
                subject.viewWillAppear(false)
            }

            it("should not show the onboarding view") {
                expect(subject.onboardingView.superview).to(beNil())
            }

            it("should add a subscriber to the dataWriter") {
                expect(dataReadWriter.subscribers).toNot(beEmpty())
            }

            describe("responding to data subscriber (feed) update events") {
                var subscriber: DataSubscriber? = nil
                beforeEach {
                    subscriber = dataReadWriter.subscribers.anyObject as? DataSubscriber
                }

                context("when the feeds start refreshing") {
                    beforeEach {
                        subscriber?.willUpdateFeeds()
                    }

                    it("should unhide the updateBar") {
                        expect(subject.updateBar.hidden).to(beFalsy())
                    }

                    it("should set the updateBar progress to 0") {
                        expect(subject.updateBar.progress).to(equal(0))
                    }

                    context("as progress continues") {
                        beforeEach {
                            subscriber?.didUpdateFeedsProgress(1, total: 2)
                        }

                        it("should set the updateBar progress to progress / total") {
                            expect(subject.updateBar.progress).to(equal(0.5))
                        }

                        context("when it finishes") {
                            beforeEach {
                                subscriber?.didUpdateFeeds([])
                            }

                            it("should hide the updateBar") {
                                expect(subject.updateBar.hidden).to(beTruthy())
                            }
                        }
                    }
                }
            }

            describe("Key Commands") {
                it("can become first responder") {
                    expect(subject.canBecomeFirstResponder()).to(beTruthy())
                }

                it("have a list of key commands") {
                    let keyCommands = subject.keyCommands
                    expect(keyCommands).toNot(beNil())
                    guard let commands = keyCommands else {
                        return
                    }

                    // cmd+f, cmd+i, cmd+shift+i, cmd+opt+i
                    let expectedCommands = [
                        UIKeyCommand(input: "f", modifierFlags: .Command, action: ""),
                        UIKeyCommand(input: "i", modifierFlags: .Command, action: ""),
                        UIKeyCommand(input: "i", modifierFlags: [.Command, .Shift], action: ""),
                        UIKeyCommand(input: "i", modifierFlags: [.Command, .Alternate], action: ""),
                        UIKeyCommand(input: ",", modifierFlags: .Command, action: ""),
                    ]
                    let expectedDiscoverabilityTitles = [
                        "Filter by tags",
                        "Import from web",
                        "Import from local",
                        "Create query feed",
                        "Open settings",
                    ]

                    expect(commands.count).to(equal(expectedCommands.count))
                    for (idx, cmd) in commands.enumerate() {
                        let expectedCmd = expectedCommands[idx]
                        expect(cmd.input).to(equal(expectedCmd.input))
                        expect(cmd.modifierFlags).to(equal(expectedCmd.modifierFlags))

                        if #available(iOS 9.0, *) {
                            let expectedTitle = expectedDiscoverabilityTitles[idx]
                            expect(cmd.discoverabilityTitle).to(equal(expectedTitle))
                        }
                    }
                }
            }

            describe("typing in the searchbar") {
                beforeEach {
                    subject.searchBar.delegate?.searchBar?(subject.searchBar, textDidChange: "a")
                }

                it("should filter feeds down to only those with tags that match the search string") {
                    expect(subject.tableView.numberOfRowsInSection(0)).to(equal(1))

                    if let cell = subject.tableView.visibleCells[0] as? FeedTableCell {
                        expect(cell.feed).to(equal(feeds[0]))
                    }
                }
            }

            describe("tapping the settings button") {
                beforeEach {
                    subject.navigationItem.leftBarButtonItem?.tap()
                }

                it("should present a settings page") {
                    expect(subject.presentedViewController).to(beAnInstanceOf(UINavigationController.self))
                    if let nc = subject.presentedViewController as? UINavigationController {
                        expect(nc.topViewController).to(beAnInstanceOf(SettingsViewController.self))
                    }
                }
            }

            describe("tapping the add feed button") {
                var addButton: UIBarButtonItem! = nil
                var buttons: [UIButton] = []
                beforeEach {
                    addButton = subject.navigationItem.rightBarButtonItems?.first
                    addButton.tap()
                    buttons = subject.dropDownMenu.valueForKey("_buttons") as? [UIButton] ?? []
                    expect(buttons).toNot(beEmpty())
                }

                afterEach {
                    navigationController.popToRootViewControllerAnimated(false)
                    subject.dropDownMenu.closeAnimated(false)
                }

                it("should bring up the dropDownMenu") {
                    expect(subject.dropDownMenu.isOpen).to(beTruthy())
                    let expectedTitles = ["Add from Web", "Add from Local", "Create Query Feed"]
                    let titles: [String] = buttons.map { $0.titleForState(.Normal) ?? "" }
                    expect(titles).to(equal(expectedTitles))
                }

                context("tapping on the add feed button again") {
                    beforeEach {
                        addButton.tap()
                    }

                    it("should close the dropDownMenu") {
                        expect(subject.dropDownMenu.isOpen).to(beFalsy())
                    }
                }

                context("tapping on add from web") {
                    beforeEach {
                        let button = buttons[0]
                        button.sendActionsForControlEvents(UIControlEvents.TouchUpInside)
                        (subject.presentedViewController as? UINavigationController)?.topViewController?.view
                    }

                    it("should close the dropDownMenu") {
                        expect(subject.dropDownMenu.isOpen).to(beFalsy())
                    }

                    it("should present a FindFeedViewController") {
                        expect(subject.presentedViewController).to(beAnInstanceOf(UINavigationController.self))
                        if let nc = subject.presentedViewController as? UINavigationController {
                            expect(nc.topViewController).to(beAnInstanceOf(FindFeedViewController.self))
                        }
                    }
                }

                context("tapping on add from local") {
                    beforeEach {
                        let button = buttons[1]
                        button.sendActionsForControlEvents(UIControlEvents.TouchUpInside)
                    }

                    it("should close the dropDownMenu") {
                        expect(subject.dropDownMenu.isOpen).to(beFalsy())
                    }

                    it("should present a LocalImportViewController") {
                        expect(subject.presentedViewController).to(beAnInstanceOf(UINavigationController.self))
                        if let nc = subject.presentedViewController as? UINavigationController {
                            expect(nc.topViewController).to(beAnInstanceOf(LocalImportViewController.self))
                        }
                    }
                }

                context("tapping on create query feed") {
                    beforeEach {
                        let button = buttons[2]
                        button.sendActionsForControlEvents(UIControlEvents.TouchUpInside)
                    }

                    it("should close the dropDownMenu") {
                        expect(subject.dropDownMenu.isOpen).to(beFalsy())
                    }

                    it("should present a QueryFeedViewController") {
                        expect(subject.presentedViewController).to(beAnInstanceOf(UINavigationController.self))
                        if let nc = subject.presentedViewController as? UINavigationController {
                            expect(nc.topViewController).to(beAnInstanceOf(QueryFeedViewController.self))
                        }
                    }
                }
            }

            describe("pull to refresh") {
                beforeEach {
                    expect(dataReadWriter.didUpdateFeeds).to(beFalsy())
                    subject.refreshView.beginRefreshing()
                    subject.refreshViewDidRefresh(subject.refreshView)
                }

                it("should tell the dataManager to updateFeeds") {
                    expect(dataReadWriter.didUpdateFeeds).to(beTruthy())
                }

                it("should be refreshing") {
                    expect(subject.refreshView.isRefreshing).to(beTruthy())
                }

                context("when the call succeeds") {
                    var feed3: Feed! = nil
                    beforeEach {
                        feed3 = Feed(title: "d", url: nil, summary: "", query: "", tags: [],
                            waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                        dataReadWriter.feedsList = feeds + [feed3]
                        dataReadWriter.updateFeedsCompletion([], [])
                    }

                    it("should end refreshing") {
                        expect(subject.refreshView.isRefreshing).to(beFalsy())
                    }

                    it("should reload the tableView") {
                        expect(subject.tableView.numberOfRowsInSection(0)).to(equal(3)) // cause it was 2
                    }
                }

                context("when the call fails") {
                    var alert: UIAlertController? = nil
                    beforeEach {
                        let error = NSError(domain: "spec", code: 666, userInfo: [NSLocalizedFailureReasonErrorKey: "Bad Connection"])
                        dataReadWriter.updateFeedsCompletion([], [error])
                        alert = subject.presentedViewController as? UIAlertController
                    }

                    it("should end refreshing") {
                        expect(subject.refreshView.isRefreshing).to(beFalsy())
                    }

                    it("should bring up an alert notifying the user") {
                        expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                        if let alert = alert {
                            expect(alert.title).to(equal("Unable to update feeds"))
                            expect(alert.message).to(equal(""))
                        }
                    }

                    it("should dismiss the alert when tapping the single (OK) button") {
                        if let actions = alert?.actions {
                            expect(actions.count).to(equal(1))
                            if let action = actions.first {
                                expect(action.title).to(equal("OK"))
                            }
                        }
                    }
                }
            }

            describe("the tableView") {
                it("should have a row for each feed") {
                    expect(subject.tableView.numberOfRowsInSection(0)).to(equal(feeds.count))
                }

                describe("a cell") {
                    var cell: FeedTableCell! = nil
                    var feed: Feed! = nil

                    context("for a regular feed") {
                        beforeEach {
                            cell = subject.tableView.visibleCells.first as? FeedTableCell
                            feed = feeds[0]

                            expect(cell).to(beAnInstanceOf(FeedTableCell.self))
                        }

                        it("should be configured with the theme repository") {
                            expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                        }

                        it("should be configured with the feed") {
                            expect(cell.feed).to(equal(feed))
                        }

                        describe("tapping on a cell") {
                            beforeEach {
                                let indexPath = NSIndexPath(forRow: 0, inSection: 0)
                                subject.tableView(subject.tableView, didSelectRowAtIndexPath: indexPath)
                            }

                            it("should navigate to an ArticleListViewController for that feed") {
                                expect(navigationController.topViewController).to(beAnInstanceOf(ArticleListController.self))
                                if let articleList = navigationController.topViewController as? ArticleListController {
                                    expect(articleList.feeds).to(equal([feed]))
                                }
                            }
                        }

                        describe("exposing edit actions") {
                            var actions: [UITableViewRowAction] = []
                            var action: UITableViewRowAction! = nil
                            let indexPath = NSIndexPath(forRow: 0, inSection: 0)
                            beforeEach {
                                actions = subject.tableView(subject.tableView, editActionsForRowAtIndexPath: indexPath) ?? []
                            }

                            it("should have 3 actions") {
                                expect(actions.count).to(equal(3))
                            }

                            describe("the first action") {
                                beforeEach {
                                    action = actions[0]
                                }

                                it("should state it deletes the feed") {
                                    expect(action.title).to(equal("Delete"))
                                }

                                describe("tapping it") {
                                    beforeEach {
                                        action.handler()(action, indexPath)
                                    }

                                    it("should delete the feed from the data store") {
                                        expect(dataReadWriter.lastDeletedFeed).to(equal(feed))
                                    }
                                }
                            }

                            describe("the second action") {
                                beforeEach {
                                    action = actions[1]
                                }

                                it("should state it marks all items in the feed as read") {
                                    expect(action.title).to(equal("Mark\nRead"))
                                }

                                describe("tapping it") {
                                    beforeEach {
                                        action.handler()(action, indexPath)
                                    }

                                    it("should mark all articles of that feed as read") {
                                        expect(dataReadWriter.lastFeedMarkedRead).to(equal(feed))
                                    }
                                }
                            }

                            describe("the second action") {
                                beforeEach {
                                    action = actions[2]
                                }

                                it("should state it edits the feed") {
                                    expect(action.title).to(equal("Edit"))
                                }

                                describe("tapping it") {
                                    beforeEach {
                                        action.handler()(action, indexPath)
                                    }
                                    
                                    it("should bring up a feed edit screen") {
                                        expect(navigationController.visibleViewController).to(beAnInstanceOf(UINavigationController.self))
                                        if let nc = navigationController.visibleViewController as? UINavigationController {
                                            expect(nc.viewControllers.count).to(equal(1))
                                            expect(nc.topViewController).to(beAnInstanceOf(FeedViewController.self))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    context("for a query feed") {
                        beforeEach {
                            cell = subject.tableView.visibleCells.last as? FeedTableCell
                            feed = feeds[1]

                            expect(cell).to(beAnInstanceOf(FeedTableCell.self))
                        }

                        it("should be configured with the theme repository") {
                            expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                        }

                        it("should be configured with the feed") {
                            expect(cell.feed).to(equal(feed))
                        }

                        describe("tapping on a cell") {
                            beforeEach {
                                let indexPath = NSIndexPath(forRow: 1, inSection: 0)
                                subject.tableView(subject.tableView, didSelectRowAtIndexPath: indexPath)
                            }

                            it("should navigate to an ArticleListViewController for that feed") {
                                expect(navigationController.topViewController).to(beAnInstanceOf(ArticleListController.self))
                                if let articleList = navigationController.topViewController as? ArticleListController {
                                    expect(articleList.feeds).to(equal([feed]))
                                }
                            }
                        }

                        describe("exposing edit actions") {
                            var actions: [UITableViewRowAction] = []
                            var action: UITableViewRowAction! = nil
                            let indexPath = NSIndexPath(forRow: 1, inSection: 0)
                            beforeEach {
                                actions = subject.tableView(subject.tableView, editActionsForRowAtIndexPath: indexPath) ?? []
                            }

                            it("should have 3 actions") {
                                expect(actions.count).to(equal(3))
                            }

                            describe("the first action") {
                                beforeEach {
                                    action = actions[0]
                                }

                                it("should state it deletes the feed") {
                                    expect(action.title).to(equal("Delete"))
                                }

                                describe("tapping it") {
                                    beforeEach {
                                        action.handler()(action, indexPath)
                                    }

                                    it("should delete the feed from the data store") {
                                        expect(dataReadWriter.lastDeletedFeed).to(equal(feed))
                                    }
                                }
                            }

                            describe("the second action") {
                                beforeEach {
                                    action = actions[1]
                                }

                                it("should state it marks all items in the feed as read") {
                                    expect(action.title).to(equal("Mark\nRead"))
                                }

                                describe("tapping it") {
                                    beforeEach {
                                        action.handler()(action, indexPath)
                                    }

                                    it("should mark all articles of that feed as read") {
                                        expect(dataReadWriter.lastFeedMarkedRead).to(equal(feed))
                                    }
                                }
                            }

                            describe("the second action") {
                                beforeEach {
                                    action = actions[2]
                                }

                                it("should state it edits the feed") {
                                    expect(action.title).to(equal("Edit"))
                                }

                                describe("tapping it") {
                                    beforeEach {
                                        action.handler()(action, indexPath)
                                    }

                                    it("should bring up a feed edit screen") {
                                        expect(navigationController.visibleViewController).to(beAnInstanceOf(UINavigationController.self))
                                        if let nc = navigationController.visibleViewController as? UINavigationController {
                                            expect(nc.viewControllers.count).to(equal(1))
                                            expect(nc.topViewController).to(beAnInstanceOf(QueryFeedViewController.self))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
