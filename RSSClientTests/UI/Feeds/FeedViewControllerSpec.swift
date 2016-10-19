import Quick
import Nimble
import rNews
import Ra
@testable import rNewsKit

class FeedViewControllerSpec: QuickSpec {
    override func spec() {
        var feed = Feed(title: "title", url: URL(string: "http://example.com/feed")!, summary: "summary",
            tags: ["a", "b", "c"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
        let otherFeed = Feed(title: "", url: URL(string: "http://example.com/feed")!, summary: "",
            tags: ["a", "b", "c"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

        var navigationController: UINavigationController!
        var subject: FeedViewController! = nil
        var injector: Injector! = nil
        var dataRepository: FakeDatabaseUseCase! = nil

        var urlSession: FakeURLSession! = nil
        var backgroundQueue: FakeOperationQueue! = nil
        var presentingController: UIViewController! = nil
        var themeRepository: ThemeRepository! = nil

        beforeEach {
            injector = Injector()

            urlSession = FakeURLSession()
            injector.bind(kind: URLSession.self, toInstance: urlSession)

            themeRepository = ThemeRepository(userDefaults: nil)
            injector.bind(kind: ThemeRepository.self, toInstance: themeRepository)

            backgroundQueue = FakeOperationQueue()
            backgroundQueue.runSynchronously = true
            injector.bind(string: kBackgroundQueue, toInstance: backgroundQueue)

            dataRepository = FakeDatabaseUseCase()
            injector.bind(kind: DatabaseUseCase.self, toInstance: dataRepository)

            subject = injector.create(kind: FeedViewController.self)!

            navigationController = UINavigationController(rootViewController: subject)

            presentingController = UIViewController()
            presentingController.present(navigationController, animated: false, completion: nil)

            feed = Feed(title: "title", url: URL(string: "http://example.com/feed")!, summary: "summary",
                tags: ["a", "b", "c"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            subject.feed = feed

            expect(subject.view).toNot(beNil())
        }

        it("should have a save button") {
            expect(subject.navigationItem.rightBarButtonItem?.title).to(equal("Save"))
        }

        describe("tapping 'save'") {
            beforeEach {
                let saveButton = subject.navigationItem.rightBarButtonItem
                saveButton?.tap()
            }

            it("should save the changes to the dataManager") {
                expect(dataRepository.lastSavedFeed).to(equal(feed))
            }

            it("should dismiss itself") {
                expect(presentingController.presentedViewController).to(beNil())
            }
        }

        it("should have a dismiss button") {
            expect(subject.navigationItem.leftBarButtonItem?.title).to(equal("Dismiss"))
        }

        describe("tapping 'dismiss'") {
            beforeEach {
                let dismissButton = subject.navigationItem.leftBarButtonItem
                dismissButton?.tap()
            }

            it("should dismiss itself") {
                expect(presentingController.presentedViewController).to(beNil())
            }
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("should change the tableView") {
                expect(subject.tableView.backgroundColor).to(equal(themeRepository.backgroundColor))
                expect(subject.tableView.separatorColor).to(equal(themeRepository.textColor))
            }

            it("should update the navigation bar styling") {
                expect(subject.navigationController?.navigationBar.barStyle).to(equal(themeRepository.barStyle))
                expect(subject.navigationController?.navigationBar.titleTextAttributes as? [String: UIColor]) == [NSForegroundColorAttributeName: themeRepository.textColor]
            }

            it("should update the tableView scroll indicator style") {
                expect(subject.tableView.indicatorStyle).to(equal(themeRepository.scrollIndicatorStyle))
            }
        }

        describe("the tableView") {
            it("should should have 4 sections") {
                expect(subject.tableView.numberOfSections).to(equal(4))
            }

            describe("the first section") {
                it("should have 1 row") {
                    expect(subject.tableView.numberOfRows(inSection: 0)).to(equal(1))
                }

                it("should be titled 'Title'") {
                    expect(subject.tableView(subject.tableView, titleForHeaderInSection: 0)).to(equal("Title"))
                }

                it("should not be editable") {
                    expect(subject.tableView(subject.tableView, canEditRowAt: IndexPath(row: 0, section: 0))) == false
                }

                describe("the cell") {
                    var cell: TableViewCell! = nil

                    context("when the feed has a tag that starts with '~'") {
                        beforeEach {
                            subject.feed = Feed(title: "a title", url: URL(string: ""), summary: "",
                                tags: ["~custom title"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                            cell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAt: IndexPath(row: 0, section: 0)) as! TableViewCell
                        }

                        it("should use that tag as the title, minus the leading '~'") {
                            expect(cell.textLabel?.text).to(equal("custom title"))
                        }

                        it("should set the cell's themeRepository") {
                            expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                        }
                    }

                    context("when the feed has a title preconfigured") {
                        beforeEach {
                            cell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAt: IndexPath(row: 0, section: 0)) as! TableViewCell
                        }

                        it("should have a label title equal to the feed's") {
                            expect(cell.textLabel?.text).to(equal(feed.displayTitle))
                        }

                        it("should set the cell's themeRepository") {
                            expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                        }
                    }
                }
            }

            describe("the second section") {
                it("should have 1 row") {
                    expect(subject.tableView.numberOfRows(inSection: 1)).to(equal(1))
                }

                it("should be titled 'URL'") {
                    expect(subject.tableView(subject.tableView, titleForHeaderInSection: 1)).to(equal("URL"))
                }

                it("should not be editable") {
                    expect(subject.tableView(subject.tableView, canEditRowAt: IndexPath(row: 0, section: 1))) == false
                }

                describe("the cell") {
                    var cell: TextFieldCell! = nil
                    beforeEach {
                        cell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAt: IndexPath(row: 0, section: 1)) as! TextFieldCell
                    }

                    it("should be preconfigured with the feed's url") {
                        expect(cell.textField.text).to(equal(feed.url!.absoluteString))
                    }

                    it("should set the cell's themeRepository") {
                        expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                    }

                    describe("on change") {
                        beforeEach {
                            let range = NSMakeRange(0, 23)
                            _ = cell.textField(cell.textField, shouldChangeCharactersIn: range, replacementString: "http://example.com/feed")
                        }

                        it("should make a request to the url") {
                            let urlString = urlSession.lastURL?.absoluteString
                            expect(urlString).to(equal("http://example.com/feed"))
                        }

                        context("when the request succeeds") {
                            let urlResponse = HTTPURLResponse(url: URL(string: "https://example.com/feed")!, statusCode: 200, httpVersion: nil, headerFields: nil)
                            context("if the response (text) is a valid feed") {
                                beforeEach {
                                    let rss = Bundle(for: self.classForCoder).url(forResource: "feed2", withExtension: "rss")!
                                    let data = try! Data(contentsOf: rss)
                                    urlSession.lastCompletionHandler(data, urlResponse, nil)
                                }
                                
                                it("should mark the field as valid") {
                                    expect(cell.isValid) == true
                                }
                            }

                            context("if the response is not a valid feed") {
                                beforeEach {
                                    let data = "Hello World".data(using: String.Encoding.utf8)
                                    urlSession.lastCompletionHandler(data, urlResponse, nil)
                                }

                                it("should mark the field as invalid") {
                                    expect(cell.isValid) == false
                                }
                            }
                        }

                        context("when the request fails") {
                            beforeEach {
                                urlSession.lastCompletionHandler(nil, nil, NSError(domain: "", code: 0, userInfo: [:]))
                            }

                            it("should mark the field as invalid") {
                                expect(cell.isValid) == false
                            }
                        }
                    }
                }
            }

            describe("the third section") {
                var cell: TableViewCell! = nil
                it("should have 1 row") {
                    expect(subject.tableView.numberOfRows(inSection: 2)).to(equal(1))
                }

                it("should be titled 'Summary'") {
                    expect(subject.tableView(subject.tableView, titleForHeaderInSection: 2)).to(equal("Summary"))
                }

                it("should not be editable") {
                    expect(subject.tableView(subject.tableView, canEditRowAt: IndexPath(row: 0, section: 2))) == false
                }

                context("when the feed has no summary preconfigured") {
                    beforeEach {
                        subject.feed = otherFeed

                        cell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAt: IndexPath(row: 0, section: 2)) as! TableViewCell
                    }

                    it("should set the cell's themeRepository") {
                        expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                    }

                    it("should have a label title 'No Summary Available'") {
                        expect(cell.textLabel?.text).to(equal("No Summary Available"))
                    }

                    it("should re-color the text gray") {
                        expect(cell.textLabel?.textColor).to(equal(UIColor.gray))
                    }
                }

                context("when the feed has a tag that starts with '`'") {
                    beforeEach {
                        subject.feed = Feed(title: "a title", url: URL(string: ""), summary: "a summary",
                            tags: ["`custom summary"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                        cell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAt: IndexPath(row: 0, section: 2)) as! TableViewCell
                    }

                    it("should use that tag as the summary, minus the leading '`'") {
                        expect(cell.textLabel?.text).to(equal("custom summary"))
                    }

                    it("should set the cell's themeRepository") {
                        expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                    }
                }

                context("when the feed has a summary preconfigured") {
                    beforeEach {
                        cell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAt: IndexPath(row: 0, section: 2)) as! TableViewCell
                    }

                    it("should have a label title equal to the feed's") {
                        expect(cell.textLabel?.text).to(equal(feed.displaySummary))
                    }

                    it("should set the cell's themeRepository") {
                        expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                    }
                }
            }

            describe("the fourth section") {
                it("should have n+1 rows") {
                    expect(subject.tableView.numberOfRows(inSection: 3)).to(equal(feed.tags.count + 1))
                }

                it("should be titled 'Tags'") {
                    expect(subject.tableView(subject.tableView, titleForHeaderInSection: 3)).to(equal("Tags"))
                }

                describe("the first row") {
                    var cell: TableViewCell! = nil
                    let tagIndex: Int = 0

                    beforeEach {
                        cell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAt: IndexPath(row: 0, section: 3)) as! TableViewCell
                    }

                    it("should be titled for the row") {
                        expect(cell.textLabel?.text).to(equal(feed.tags[tagIndex]))
                    }

                    it("should be editable") {
                        expect(subject.tableView(subject.tableView, canEditRowAt: IndexPath(row: tagIndex, section: 3))) == true
                    }

                    it("should set the cell's themeRepository") {
                        expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                    }

                    describe("edit actions") {
                        var editActions: [UITableViewRowAction] = []
                        beforeEach {
                            editActions = subject.tableView(subject.tableView,
                                editActionsForRowAt: IndexPath(row: tagIndex, section: 3)) ?? []
                        }

                        it("should have 2 edit actions") {
                            expect(editActions.count).to(equal(2))
                        }

                        describe("the first action") {
                            var action: UITableViewRowAction! = nil

                            beforeEach {
                                action = editActions.first
                            }

                            it("should is titled 'Delete'") {
                                expect(action.title).to(equal("Delete"))
                            }

                            it("should removes the tag when tapped") {
                                let tag = feed.tags[tagIndex]
                                action.handler(action, IndexPath(row: tagIndex, section: 3))
                                expect(feed.tags).toNot(contain(tag))
                            }
                        }

                        describe("the second action") {
                            var action: UITableViewRowAction! = nil

                            beforeEach {
                                action = editActions.last
                            }

                            it("should is titled 'Edit'") {
                                expect(action.title).to(equal("Edit"))
                            }

                            it("should removes the tag when tapped") {
                                action.handler(action, IndexPath(row: tagIndex, section: 3))
                                expect(navigationController.topViewController).to(beAnInstanceOf(TagEditorViewController.self))
                                if let tagEditor = navigationController.topViewController as? TagEditorViewController {
                                    expect(tagEditor.tagIndex).to(equal(tagIndex))
                                    expect(tagEditor.feed).to(equal(feed))
                                }
                            }
                        }
                    }
                }

                describe("the last row") {
                    var cell: TableViewCell! = nil
                    var indexPath: IndexPath! = nil

                    beforeEach {
                        indexPath = IndexPath(row: feed.tags.count, section: 3)
                        cell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAt: indexPath) as! TableViewCell
                    }

                    it("should be titled 'Add Tag'") {
                        expect(cell.textLabel?.text).to(equal("Add Tag"))
                    }

                    it("should not be editable") {
                        expect(subject.tableView(subject.tableView, canEditRowAt: indexPath)) == false
                    }

                    it("should set the cell's themeRepository") {
                        expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                    }

                    describe("when tapped") {
                        beforeEach {
                            subject.tableView(subject.tableView, didSelectRowAt: indexPath)
                        }

                        it("should bring up the tag editor screen") {
                            expect(navigationController.topViewController).to(beAnInstanceOf(TagEditorViewController.self))
                            if let tagEditor = navigationController.topViewController as? TagEditorViewController {
                                expect(tagEditor.tagIndex).to(beNil())
                                expect(tagEditor.feed).to(equal(feed))
                            }
                        }
                    }
                }
            }
        }
    }
}
