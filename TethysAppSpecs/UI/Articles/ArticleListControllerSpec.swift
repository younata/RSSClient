import Quick
import Nimble
@testable import Tethys
import TethysKit
import UIKit

class FakeUIViewControllerPreviewing: NSObject, UIViewControllerPreviewing {
    @available(iOS 9.0, *)
    var previewingGestureRecognizerForFailureRelationship: UIGestureRecognizer {
        return UIGestureRecognizer()
    }

    private let _delegate: NSObject?

    @available(iOS 9.0, *)
    var delegate: UIViewControllerPreviewingDelegate {
        if let delegate = _delegate as? UIViewControllerPreviewingDelegate {
            return delegate
        }
        fatalError("_delegate was not set")
    }

    private let _sourceView: UIView

    @available(iOS 9.0, *)
    var sourceView: UIView {
        return _sourceView
    }

    private var _sourceRect: CGRect

    @available(iOS 9.0, *)
    var sourceRect: CGRect {
        get { return _sourceRect }
        set { _sourceRect = newValue }
    }

    init(sourceView: UIView, sourceRect: CGRect, delegate: NSObject) {
        self._sourceView = sourceView
        self._sourceRect = sourceRect
        self._delegate = delegate
    }
}

private var publishedOffset = -1
func fakeArticle(feed: Feed, isUpdated: Bool = false, read: Bool = false) -> Article {
    publishedOffset += 1
    let publishDate: Date
    let updatedDate: Date?
    if isUpdated {
        updatedDate = Date(timeIntervalSinceReferenceDate: TimeInterval(publishedOffset))
        publishDate = Date(timeIntervalSinceReferenceDate: 0)
    } else {
        publishDate = Date(timeIntervalSinceReferenceDate: TimeInterval(publishedOffset))
        updatedDate = nil
    }
    return Article(title: "article \(publishedOffset)", link: URL(string: "http://example.com")!, summary: "", authors: [Author(name: "Rachel", email: nil)], published: publishDate, updatedAt: updatedDate, identifier: "\(publishedOffset)", content: "", read: read, synced: false, feed: feed, flags: [])
}

