import UIKit
import rNewsKit
import Ra

public class ArticleListController: UITableViewController, DataSubscriber, Injectable {

    internal var articles = DataStoreBackedArray<Article>()
    public var feed: Feed? {
        didSet {
            self.resetArticles()
            self.resetBarItems()
        }
    }

    public var previewMode: Bool = false

    private let feedRepository: DatabaseUseCase
    private let themeRepository: ThemeRepository
    private let settingsRepository: SettingsRepository
    private let articleViewController: Void -> ArticleViewController

    public lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar(frame: CGRect(x: 0, y: 0, width: 320, height: 32))
        searchBar.autocorrectionType = .No
        searchBar.autocapitalizationType = .None
        searchBar.placeholder = NSLocalizedString("ArticleListController_Search", comment: "")
        searchBar.delegate = self
        return searchBar
    }()

    public init(feedRepository: DatabaseUseCase,
                themeRepository: ThemeRepository,
                settingsRepository: SettingsRepository,
                articleViewController: Void -> ArticleViewController) {
        self.feedRepository = feedRepository
        self.themeRepository = themeRepository
        self.settingsRepository = settingsRepository
        self.articleViewController = articleViewController

        super.init(style: .Plain)
    }

    public required convenience init(injector: Injector) {
        self.init(
            feedRepository: injector.create(DatabaseUseCase)!,
            themeRepository: injector.create(ThemeRepository)!,
            settingsRepository: injector.create(SettingsRepository)!,
            articleViewController: { injector.create(ArticleViewController)! }
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.estimatedRowHeight = 40
        self.tableView.keyboardDismissMode = .OnDrag
        self.tableView.registerClass(ArticleCell.self, forCellReuseIdentifier: "read")
        self.tableView.registerClass(ArticleCell.self, forCellReuseIdentifier: "unread")
        // Prevents a green triangle which'll (dis)appear depending on whether
        // article loaded into it is read or not.

        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.tableFooterView = UIView()

        self.feedRepository.addSubscriber(self)

        self.themeRepository.addSubscriber(self)

        if !self.previewMode {
            self.tableView.tableHeaderView = self.searchBar
            self.navigationItem.rightBarButtonItem = self.editButtonItem()

            if let feed = self.feed {
                self.navigationItem.title = feed.displayTitle
            }

            if self.traitCollection.forceTouchCapability == .Available {
                self.registerForPreviewingWithDelegate(self, sourceView: self.tableView)
            }
            self.resetBarItems()
        }
    }

    public func deletedArticle(article: Article) {}
    public func willUpdateFeeds() {}
    public func didUpdateFeedsProgress(finished: Int, total: Int) {}
    public func didUpdateFeeds(feeds: [Feed]) {}
    public func deletedFeed(feed: Feed, feedsLeft: Int) {}

    public func markedArticles(articles: [Article], asRead read: Bool) {
        let indices = articles.flatMap { self.articles.indexOf($0) }

        let indexPaths = indices.map { NSIndexPath(forRow: $0, inSection: 0) }
        self.tableView.reloadRowsAtIndexPaths(indexPaths, withRowAnimation: .Right)
    }

    private func articleForIndexPath(indexPath: NSIndexPath) -> Article {
        return self.articles[indexPath.row]
    }

    public func showArticle(article: Article, animated: Bool = true) -> ArticleViewController {
        let avc = self.configuredArticleController(article)
        self.showArticleController(avc, animated: animated)
        return avc
    }

    private func configuredArticleController(article: Article, read: Bool = true) -> ArticleViewController {
        let articleViewController = self.articleViewController()
        articleViewController.setArticle(article, read: read)
        return articleViewController
    }

    private func showArticleController(avc: ArticleViewController, animated: Bool) {
        if let splitView = self.splitViewController {
            let delegate = UIApplication.sharedApplication().delegate as? AppDelegate
            delegate?.splitView.collapseDetailViewController = false
            splitView.showDetailViewController(UINavigationController(rootViewController: avc),
                sender: self)
        } else {
            if avc != self.navigationController?.topViewController {
                self.navigationController?.pushViewController(avc, animated: animated)
            }
        }
    }

    // MARK: - Table view data source

    public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.articles.count
    }

    public override func tableView(tableView: UITableView,
        cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
            let article = self.articleForIndexPath(indexPath)
            let cellTypeToUse = (article.read ? "read" : "unread")
            // Prevents a green triangle which'll (dis)appear depending
            // on whether article loaded into it is read or not.
            let cell = tableView.dequeueReusableCellWithIdentifier(cellTypeToUse,
                forIndexPath: indexPath) as! ArticleCell

            cell.themeRepository = self.themeRepository
            cell.settingsRepository = self.settingsRepository
            cell.article = article

        return cell
    }

    public override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)

        if !self.previewMode {
            self.showArticle(self.articleForIndexPath(indexPath))
        }
    }

    public override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return !self.previewMode
    }

    public override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle,
        forRowAtIndexPath indexPath: NSIndexPath) {}

    public override func tableView(tableView: UITableView,
        editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
            if self.previewMode {
                return nil
            }
            let article = self.articleForIndexPath(indexPath)
            let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
            let delete = UITableViewRowAction(style: .Default, title: deleteTitle,
                handler: {(action: UITableViewRowAction!, indexPath: NSIndexPath!) in

                    let confirmDelete = NSLocalizedString("Generic_ConfirmDelete", comment: "")
                    let deleteAlertTitle = NSString.localizedStringWithFormat(confirmDelete, article.title) as String
                    let alert = UIAlertController(title: deleteAlertTitle, message: "", preferredStyle: .Alert)
                    alert.addAction(UIAlertAction(title: deleteTitle, style: .Destructive) { _ in
                        self.articles.remove(article)
                        self.feedRepository.deleteArticle(article)
                        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
                        self.dismissViewControllerAnimated(true, completion: nil)
                    })
                    let cancelTitle = NSLocalizedString("Generic_Cancel", comment: "")
                    alert.addAction(UIAlertAction(title: cancelTitle, style: .Cancel) { _ in
                        tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Right)
                        self.dismissViewControllerAnimated(true, completion: nil)
                    })
                    self.presentViewController(alert, animated: true, completion: nil)
            })
            let unread = NSLocalizedString("ArticleListController_Cell_EditAction_MarkUnread", comment: "")
            let read = NSLocalizedString("ArticleListController_Cell_EditAction_MarkRead", comment: "")
            let toggleText = article.read ? unread : read
            let toggle = UITableViewRowAction(style: .Normal, title: toggleText,
                handler: {(action: UITableViewRowAction!, indexPath: NSIndexPath!) in
                    article.read = !article.read
                    self.feedRepository.markArticle(article, asRead: article.read)
            })
            return [delete, toggle]
    }

    // Mark: Private

    private func resetArticles() {
        guard let articles = self.feed?.articlesArray else { return }
        self.articles = articles
        self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
    }

    private func resetBarItems() {
        guard !self.previewMode else { return }

        var barItems = [self.editButtonItem()]

        if let _ = self.feed {
            let shareSheet = UIBarButtonItem(barButtonSystemItem: .Action,
                                             target: self,
                                             action: #selector(ArticleListController.shareFeed))
            barItems.append(shareSheet)
        }

        self.navigationItem.rightBarButtonItems = barItems
    }

    @objc private func shareFeed() {
        guard let url = self.feed?.url else { return }
        let shareSheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        self.presentViewController(shareSheet, animated: true, completion: nil)
    }
}

