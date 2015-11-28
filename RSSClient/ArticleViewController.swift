import UIKit
import PureLayout
import TOBrowserActivityKit
import Ra
import rNewsKit
import SafariServices

// swiftlint:disable file_length
// swiftlint:disable type_body_length
// swiftlint:disable function_body_length

public class ArticleViewController: UIViewController {
    public var article: Article? = nil

    public func setArticle(article: Article?, read: Bool = true, show: Bool = true) {
        self.article = article
        self.navigationController?.setToolbarHidden(false, animated: false)
        if let a = article {
            if a.read == false && read {
                self.dataWriter?.markArticle(a, asRead: true)
            }
            if show {
                self.showArticle(a, onWebView: self.content)
            }

            self.toolbarItems = [
                self.spacer(), self.shareButton, self.spacer()
            ]
            if #available(iOS 9, *) {
                if article?.link != nil {
                    self.toolbarItems = [
                        self.spacer(), self.shareButton, self.spacer(), self.openInSafariButton, self.spacer()
                    ]
                }
            }

            self.navigationItem.title = a.title ?? ""

            if self.userActivity == nil {
                let activityType = "com.rachelbrindle.rssclient.article"
                self.userActivity = NSUserActivity(activityType: activityType)

                if #available(iOS 9.0, *) {
                    self.userActivity?.requiredUserInfoKeys = Set(["feed", "article"])
                }

                self.userActivity?.delegate = self

                self.userActivity?.becomeCurrent()
            }

            let userActivityTitle: String
            if let feedTitle = a.feed?.title {
                userActivityTitle = "\(feedTitle): \(a.title)"
            } else {
                userActivityTitle = a.title
            }
            self.userActivity?.title = userActivityTitle

            self.userActivity?.userInfo = [
                "feed": a.feed?.title ?? "",
                "article": a.articleID?.URIRepresentation().absoluteString ?? "",
            ]