class ArticleListControllerSpec: QuickSpec {
    override func spec() {
        var mainQueue: FakeOperationQueue!
        var feed: Feed!
        var subject: ArticleListController!
        var navigationController: UINavigationController!
        var articles: [Article] = []
        var dataRepository: FakeDatabaseUseCase!
        var articleService: FakeArticleService!
        var themeRepository: ThemeRepository!
        var settingsRepository: SettingsRepository!
        var articleCellController: FakeArticleCellController!

        beforeEach {
            mainQueue = FakeOperationQueue()
            settingsRepository = SettingsRepository(userDefaults: nil)

            let useCase = FakeArticleUseCase()
            useCase.readArticleReturns("hello")

            themeRepository = ThemeRepository(userDefaults: nil)
            dataRepository = FakeDatabaseUseCase()

            publishedOffset = 0

            feed = Feed(title: "", url: URL(string: "https://example.com")!, summary: "hello world", tags: [], articles: [], image: nil)
            let d = fakeArticle(feed: feed)
            let c = fakeArticle(feed: feed, read: true)
            let b = fakeArticle(feed: feed, isUpdated: true)
            let a = fakeArticle(feed: feed)
            articles = [a, b, c, d]

            for article in articles {
                feed.addArticle(article)
            }

            articleService = FakeArticleService()
            articleCellController = FakeArticleCellController()

            subject = ArticleListController(
                mainQueue: mainQueue,
                articleService: articleService,
                feedRepository: dataRepository,
                themeRepository: themeRepository,
                settingsRepository: settingsRepository,
                articleCellController: articleCellController,
                articleViewController: { articleViewControllerFactory(articleUseCase: useCase) }
            )

            navigationController = UINavigationController(rootViewController: subject)
        }

        it("dismisses the keyboard upon drag") {
            subject.view.layoutIfNeeded()
            expect(subject.tableView.keyboardDismissMode).to(equal(UIScrollViewKeyboardDismissMode.onDrag))
        }

        it("hides the toolbar") {
            expect(navigationController.isToolbarHidden).to(beTruthy())
        }

        describe("the bar button items") {
            describe("when a feed is backing the list") {
                beforeEach {
                    subject.view.layoutIfNeeded()

                    subject.feed = feed
                }

                it("displays 3 items") {
                    expect(subject.navigationItem.rightBarButtonItems).to(haveCount(3))
                }

                describe("the first item") {
                    var item: UIBarButtonItem?

                    beforeEach {
                        item = subject.navigationItem.rightBarButtonItems?.first
                    }

                    it("is the edit button") {
                        expect(item) == subject.editButtonItem
                    }
                }

                describe("the second item") {
                    var item: UIBarButtonItem?

                    beforeEach {
                        guard subject.navigationItem.rightBarButtonItems?.count == 3 else {
                            item = nil
                            return
                        }
                        item = subject.navigationItem.rightBarButtonItems?[1]
                    }

                    describe("when tapped") {
                        beforeEach {
                            item?.tap()
                        }

                        it("presents a share sheet") {
                            expect(subject.presentedViewController).to(beAnInstanceOf(URLShareSheet.self))
                        }

                        it("configures the share sheet with the url") {
                            guard let shareSheet = subject.presentedViewController as? URLShareSheet else {
                                fail("No share sheet presented")
                                return
                            }
                            expect(shareSheet.url) == feed.url
                            expect(shareSheet.themeRepository) == themeRepository
                            expect(shareSheet.activityItems as? [URL]) == [feed.url]
                        }
                    }
                }

                describe("the third item") {
                    var item: UIBarButtonItem?

                    beforeEach {
                        item = subject.navigationItem.rightBarButtonItems?.last
                    }

                    describe("when tapped") {
                        beforeEach {
                            item?.tap()
                        }

                        it("shows an indicator that we're doing things") {
                            let indicator = subject.view.subviews.filter {
                                return $0.isKind(of: ActivityIndicator.classForCoder())
                                }.first as? ActivityIndicator
                            expect(indicator?.message) == "Marking Articles as Read"
                        }

                        it("marks all articles of that feed as read") {
                            expect(dataRepository.lastFeedMarkedRead) == feed
                        }

                        describe("when the mark read promise succeeds") {
                            beforeEach {
                                dataRepository.lastFeedMarkedReadPromise?.resolve(.success(1))

                                mainQueue.runNextOperation()

                            }
                            it("removes the indicator") {
                                let indicator = subject.view.subviews.filter {
                                    return $0.isKind(of: ActivityIndicator.classForCoder())
                                    }.first
                                expect(indicator).to(beNil())
                            }
                        }

                        describe("when the mark read promise fails") {
                            beforeEach {
                                dataRepository.lastFeedMarkedReadPromise?.resolve(.failure(.database(.unknown)))
                                mainQueue.runNextOperation()
                            }

                            it("removes the indicator") {
                                let indicator = subject.view.subviews.filter {
                                    return $0.isKind(of: ActivityIndicator.classForCoder())
                                    }.first
                                expect(indicator).to(beNil())
                            }

                            it("shows an alert box") {
                                expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                if let alert = subject.presentedViewController as? UIAlertController {
                                    expect(alert.title) == "Unable to Mark Articles as Read"
                                    expect(alert.message) == "Unknown Database Error"
                                    expect(alert.actions.count) == 1
                                    if let action = alert.actions.first {
                                        expect(action.title) == "Ok"
                                        action.handler?(action)
                                        expect(subject.presentedViewController).to(beNil())
                                    }
                                }
                            }
                        }
                    }
                }
            }

            describe("when a feed is not backing the list") {
                beforeEach {
                    subject.view.layoutIfNeeded()

                    subject.feed = nil
                }

                it("displays only the edit button") {
                    expect(subject.navigationItem.rightBarButtonItems?.count) == 1
                    expect(subject.navigationItem.rightBarButtonItems?.first) == subject.editButtonItem
                }
            }
        }

        describe("listening to theme repository updates") {
            beforeEach {
                subject.view.layoutIfNeeded()
                subject.viewWillAppear(false)
                themeRepository.theme = .dark
            }

            it("should update the tableView") {
                expect(subject.tableView.backgroundColor).to(equal(themeRepository.backgroundColor))
                expect(subject.tableView.separatorColor).to(equal(themeRepository.textColor))
            }

            it("should update the tableView scroll indicator style") {
                expect(subject.tableView.indicatorStyle).to(equal(themeRepository.scrollIndicatorStyle))
            }

            it("should update the navigation bar") {
                expect(subject.navigationController?.navigationBar.barStyle).to(equal(themeRepository.barStyle))
                expect(subject.navigationController?.navigationBar.titleTextAttributes as? [String: UIColor]) == [NSForegroundColorAttributeName: themeRepository.textColor]
            }
        }

        describe("force pressing an article cell") {
            var viewControllerPreviewing: FakeUIViewControllerPreviewing! = nil
            let indexPath = IndexPath(row: 0, section: 1)
            var viewController: UIViewController? = nil

            beforeEach {
                viewControllerPreviewing = FakeUIViewControllerPreviewing(sourceView: subject.tableView, sourceRect: CGRect.zero, delegate: subject)

                subject.view.layoutIfNeeded()
                subject.feed = feed
                let rect = subject.tableView.rectForRow(at: indexPath)
                let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
            }

            it("returns an ArticleViewController configured with the article to present to the user") {
                expect(viewController).to(beAKindOf(ArticleViewController.self))
                if let articleVC = viewController as? ArticleViewController {
                    expect(articleVC.article).to(equal(articles[0]))
                }
            }

            it("does not mark the article as read") {
                expect(articleService.markArticleAsReadCalls).to(haveCount(0))
                expect(articles[0].read) == false
            }

            describe("the preview actions") {
                var previewActions: [UIPreviewActionItem]?
                var action: UIPreviewAction?

                beforeEach {
                    previewActions = viewController?.previewActionItems
                    expect(previewActions).toNot(beNil())
                }

                it("has 2 preview actions") {
                    expect(previewActions?.count) == 2
                }

                describe("the first action") {
                    describe("for an unread article") {
                        beforeEach {
                            action = previewActions?.first as? UIPreviewAction

                            expect(action?.title).to(equal("Mark Read"))
                            action?.handler(action!, viewController!)
                        }

                        it("marks the article as read") {
                            guard let call = articleService.markArticleAsReadCalls.last else {
                                fail("Didn't call ArticleService to mark article as read")
                                return
                            }
                            expect(call.article) == articles.first
                            expect(call.read) == true
                        }

                        context("when the articleService successfully marks the article as read") {
                            var updatedArticle: Article!
                            beforeEach {
                                guard let article = articles.first else { fail("No articles - can't happen"); return }
                                updatedArticle = Article(
                                    title: article.title,
                                    link: article.link,
                                    summary: article.summary,
                                    authors: article.authors,
                                    published: article.published,
                                    updatedAt: article.updatedAt,
                                    identifier: article.identifier,
                                    content: article.content,
                                    read: true,
                                    synced: article.synced,
                                    feed: article.feed,
                                    flags: article.flags
                                )
                                articleService.markArticleAsReadPromises.last?.resolve(.success(
                                    updatedArticle
                                    ))
                            }

                            it("Updates the articles in the controller to reflect that") {
                                expect(subject.articles.first).to(equal(updatedArticle))
                            }
                        }

                        context("when the articleService fails to mark the article as read") {
                            xit("presents a banner indicates that a failure happened") {
                                fail("Not Implemented")
                            }
                        }
                    }

                    describe("for a read article") {
                        beforeEach {
                            let rect = subject.tableView.rectForRow(at: IndexPath(row: 2, section: 1))
                            let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                            viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                            previewActions = viewController?.previewActionItems
                            action = previewActions?.first as? UIPreviewAction

                            expect(action?.title).to(equal("Mark Unread"))
                            action?.handler(action!, viewController!)
                        }

                        it("marks the article as unread") {
                            guard let call = articleService.markArticleAsReadCalls.last else {
                                fail("Didn't call ArticleService to mark article as read/unread")
                                return
                            }
                            expect(call.article) == articles[2]
                            expect(call.read) == false
                        }

                        context("when the articleService successfully marks the article as read") {
                            var updatedArticle: Article!
                            beforeEach {
                                guard let article = articles.first else { fail("No articles - can't happen"); return }
                                updatedArticle = Article(
                                    title: article.title,
                                    link: article.link,
                                    summary: article.summary,
                                    authors: article.authors,
                                    published: article.published,
                                    updatedAt: article.updatedAt,
                                    identifier: article.identifier,
                                    content: article.content,
                                    read: false,
                                    synced: article.synced,
                                    feed: article.feed,
                                    flags: article.flags
                                )
                                articleService.markArticleAsReadPromises.last?.resolve(.success(
                                    updatedArticle
                                    ))
                            }

                            it("Updates the articles in the controller to reflect that") {
                                expect(subject.articles.first).to(equal(updatedArticle))
                            }
                        }

                        context("when the articleService fails to mark the article as read") {
                            xit("presents a banner indicates that a failure happened") {
                                fail("Not Implemented")
                            }
                        }
                    }
                }

                describe("the last action") {
                    beforeEach {
                        action = previewActions?.last as? UIPreviewAction
                    }

                    it("states that it deletes the article") {
                        expect(action?.title) == "Delete"
                    }

                    describe("tapping it") {
                        beforeEach {
                            action?.handler(action!, viewController!)
                        }

                        it("does not yet delete the article") {
                            expect(articleService.removeArticleCalls).to(beEmpty())
                        }

                        it("presents an alert asking for confirmation that the user wants to do this") {
                            expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                            guard let alert = subject.presentedViewController as? UIAlertController else { return }
                            expect(alert.preferredStyle) == UIAlertControllerStyle.alert
                            expect(alert.title) == "Delete \(articles.first!.title)?"

                            expect(alert.actions.count) == 2
                            expect(alert.actions.first?.title) == "Delete"
                            expect(alert.actions.last?.title) == "Cancel"
                        }

                        describe("tapping 'Delete'") {
                            beforeEach {
                                expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                guard let alert = subject.presentedViewController as? UIAlertController else { return }

                                alert.actions.first?.handler?(alert.actions.first!)
                            }

                            it("deletes the article") {
                                expect(articleService.removeArticleCalls.last).to(equal(articles.first))
                            }

                            it("dismisses the alert") {
                                expect(subject.presentedViewController).to(beNil())
                            }

                            xit("shows a spinner while we wait to delete the article") {
                                fail("Implement me!")
                            }

                            context("when the delete operation succeeds") {
                                beforeEach {
                                    articleService.removeArticlePromises.last?.resolve(.success())
                                }

                                it("removes the article from the list") {
                                    expect(Array(subject.articles)).toNot(contain(articles[0]))
                                }
                            }

                            context("when the delete operation fails") {
                                beforeEach {
                                    articleService.removeArticlePromises.last?.resolve(.failure(TethysError.database(.unknown)))
                                }

                                xit("shows a message saying that we had an error") {
                                    fail("Implement me!")
                                }
                            }
                        }

                        describe("tapping 'Cancel'") {
                            beforeEach {
                                expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                guard let alert = subject.presentedViewController as? UIAlertController else { return }

                                alert.actions.last?.handler?(alert.actions.last!)
                            }

                            it("does not delete the article") {
                                expect(articleService.removeArticleCalls).to(beEmpty())
                            }

                            it("dismisses the alert") {
                                expect(subject.presentedViewController).to(beNil())
                            }
                        }
                    }
                }
            }

            describe("committing that view controller") {
                beforeEach {
                    if let vc = viewController {
                        subject.previewingContext(viewControllerPreviewing, commit: vc)
                    }
                }

                it("pushes the view controller") {
                    expect(navigationController.topViewController).to(beIdenticalTo(viewController))
                }

                it("marks the article as read") {
                    guard let call = articleService.markArticleAsReadCalls.last else {
                        fail("Didn't call ArticleService to mark article as read")
                        return
                    }
                    expect(call.article) == articles[0]
                    expect(call.read) == true
                }

                context("when the articleService successfully marks the article as read") {
                    var updatedArticle: Article!
                    beforeEach {
                        guard let article = articles.first else { fail("No articles - can't happen"); return }
                        updatedArticle = Article(
                            title: article.title,
                            link: article.link,
                            summary: article.summary,
                            authors: article.authors,
                            published: article.published,
                            updatedAt: article.updatedAt,
                            identifier: article.identifier,
                            content: article.content,
                            read: true,
                            synced: article.synced,
                            feed: article.feed,
                            flags: article.flags
                        )
                        articleService.markArticleAsReadPromises.last?.resolve(.success(
                            updatedArticle
                            ))
                    }

                    it("Updates the articles in the controller to reflect that") {
                        expect(subject.articles.first).to(equal(updatedArticle))
                    }
                }

                context("when the articleService fails to mark the article as read") {
                    xit("presents a banner indicates that a failure happened") {
                        fail("Not Implemented")
                    }
                }
            }
        }

        describe("the table") {
            it("has 2 sections") {
                subject.view.layoutIfNeeded()
                subject.feed = feed

                expect(subject.tableView.numberOfSections) == 2
            }

            it("does not allow multiselection") {
                subject.view.layoutIfNeeded()
                subject.feed = feed

                expect(subject.tableView.allowsMultipleSelection) == false
            }

            describe("the first section") {
                context("when a feed is backing the list") {
                    beforeEach {
                        subject.view.layoutIfNeeded()

                        subject.feed = feed
                        subject.tableView.reloadData()
                    }

                    it("has 1 cell in the first section of the tableView") {
                        expect(subject.tableView.numberOfRows(inSection: 0)) == 1
                    }

                    describe("that cell") {
                        var cell: ArticleListHeaderCell?

                        beforeEach {
                            feed.summary = "summary"
                            cell = subject.tableView.visibleCells.first as? ArticleListHeaderCell
                            expect(cell).toNot(beNil())
                        }

                        it("is configured with the theme repository") {
                            expect(cell?.themeRepository).to(beIdenticalTo(themeRepository))
                        }

                        it("is configured with the feed") {
                            expect(cell?.summary.text) == feed.displaySummary
                        }

                        it("has no edit actions") {
                            expect(subject.tableView(subject.tableView, editActionsForRowAt: IndexPath(row: 0, section: 0))).to(beNil())
                        }

                        it("does nothing when tapped") {
                            subject.tableView(subject.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
                            expect(navigationController.topViewController).to(beIdenticalTo(subject))
                        }
                    }
                }

                context("when a feed without a description or image is backing the list") {
                    beforeEach {
                        subject.view.layoutIfNeeded()

                        subject.feed = Feed(title: "Title", url: URL(string: "https://example.com")!, summary: "",
                                            tags: [], articles: [], image: nil)
                        subject.tableView.reloadData()
                    }

                    it("has 0 cells in the first section of the tableView") {
                        expect(subject.tableView.numberOfRows(inSection: 0)) == 0
                    }
                }

                context("when a feed is not backing the list") {
                    beforeEach {
                        subject.view.layoutIfNeeded()

                        subject.feed = nil
                        subject.tableView.reloadData()
                    }
                    
                    it("has 0 cells in the first section of the tableView") {
                        expect(subject.tableView.numberOfRows(inSection: 0)) == 0
                    }
                }
            }

            describe("the articles section") {
                beforeEach {
                    subject.feed = feed
                    subject.view.layoutIfNeeded()
                }

                it("has a row for each article") {
                    expect(subject.tableView.numberOfRows(inSection: 1)).to(equal(articles.count))
                }

                describe("the cells") {
                    it("is editable") {
                        let section = 1
                        for row in 0..<subject.tableView.numberOfRows(inSection: section) {
                            let indexPath = IndexPath(row: row, section: section)
                            expect(subject.tableView(subject.tableView, canEditRowAt: indexPath)) == true
                        }
                    }

                    it("has 2 edit actions") {
                        let section = 1
                        for row in 0..<subject.tableView.numberOfRows(inSection: section) {
                            let indexPath = IndexPath(row: row, section: section)
                            expect(subject.tableView(subject.tableView, editActionsForRowAt: indexPath)?.count).to(equal(2))
                        }
                    }

                    describe("the edit actions") {
                        describe("the first action") {
                            var action: UITableViewRowAction! = nil
                            let indexPath = IndexPath(row: 0, section: 1)

                            beforeEach {
                                action = subject.tableView(subject.tableView, editActionsForRowAt: indexPath)?.first
                            }

                            it("states that it deletes the article") {
                                expect(action?.title) == "Delete"
                            }

                            describe("tapping it") {
                                beforeEach {
                                    action.handler?(action, indexPath)
                                }

                                it("does not yet delete the article") {
                                    expect(articleService.removeArticleCalls).to(beEmpty())
                                }

                                it("presents an alert asking for confirmation that the user wants to do this") {
                                    expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                    guard let alert = subject.presentedViewController as? UIAlertController else { return }
                                    expect(alert.preferredStyle) == UIAlertControllerStyle.alert
                                    expect(alert.title) == "Delete \(articles.first!.title)?"

                                    expect(alert.actions.count) == 2
                                    expect(alert.actions.first?.title) == "Delete"
                                    expect(alert.actions.last?.title) == "Cancel"
                                }

                                describe("tapping 'Delete'") {
                                    beforeEach {
                                        expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                        guard let alert = subject.presentedViewController as? UIAlertController else { return }

                                        alert.actions.first?.handler?(alert.actions.first!)
                                    }

                                    it("deletes the article") {
                                        expect(articleService.removeArticleCalls.last) == articles.first
                                    }

                                    it("dismisses the alert") {
                                        expect(subject.presentedViewController).to(beNil())
                                    }

                                    xit("shows a spinner while we wait to delete the article") {
                                        fail("Implement me!")
                                    }

                                    context("when the delete operation succeeds") {
                                        beforeEach {
                                            articleService.removeArticlePromises.last?.resolve(.success())
                                        }

                                        it("removes the article from the list") {
                                            expect(Array(subject.articles)).toNot(contain(articles[0]))
                                        }
                                    }

                                    context("when the delete operation fails") {
                                        beforeEach {
                                            articleService.removeArticlePromises.last?.resolve(.failure(TethysError.database(.unknown)))
                                        }

                                        xit("shows a message saying that we had an error") {
                                            fail("Implement me!")
                                        }
                                    }
                                }

                                describe("tapping 'Cancel'") {
                                    beforeEach {
                                        expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                        guard let alert = subject.presentedViewController as? UIAlertController else { return }

                                        alert.actions.last?.handler?(alert.actions.last!)
                                    }

                                    it("does not delete the article") {
                                        expect(articleService.removeArticleCalls).to(beEmpty())
                                    }

                                    it("dismisses the alert") {
                                        expect(subject.presentedViewController).to(beNil())
                                    }
                                }
                            }
                        }

                        describe("for an unread article") {
                            beforeEach {
                                let indexPath = IndexPath(row: 0, section: 1)
                                guard let markRead = subject.tableView(subject.tableView, editActionsForRowAt: indexPath)?.last else {
                                    fail("No mark read edit action")
                                    return
                                }

                                expect(markRead.title).to(equal("Mark\nRead"))
                                markRead.handler?(markRead, indexPath)
                            }

                            it("marks the article as read with the second action item") {
                                guard let call = articleService.markArticleAsReadCalls.last else {
                                    fail("Didn't call ArticleService to mark article as read")
                                    return
                                }
                                expect(call.article) == articles.first
                                expect(call.read) == true
                            }

                            context("when the articleService successfully marks the article as read") {
                                var updatedArticle: Article!
                                beforeEach {
                                    guard let article = articles.first else { fail("No articles - can't happen"); return }
                                    updatedArticle = Article(
                                        title: article.title,
                                        link: article.link,
                                        summary: article.summary,
                                        authors: article.authors,
                                        published: article.published,
                                        updatedAt: article.updatedAt,
                                        identifier: article.identifier,
                                        content: article.content,
                                        read: true,
                                        synced: article.synced,
                                        feed: article.feed,
                                        flags: article.flags
                                    )
                                    articleService.markArticleAsReadPromises.last?.resolve(.success(
                                        updatedArticle
                                        ))
                                }

                                it("Updates the articles in the controller to reflect that") {
                                    expect(subject.articles.first).to(equal(updatedArticle))
                                }
                            }

                            context("when the articleService fails to mark the article as read") {
                                xit("presents a banner indicates that a failure happened") {
                                    fail("Not Implemented")
                                }
                            }
                        }

                        describe("for a read article") {
                            beforeEach {
                                let indexPath = IndexPath(row: 2, section: 1)
                                guard let markRead = subject.tableView(subject.tableView, editActionsForRowAt: indexPath)?.last else {
                                    fail("No mark unread edit action")
                                    return
                                }

                                expect(markRead.title).to(equal("Mark\nUnread"))
                                markRead.handler?(markRead, indexPath)
                            }

                            it("marks the article as unread with the second action item") {
                                guard let call = articleService.markArticleAsReadCalls.last else {
                                    fail("Didn't call ArticleService to mark article as read")
                                    return
                                }
                                expect(call.article) == articles[2]
                                expect(call.read) == false
                            }

                            context("when the articleService successfully marks the article as read") {
                                var updatedArticle: Article!
                                beforeEach {
                                    guard let article = articles.first else { fail("No articles - can't happen"); return }
                                    updatedArticle = Article(
                                        title: article.title,
                                        link: article.link,
                                        summary: article.summary,
                                        authors: article.authors,
                                        published: article.published,
                                        updatedAt: article.updatedAt,
                                        identifier: article.identifier,
                                        content: article.content,
                                        read: false,
                                        synced: article.synced,
                                        feed: article.feed,
                                        flags: article.flags
                                    )
                                    articleService.markArticleAsReadPromises.last?.resolve(.success(
                                        updatedArticle
                                        ))
                                }

                                it("Updates the articles in the controller to reflect that") {
                                    expect(Array(subject.articles)[2]).to(equal(updatedArticle))
                                }
                            }

                            context("when the articleService fails to mark the article as read") {
                                xit("presents a banner indicates that a failure happened") {
                                    fail("Not Implemented")
                                }
                            }
                        }
                    }

                    describe("when tapped") {
                        beforeEach {
                            subject.tableView(subject.tableView, didSelectRowAt: IndexPath(row: 1, section: 1))
                        }

                        it("should navigate to an ArticleViewController") {
                            expect(navigationController.topViewController).to(beAnInstanceOf(ArticleViewController.self))
                            if let articleController = navigationController.topViewController as? ArticleViewController {
                                expect(articleController.article).to(equal(articles[1]))
                            }
                        }
                    }
                }
            }
        }
    }
}
