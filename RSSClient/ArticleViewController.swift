import UIKit
import WebKit
import TOBrowserActivityKit
import Ra
import rNewsKit

public class ArticleViewController: UIViewController, WKNavigationDelegate {
    public var article: Article? = nil {
        didSet {
            self.navigationController?.setToolbarHidden(false, animated: false)
            if let a = article {
                self.dataWriter?.markArticle(a, asRead: true)
                showArticle(a, onWebView: content)

                self.navigationItem.title = a.title ?? ""

                if userActivity == nil {
                    let activityType = "com.rachelbrindle.rssclient.article"
                    userActivity = NSUserActivity(activityType: activityType)
                    userActivity?.title = NSLocalizedString("Reading Article", comment: "")
                    userActivity?.becomeCurrent()
                }

                userActivity?.userInfo = ["feed": a.feed?.title ?? "",
                                          "article": a.identifier,
                                          "showingContent": true]

                if #available(iOS 9.0, *) {
                    userActivity?.keywords = Set<String>([a.title, a.summary, a.author] + a.flags)
                }

                userActivity?.webpageURL = a.link
                self.userActivity?.needsSave = true
            }
        }
    }

    private enum ArticleContentType {
        case Content;
        case Link;
    }

    public var content = WKWebView(forAutoLayout: ())
    public let loadingBar = UIProgressView(progressViewStyle: .Bar)

    public private(set) lazy var shareButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .Compose, target: self, action: "share")
    }()
    public private(set) lazy var toggleContentButton: UIBarButtonItem = {
        return UIBarButtonItem(title: self.linkString, style: .Plain, target: self, action: "toggleContentLink")
    }()
    private let contentString = NSLocalizedString("Content", comment: "")
    private let linkString = NSLocalizedString("Link", comment: "")

    public var articles: [Article] = []
    public var lastArticleIndex = 0

    public lazy var dataWriter: DataWriter? = {
        return self.injector?.create(DataWriter.self) as? DataWriter
    }()

    public lazy var swipeRight: UIScreenEdgePanGestureRecognizer = {
        return UIScreenEdgePanGestureRecognizer(target: self, action: "next:")
    }()


    private var articleCSS: String {
        if let loc = NSBundle.mainBundle().URLForResource("article", withExtension: "css") {
            do {
                let str = try NSString(contentsOfURL: loc, encoding: NSUTF8StringEncoding)
                return "<html><head><style type=\"text/css\">\(str)</style></head><body>"
            } catch _ {
            }
        }
        return "<html><body>"
    }

    private var contentType: ArticleContentType = .Content {
        didSet {
            if let a = article {
                switch (contentType) {
                case .Content:
                    toggleContentButton.title = linkString
                    let content = a.content ?? a.summary ?? ""
                    self.content.loadHTMLString(articleCSS + content + "</body></html>", baseURL: a.feed?.url)
                case .Link:
                    toggleContentButton.title = contentString
                    self.content.loadRequest(NSURLRequest(URL: a.link!))
                }
                if (a.content ?? a.summary) != nil {
                    self.toolbarItems = [spacer(), shareButton, spacer(), toggleContentButton, spacer()]
                } else {
                    self.toolbarItems = [spacer(), shareButton, spacer()]
                }
            } else {
                self.toolbarItems = []
                self.content.loadHTMLString("", baseURL: nil)
            }
        }
    }

    private func showArticle(article: Article, onWebView webView: WKWebView) {
        let content = article.content.isEmpty ? article.summary : article.content
        if !content.isEmpty {
            let title = "<h2>\(article.title)</h2>"
            webView.loadHTMLString(articleCSS + title + content + "</body></html>", baseURL: article.feed?.url!)
            self.toolbarItems = [spacer(), shareButton, spacer(), toggleContentButton, spacer()]
        } else if let link = article.link {
            webView.loadRequest(NSURLRequest(URL: link))
            self.toolbarItems = [spacer(), shareButton, spacer()]
        }
    }

    private func spacer() -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: "")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.edgesForExtendedLayout = .None
        self.navigationController?.setToolbarHidden(false, animated: true)

        self.view.backgroundColor = UIColor.whiteColor()

        if userActivity == nil {
            userActivity = NSUserActivity(activityType: "com.rachelbrindle.rssclient.article")
            userActivity?.title = NSLocalizedString("Reading Article", comment: "")
            if #available(iOS 9.0, *) {
                userActivity?.eligibleForPublicIndexing = false
                userActivity?.eligibleForSearch = true
            }
            userActivity?.becomeCurrent()
        }

        self.view.addSubview(loadingBar)
        loadingBar.translatesAutoresizingMaskIntoConstraints = false
        loadingBar.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Bottom)
        loadingBar.autoSetDimension(.Height, toSize: 1)
        loadingBar.progressTintColor = UIColor.darkGreenColor()

        self.view.addSubview(content)
        content.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        configureContent()

        let is6Plus = UIScreen.mainScreen().scale == UIScreen.mainScreen().nativeScale &&
                      UIScreen.mainScreen().scale > 2
        let isiPad = UIDevice.currentDevice().userInterfaceIdiom == .Pad
        if let splitView = self.splitViewController where isiPad || is6Plus {
            self.navigationItem.leftBarButtonItem = splitView.displayModeButtonItem()
        }

        let back = UIBarButtonItem(title: "<", style: .Plain, target: content, action: "goBack")
        let forward = UIBarButtonItem(title: ">", style: .Plain, target: content, action: "goForward")
        back.enabled = false
        forward.enabled = false

        self.navigationItem.rightBarButtonItems = [forward, back]
        // share, show (content|link)
        if let a = article {
            if (a.content ?? a.summary) != nil {
                self.toolbarItems = [spacer(), shareButton, spacer(), toggleContentButton, spacer()]
            } else {
                self.toolbarItems = [spacer(), shareButton, spacer()]
            }
        }

        swipeRight.edges = .Right
        self.view.addGestureRecognizer(swipeRight)
    }

    public override func restoreUserActivityState(activity: NSUserActivity) {
        super.restoreUserActivityState(activity)

        if let userInfo = activity.userInfo, let showingContent = userInfo["showingContent"] as? Bool {
            if showingContent {
                self.contentType = .Content
            } else {
                self.contentType = .Link
            }
            if let url = activity.webpageURL {
                self.content.loadRequest(NSURLRequest(URL: url))
            }
        }
    }

    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }

    private var objectsBeingObserved: [WKWebView] = []

    public override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        userActivity?.invalidate()
        userActivity = nil
        for obj in objectsBeingObserved {
            obj.removeObserver(self, forKeyPath: "estimatedProgress")
        }
        objectsBeingObserved = []
    }

    private func removeObserverFromContent(obj: WKWebView) {
        var idx: Int? = nil
        repeat {
            idx = nil
            for (i, x) in objectsBeingObserved.enumerate() {
                if x == obj {
                    idx = i
                    x.removeObserver(self, forKeyPath: "estimatedProgress")
                    break
                }
            }
            if let i = idx {
                objectsBeingObserved.removeAtIndex(i)
            }
        } while idx != nil
    }

    deinit {
        for obj in objectsBeingObserved {
            obj.removeObserver(self, forKeyPath: "estimatedProgress")
        }
        objectsBeingObserved = []
        userActivity?.invalidate()
    }

    private func configureContent() {
        content.navigationDelegate = self
        self.view.bringSubviewToFront(self.loadingBar)
        if let items = self.navigationItem.rightBarButtonItems {
            let forward = items[0]
            let back = items[1]
            forward.enabled = content.canGoForward
            back.enabled = content.canGoBack
        }
    }

    private var nextContent: WKWebView = WKWebView(forAutoLayout: ())
    private var nextContentRight: NSLayoutConstraint! = nil

    private func next(gesture: UIScreenEdgePanGestureRecognizer) {
        if lastArticleIndex + 1 >= articles.count {
            return;
        }
        let width = CGRectGetWidth(self.view.bounds)
        let translation = width + gesture.translationInView(self.view).x
        if gesture.state == .Began {
            let a = articles[lastArticleIndex+1]
            nextContent = WKWebView(forAutoLayout: ())
            self.view.addSubview(nextContent)
            self.showArticle(a, onWebView: nextContent)
            nextContent.autoPinEdgeToSuperviewEdge(.Top)
            nextContent.autoPinEdgeToSuperviewEdge(.Bottom)
            nextContent.autoMatchDimension(.Width, toDimension: .Width, ofView: self.view)
            nextContentRight = nextContent.autoPinEdgeToSuperviewEdge(.Right, withInset: translation)
        } else if gesture.state == .Changed {
            nextContentRight.constant = translation
        } else if gesture.state == .Cancelled {
            nextContent.removeFromSuperview()
            self.removeObserverFromContent(nextContent)
        } else if gesture.state == .Ended {
            let speed = gesture.velocityInView(self.view).x * -1
            if speed >= 0 {
                lastArticleIndex++
                article = articles[lastArticleIndex]
                nextContentRight.constant = 0
                let oldContent = content
                content = nextContent
                configureContent()
                UIView.animateWithDuration(0.2, animations: {
                    self.view.layoutIfNeeded()
                }, completion: {(completed) in
                    self.view.bringSubviewToFront(self.loadingBar)
                    oldContent.removeFromSuperview()
                    self.removeObserverFromContent(oldContent)
                })
            } else {
                nextContent.removeFromSuperview()
                self.removeObserverFromContent(nextContent)
            }
        }
    }

    internal func share() {
        if let link = article?.link {
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

    internal func toggleContentLink() {
        switch (self.contentType) {
        case .Link:
            self.contentType = .Content
            self.userActivity?.userInfo?["showingContent"] = true
        case .Content:
            self.contentType = .Link
            self.userActivity?.userInfo?["showingContent"] = false
        }
        self.userActivity?.needsSave = true
    }

    public override func observeValueForKeyPath(keyPath: String?,
        ofObject object: AnyObject?, change: [String : AnyObject]?,
        context: UnsafeMutablePointer<Void>) {
            if (keyPath == "estimatedProgress" && (object as? NSObject) == content) {
                loadingBar.progress = Float(content.estimatedProgress)
            }
    }

    public func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        loadingBar.hidden = true
        self.removeObserverFromContent(webView)
        if webView.URL?.scheme != "about" {
            userActivity?.webpageURL = webView.URL
        }

        if let items = self.navigationItem.rightBarButtonItems, forward = items.first, back = items.last {
            forward.enabled = content.canGoForward
            back.enabled = content.canGoBack
        }
    }

    public func webView(webView: WKWebView, didFailNavigation _: WKNavigation!, withError _: NSError) {
        loadingBar.hidden = true
        self.removeObserverFromContent(webView)
    }

    public func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loadingBar.progress = 0
        loadingBar.hidden = false
        if !objectsBeingObserved.contains(webView) {
            webView.addObserver(self, forKeyPath: "estimatedProgress", options: .New, context: nil)
            objectsBeingObserved.append(webView)
        }
    }
}