extension ArticleListController: UISearchBarDelegate {
    public func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            self.resetArticles()
        } else if let feed = self.feed {
            let articlesArray = self.feedRepository.articlesOfFeed(feed, matchingSearchQuery: searchText)
            if self.articles != articlesArray {
                self.articles = articlesArray
                self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
            }
        }
    }
}

extension ArticleListController: UIViewControllerPreviewingDelegate {
    public func previewingContext(previewingContext: UIViewControllerPreviewing,
        viewControllerForLocation location: CGPoint) -> UIViewController? {
            if let indexPath = self.tableView.indexPathForRowAtPoint(location) where !self.previewMode {
                let article = self.articleForIndexPath(indexPath)
                return self.configuredArticleController(article, read: false)
            }
            return nil
    }

    public func previewingContext(previewingContext: UIViewControllerPreviewing,
        commitViewController viewControllerToCommit: UIViewController) {
            if let articleController = viewControllerToCommit as? ArticleViewController,
                article = articleController.article where !self.previewMode {
                    self.feedRepository.markArticle(article, asRead: true)
                    self.showArticleController(articleController, animated: true)
            }
    }
}

extension ArticleListController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository) {
        self.tableView.backgroundColor = themeRepository.backgroundColor
        self.tableView.separatorColor = themeRepository.textColor
        self.tableView.indicatorStyle = themeRepository.scrollIndicatorStyle

        self.searchBar.backgroundColor = themeRepository.backgroundColor
        self.searchBar.barStyle = themeRepository.barStyle

        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
    }
}
