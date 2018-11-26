import Quick
import Nimble
import Tethys
@testable import TethysKit

class FeedViewControllerSpec: QuickSpec {
    override func spec() {
        var feed: Feed!

        var navigationController: UINavigationController!
        var subject: FeedViewController!
        var dataRepository: FakeDatabaseUseCase!

        var presentingController: UIViewController!
        var themeRepository: ThemeRepository!

        beforeEach {
            feed = Feed(title: "title", url: URL(string: "http://example.com/feed")!, summary: "summary", tags: ["a", "b", "c"], articles: [], image: nil)

            themeRepository = ThemeRepository(userDefaults: nil)

            dataRepository = FakeDatabaseUseCase()
            subject = FeedViewController(
                feed: feed,
                feedRepository: dataRepository,
                themeRepository: themeRepository,
                tagEditorViewController: {
                    return TagEditorViewController(feedRepository: dataRepository, themeRepository: themeRepository)
                }
            )

            navigationController = UINavigationController(rootViewController: subject)

            presentingController = UIViewController()
            presentingController.present(navigationController, animated: false, completion: nil)

            subject.view.layoutIfNeeded()
        }

        it("has a save button") {
            expect(subject.navigationItem.rightBarButtonItem?.title) == "Save"
        }

        describe("tapping 'save'") {
            beforeEach {
                let saveButton = subject.navigationItem.rightBarButtonItem
                saveButton?.tap()
            }

            it("saves the changes to the dataManager") {
                expect(dataRepository.lastSavedFeed) == feed
            }

            it("dismisses itself") {
                expect(presentingController.presentedViewController).to(beNil())
            }
        }

        it("has a dismiss button") {
            expect(subject.navigationItem.leftBarButtonItem?.title) == "Dismiss"
        }

        describe("tapping 'dismiss'") {
            beforeEach {
                let dismissButton = subject.navigationItem.leftBarButtonItem
                dismissButton?.tap()
            }

            it("dismisses itself") {
                expect(presentingController.presentedViewController).to(beNil())
            }
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("updates the navigation bar styling") {
                expect(subject.navigationController?.navigationBar.barStyle).to(equal(themeRepository.barStyle))
                expect(subject.navigationController?.navigationBar.titleTextAttributes as? [String: UIColor]) == [NSForegroundColorAttributeName: themeRepository.textColor]
            }
        }

        describe("the feedDetailView") {
            it("is configured with the feed's title, url, summary, and tags") {
                expect(subject.feedDetailView.title) == "title"
                expect(subject.feedDetailView.url) == URL(string: "http://example.com/feed")
                expect(subject.feedDetailView.summary) == "summary"
                expect(subject.feedDetailView.tags) == ["a", "b", "c"]
            }
        }

        describe("the feedDetailViewDelegate") {
            describe("feedDetailView(urlDidChange:)") {
                let url = URL(string: "https://example.com/new_feed")!

                beforeEach {
                    subject.feedDetailView.delegate?.feedDetailView(subject.feedDetailView, urlDidChange: url)
                }

                it("does not yet set the feed url to the new url") {
                    expect(feed.url) == URL(string: "http://example.com/feed")
                }

                describe("tapping 'save'") {
                    beforeEach {
                        let saveButton = subject.navigationItem.rightBarButtonItem
                        saveButton?.tap()
                    }

                    it("sets the feed url to the new feed") {
                        expect(feed.url) == url
                    }

                    it("saves the changes to the dataManager") {
                        expect(dataRepository.lastSavedFeed) == feed
                    }

                    it("dismisses itself") {
                        expect(presentingController.presentedViewController).to(beNil())
                    }
                }
            }

            describe("feedDetailView(tagsDidChange:)") {
                let tags = ["d", "e", "f"]

                beforeEach {
                    subject.feedDetailView.delegate?.feedDetailView(subject.feedDetailView, tagsDidChange: tags)
                }

                it("does not yet set the feed tags to the new tags") {
                    expect(feed.tags) == ["a", "b", "c"]
                }

                describe("tapping 'save'") {
                    beforeEach {
                        let saveButton = subject.navigationItem.rightBarButtonItem
                        saveButton?.tap()
                    }

                    it("sets the feed url to the new feed") {
                        expect(feed.tags) == tags
                    }

                    it("saves the changes to the dataManager") {
                        expect(dataRepository.lastSavedFeed) == feed
                    }

                    it("dismisses itself") {
                        expect(presentingController.presentedViewController).to(beNil())
                    }
                }
            }

            describe("feedDetailView(editTag:completion:)") {
                var newTag: String?
                var tagCompletionCallCount = 0

                context("with a nil tag") {
                    beforeEach {
                        newTag = nil
                        tagCompletionCallCount = 0
                        subject.feedDetailView.delegate?.feedDetailView(subject.feedDetailView, editTag: nil) {
                            newTag = $0
                            tagCompletionCallCount += 1
                        }
                    }

                    it("shows a tag editor controller to add the tag") {
                        expect(navigationController.topViewController).to(beAnInstanceOf(TagEditorViewController.self))
                        if let tagEditor = navigationController.topViewController as? TagEditorViewController {
                            expect(tagEditor.tag).to(beNil())
                        }
                    }

                    it("calls the callback when the tagEditor is done") {
                        expect(navigationController.topViewController).to(beAnInstanceOf(TagEditorViewController.self))
                        if let tagEditor = navigationController.topViewController as? TagEditorViewController {
                            tagEditor.onSave?("newTag")

                            expect(tagCompletionCallCount) == 1
                            expect(newTag) == "newTag"
                        }
                    }
                }

                context("with a tag") {
                    let existingTag = "hello"
                    beforeEach {
                        newTag = nil
                        tagCompletionCallCount = 0
                        subject.feedDetailView.delegate?.feedDetailView(subject.feedDetailView, editTag: existingTag) {
                            newTag = $0
                            tagCompletionCallCount += 1
                        }
                    }

                    it("shows a tag editor controller to add the tag") {
                        expect(navigationController.topViewController).to(beAnInstanceOf(TagEditorViewController.self))
                        if let tagEditor = navigationController.topViewController as? TagEditorViewController {
                            expect(tagEditor.tag) == "hello"
                        }
                    }

                    it("calls the callback when the tagEditor is done") {
                        expect(navigationController.topViewController).to(beAnInstanceOf(TagEditorViewController.self))
                        if let tagEditor = navigationController.topViewController as? TagEditorViewController {
                            tagEditor.onSave?("newTag")

                            expect(tagCompletionCallCount) == 1
                            expect(newTag) == "newTag"
                        }
                    }
                }
            }
        }
    }
}
