import Quick
import Nimble
import Ra
import rNews
import rNewsKit

class TagEditorViewControllerSpec: QuickSpec {
    override func spec() {
        var injector: Injector! = nil
        var dataRepository = FakeDataRepository()
        var subject: TagEditorViewController! = nil
        var navigationController: UINavigationController! = nil
        var themeRepository: FakeThemeRepository! = nil
        let rootViewController = UIViewController()

        var feed = Feed(title: "title", url: NSURL(string: ""), summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

        beforeEach {
            injector = Injector()
            dataRepository = FakeDataRepository()
            injector.bind(FeedRepository.self, toInstance: dataRepository)

            themeRepository = FakeThemeRepository()
            injector.bind(ThemeRepository.self, toInstance: themeRepository)

            subject = injector.create(TagEditorViewController)!
            navigationController = UINavigationController(rootViewController: rootViewController)
            navigationController.pushViewController(subject, animated: false)

            feed = Feed(title: "title", url: NSURL(string: ""), summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
            subject.feed = feed

            expect(subject.view).toNot(beNil())
            expect(navigationController.topViewController).to(equal(subject))
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("should change background color") {
                expect(subject.view.backgroundColor).to(equal(themeRepository.backgroundColor))
            }

            it("should change the navigation bar style") {
                expect(subject.navigationController?.navigationBar.barTintColor).to(equal(themeRepository.backgroundColor))
            }

            it("should change the tagPicker's textColors") {
                expect(subject.tagPicker.textField.textColor).to(equal(themeRepository.textColor))
            }
        }

        it("should should set the title to the feed's title") {
            expect(subject.navigationItem.title).to(equal("title"))
        }

        it("should have a save button") {
            expect(subject.navigationItem.rightBarButtonItem?.title).to(equal("Save"))
        }

        describe("tapping the save button") {
            context("when there is data to save") {
                beforeEach {
                    subject.tagPicker.textField(subject.tagPicker.textField, shouldChangeCharactersInRange: NSMakeRange(0, 0), replacementString: "a")
                    subject.navigationItem.rightBarButtonItem?.tap()
                }

                it("should save the feed, with the added tag") {
                    let newFeed = Feed(title: "title", url: NSURL(string: ""), summary: "", query: nil, tags: ["a"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    expect(dataRepository.lastSavedFeed).to(equal(newFeed))
                }

                it("should pop the navigation controller") {
                    expect(navigationController.topViewController).to(equal(rootViewController))
                }
            }

            context("when there is not data to save") {
                it("should not even be enabled") {
                    expect(subject.navigationItem.rightBarButtonItem?.enabled).to(beFalsy())
                }
            }
        }
    }
}