            if #available(iOS 9.0, *) {
                self.userActivity?.keywords = Set<String>([a.title, a.summary, a.author] + a.flags)
            }

            self.userActivity?.webpageURL = a.link
            self.userActivity?.needsSave = true
        }
    }

    public var content = UIWebView(forAutoLayout: ())

    public private(set) lazy var shareButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .Compose, target: self, action: "share")
    }()
    public private(set) lazy var openInSafariButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .Action, target: self, action: "openInSafari")
    }()
    private let contentString = NSLocalizedString("ArticleViewController_TabBar_ViewContent", comment: "")
    private let linkString = NSLocalizedString("ArticleViewController_TabBar_ViewLink", comment: "")

    public var articles = CoreDataBackedArray<Article>()
    public var lastArticleIndex = 0

    public lazy var dataWriter: DataWriter? = {
        return self.injector?.create(DataWriter.self) as? DataWriter
    }()

    public lazy var themeRepository: ThemeRepository? = {
        return self.injector?.create(ThemeRepository.self) as? ThemeRepository
    }()

    public lazy var urlOpener: UrlOpener? = {
        return self.injector?.create(UrlOpener.self) as? UrlOpener
    }()

    public lazy var panGestureRecognizer: ScreenEdgePanGestureRecognizer = {
        return ScreenEdgePanGestureRecognizer(target: self, action: "didSwipe:")
    }()

    private func loadArticleCSS() -> String {
        if let cssFileName = self.themeRepository?.articleCSSFileName,
            let loc = NSBundle.mainBundle().URLForResource(cssFileName, withExtension: "css"),
            let cssNSString = try? NSString(contentsOfURL: loc, encoding: NSUTF8StringEncoding) {
                return "<html><head><style type=\"text/css\">\(String(cssNSString))</style></head><body>"
        }
        return "<html><body>"
    }

    private lazy var articleCSS: String = {
        return self.loadArticleCSS()
    }()

    private lazy var prismJS: String = {
        if let loc = NSBundle.mainBundle().URLForResource("prism.js", withExtension: "html"),
            let prismJS = try? NSString(contentsOfURL: loc, encoding: NSUTF8StringEncoding) as String {
                return prismJS
        }
        return ""
    }()

    private func showArticle(article: Article, onWebView webView: UIWebView) {
        let content = article.content.isEmpty ? article.summary : article.content
        let title = "<h2>\(article.title)</h2>"
        let htmlString = self.articleCSS + title + content + self.prismJS + "</body></html>"
        webView.loadHTMLString(htmlString, baseURL: article.link)
    }

    private func spacer() -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: "")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.edgesForExtendedLayout = .None
        self.navigationController?.setToolbarHidden(false, animated: true)

        self.view.backgroundColor = UIColor.whiteColor()

        if self.userActivity == nil {
            self.userActivity = NSUserActivity(activityType: "com.rachelbrindle.rssclient.article")
            if #available(iOS 9.0, *) {
                self.userActivity?.requiredUserInfoKeys = Set(["feed", "article"])
                self.userActivity?.eligibleForPublicIndexing = false
                self.userActivity?.eligibleForSearch = true
            }
            self.userActivity?.delegate = self
            self.userActivity?.becomeCurrent()
        }

        self.view.addSubview(self.content)
        self.content.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        self.configureContent()

        self.updateLeftBarButtonItem(self.traitCollection)

        self.view.addGestureRecognizer(self.panGestureRecognizer)

        self.themeRepository?.addSubscriber(self)
    }

    public override func restoreUserActivityState(activity: NSUserActivity) {
        super.restoreUserActivityState(activity)
    }

    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }

    public override func canBecomeFirstResponder() -> Bool {
        return true
    }

    public override var keyCommands: [UIKeyCommand]? {
        let addTitleToCmd: (UIKeyCommand, String) -> (Void) = {cmd, title in
            if #available(iOS 9.0, *) {
                cmd.discoverabilityTitle = title
            }
        }

        var commands: [UIKeyCommand] = []
        if self.lastArticleIndex != 0 {
            let cmd = UIKeyCommand(input: "p", modifierFlags: .Control, action: "showPreviousArticle")
            addTitleToCmd(cmd, NSLocalizedString("ArticleViewController_Command_ViewPreviousArticle", comment: ""))
            commands.append(cmd)
        }

        if self.lastArticleIndex < (self.articles.count - 1) {
            let cmd = UIKeyCommand(input: "n", modifierFlags: .Control, action: "showNextArticle")
            addTitleToCmd(cmd, NSLocalizedString("ArticleViewController_Command_ViewNextArticle", comment: ""))
            commands.append(cmd)
        }

        let markAsRead = UIKeyCommand(input: "r", modifierFlags: .Shift, action: "toggleArticleRead")
        addTitleToCmd(markAsRead, NSLocalizedString("ArticleViewController_Command_ToggleRead", comment: ""))
        commands.append(markAsRead)

        if let _ = self.article?.link {
            let cmd = UIKeyCommand(input: "l", modifierFlags: .Command, action: "openInSafari")
            addTitleToCmd(cmd, NSLocalizedString("ArticleViewController_Command_OpenInWebView", comment: ""))
            commands.append(cmd)
        }

        let showShareSheet = UIKeyCommand(input: "s", modifierFlags: .Command, action: "share")
        addTitleToCmd(showShareSheet, NSLocalizedString("ArticleViewController_Command_OpenShareSheet", comment: ""))
        commands.append(showShareSheet)

        return commands
    }

    @objc private func showPreviousArticle() {
        guard self.lastArticleIndex > 0 else {
            return
        }
        self.lastArticleIndex--
        self.setArticle(self.articles[lastArticleIndex])
        if let article = self.article {
            self.showArticle(article, onWebView: self.content)
        }
    }

    @objc private func showNextArticle() {
        guard self.lastArticleIndex < self.articles.count else {
            return
        }
        self.lastArticleIndex++
        self.setArticle(self.articles[lastArticleIndex])
        if let article = self.article {
            self.showArticle(article, onWebView: self.content)
        }
    }

    @objc private func toggleArticleRead() {
        guard let article = self.article else {
            return
        }
        self.dataWriter?.markArticle(article, asRead: !article.read)
    }

    public override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.userActivity?.invalidate()
        self.userActivity = nil
    }

    deinit {
        self.userActivity?.invalidate()
    }

    private func configureContent() {
        self.content.delegate = self
    }

    private var nextContent: UIWebView? = nil
    private var nextContentRight: NSLayoutConstraint? = nil

    private func didSwipeFromLeft(gesture: ScreenEdgePanGestureRecognizer) {
        if self.lastArticleIndex == 0 {
            return
        }
        let width = self.view.bounds.width
        let translation = -width + gesture.translationInView(self.view).x
        let nextArticleIndex = self.lastArticleIndex - 1
        if gesture.state == .Began {
            let a = self.articles[nextArticleIndex]
            self.nextContent = UIWebView(forAutoLayout: ())
            self.nextContent?.backgroundColor = self.themeRepository?.backgroundColor
            self.view.addSubview(self.nextContent!)
            self.showArticle(a, onWebView: self.nextContent!)
            self.nextContent?.autoPinEdgeToSuperviewEdge(.Top)
            self.nextContent?.autoPinEdgeToSuperviewEdge(.Bottom)
            self.nextContent?.autoMatchDimension(.Width, toDimension: .Width, ofView: self.view)
            self.nextContentRight = self.nextContent!.autoPinEdgeToSuperviewEdge(.Leading, withInset: translation)
        } else if gesture.state == .Changed {
            self.nextContentRight?.constant = translation
        } else if gesture.state == .Cancelled {
            self.nextContent?.removeFromSuperview()
            self.nextContent = nil
        } else if gesture.state == .Ended {
            let speed = gesture.velocityInView(self.view).x
            if speed >= 0 {
                self.lastArticleIndex = nextArticleIndex
                self.setArticle(self.articles[self.lastArticleIndex], show: false)
                self.nextContentRight?.constant = 0
                let oldContent = content
                if let nextContent = self.nextContent {
                    self.content = nextContent
                }
                self.configureContent()
                UIView.animateWithDuration(0.2, animations: {
                    self.view.layoutIfNeeded()
                    }, completion: {(completed) in
                        oldContent.removeFromSuperview()
                })
            } else {
                self.nextContent?.removeFromSuperview()
                self.nextContent = nil
            }
        }
    }

    private func didSwipeFromRight(gesture: ScreenEdgePanGestureRecognizer) {
        if self.lastArticleIndex + 1 >= self.articles.count {
            return
        }
        let width = CGRectGetWidth(self.view.bounds)
        let translation = width + gesture.translationInView(self.view).x
        let nextArticleIndex = self.lastArticleIndex + 1
        if gesture.state == .Began {
            let a = self.articles[nextArticleIndex]
            self.nextContent = UIWebView(forAutoLayout: ())
            self.nextContent?.backgroundColor = self.themeRepository?.backgroundColor
            self.view.addSubview(self.nextContent!)
            self.showArticle(a, onWebView: self.nextContent!)
            self.nextContent?.autoPinEdgeToSuperviewEdge(.Top)
            self.nextContent?.autoPinEdgeToSuperviewEdge(.Bottom)
            self.nextContent?.autoMatchDimension(.Width, toDimension: .Width, ofView: self.view)
            self.nextContentRight = self.nextContent!.autoPinEdgeToSuperviewEdge(.Trailing, withInset: translation)
        } else if gesture.state == .Changed {
            self.nextContentRight?.constant = translation
        } else if gesture.state == .Cancelled {
            self.nextContent?.removeFromSuperview()
            self.nextContent = nil
        } else if gesture.state == .Ended {
            let speed = gesture.velocityInView(self.view).x * -1
            if speed >= 0 {
                self.lastArticleIndex = nextArticleIndex
                self.setArticle(self.articles[self.lastArticleIndex], show: false)
                self.nextContentRight?.constant = 0
                let oldContent = content
                if let nextContent = self.nextContent {
                    self.content = nextContent
                }
                self.configureContent()
                UIView.animateWithDuration(0.2, animations: {
                    self.view.layoutIfNeeded()
                    }, completion: {(completed) in
                        oldContent.removeFromSuperview()
                })
            } else {
                self.nextContent?.removeFromSuperview()
                self.nextContent = nil
            }
        }
    }

    @objc private func didSwipe(gesture: ScreenEdgePanGestureRecognizer) {
        switch gesture.startDirection {
        case .None:
            return
        case .Left:
            self.didSwipeFromLeft(gesture)
        case .Right:
            self.didSwipeFromRight(gesture)
        }
    }

    @objc private func share() {
        if let link = self.article?.link {
            let safari = TOActivitySafari()
            let chrome = TOActivityChrome()

            let activity = UIActivityViewController(activityItems: [link],
                applicationActivities: [safari, chrome])
            if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
                let popover = UIPopoverController(contentViewController: activity)
                popover.presentPopoverFromBarButtonItem(shareButton, permittedArrowDirections: .Any, animated: true)
            } else {
                self.presentViewController(activity, animated: true, completion: nil)
            }
        }
    }

    @objc private func openInSafari() {
        guard let url = self.article?.link else { return }
        if #available(iOS 9, *) {
            self.loadUrlInSafari(url)
        } else {
            self.urlOpener?.openURL(url)
        }
    }

    private func loadUrlInSafari(url: NSURL) {
        guard #available(iOS 9, *) else { return }

        let safari = SFSafariViewController(URL: url)
        self.presentViewController(safari, animated: true, completion: nil)
    }
}

extension ArticleViewController {
    private func updateLeftBarButtonItem(traitCollection: UITraitCollection) {
        if traitCollection.horizontalSizeClass == .Regular {
            self.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem()
        } else {
            self.navigationItem.leftBarButtonItem = nil
        }
    }

    public override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.updateLeftBarButtonItem(self.traitCollection)
    }
}

extension ArticleViewController: UIWebViewDelegate {
    public func webView(webView: UIWebView,
        shouldStartLoadWithRequest request: NSURLRequest,
        navigationType: UIWebViewNavigationType) -> Bool {
            guard let url = request.URL where navigationType == .LinkClicked else { return true }

            if #available(iOS 9, *) {
                self.loadUrlInSafari(url)
            } else {
                self.urlOpener?.openURL(url)
            }

            return false
    }
}

extension ArticleViewController: NSUserActivityDelegate {
    public func userActivityWillSave(userActivity: NSUserActivity) {
        if let a = self.article {
            userActivity.userInfo = [
                "feed": a.feed?.title ?? "",
                "article": a.articleID?.URIRepresentation().absoluteString ?? "",
            ]
        }
    }
}

extension ArticleViewController: ThemeRepositorySubscriber {
    public func didChangeTheme() {
        self.articleCSS = self.loadArticleCSS()
        self.content.reload()
        self.nextContent?.reload()

        self.content.backgroundColor = self.themeRepository?.backgroundColor
        self.nextContent?.backgroundColor = self.themeRepository?.backgroundColor

        if let themeRepository = self.themeRepository {
            self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
            self.navigationController?.toolbar.barStyle = themeRepository.barStyle
        }
    }
}
