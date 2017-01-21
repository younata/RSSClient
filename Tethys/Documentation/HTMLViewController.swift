import UIKit
import PureLayout
import Ra
import WebKit
import SafariServices

public protocol HTMLViewControllerDelegate {
    func openURL(url: URL) -> Bool
    func peekURL(url: URL) -> UIViewController?
    func commitViewController(viewController: UIViewController)
}

public final class HTMLViewController: UIViewController, Injectable {
    public private(set) var htmlString: String?
    // swiftlint:disable weak_delegate
    public var delegate: HTMLViewControllerDelegate?
    // swiftlint:enable weak_delegate

    public func configure(html: String) {
        self.htmlString = html
        self.backgroundSpinnerView.startAnimating()
        self.content.loadHTMLString(html, baseURL: nil)

        var scriptContent = "var meta = document.createElement('meta');"
        scriptContent += "meta.name='viewport';"
        scriptContent += "meta.content='width=device-width';"
        scriptContent += "document.getElementsByTagName('head')[0].appendChild(meta);"

        self.content.evaluateJavaScript(scriptContent, completionHandler: nil)
    }

    public let content = WKWebView(forAutoLayout: ())

    public let themeRepository: ThemeRepository

    public init(themeRepository: ThemeRepository) {
        self.themeRepository = themeRepository
        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            themeRepository: injector.create(kind: ThemeRepository.self)!
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public private(set) lazy var backgroundSpinnerView: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(activityIndicatorStyle: self.themeRepository.spinnerStyle)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

    public private(set) lazy var backgroundView: UIView = {
        let view = UIView(forAutoLayout: ())

        view.addSubview(self.backgroundSpinnerView)
        self.backgroundSpinnerView.autoCenterInSuperview()

        return view
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.content)
        self.view.addSubview(self.backgroundView)
        if let _ = self.htmlString {
            self.backgroundSpinnerView.startAnimating()
        } else {
            self.backgroundSpinnerView.stopAnimating()
        }

        self.content.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .bottom)
        self.view.addConstraint(NSLayoutConstraint(item: self.content, attribute: .bottom, relatedBy: .equal,
                                                   toItem: self.bottomLayoutGuide, attribute: .top,
                                                   multiplier: 1, constant: 0))

        self.content.allowsLinkPreview = true
        self.content.navigationDelegate = self
        self.content.uiDelegate = self
        self.content.isOpaque = false
        self.content.scrollView.scrollIndicatorInsets.bottom = 0
        self.backgroundView.autoPinEdgesToSuperviewEdges()

        self.themeRepository.addSubscriber(self)
    }
}

extension HTMLViewController: WKNavigationDelegate, WKUIDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let request = navigationAction.request
        let navigationType = navigationAction.navigationType
        guard let url = request.url, navigationType == .linkActivated else {
            decisionHandler(.allow)
            return
        }
        if self.delegate?.openURL(url: url) == true {
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.backgroundView.isHidden = self.htmlString != nil
    }

    public func webView(_ webView: WKWebView,
                        previewingViewControllerForElement elementInfo: WKPreviewElementInfo,
                        defaultActions previewActions: [WKPreviewActionItem]) -> UIViewController? {
        guard let url = elementInfo.linkURL else { return nil }
        return self.delegate?.peekURL(url: url)
    }

    public func webView(_ webView: WKWebView,
                        commitPreviewingViewController previewingViewController: UIViewController) {
        self.delegate?.commitViewController(viewController: previewingViewController)
    }
}

extension HTMLViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        if let htmlString = self.htmlString {
            self.configure(html: htmlString)
        }

        self.content.backgroundColor = themeRepository.backgroundColor
        self.content.scrollView.backgroundColor = themeRepository.backgroundColor
        self.content.scrollView.indicatorStyle = themeRepository.scrollIndicatorStyle

        self.view.backgroundColor = themeRepository.backgroundColor
        self.backgroundView.backgroundColor = themeRepository.backgroundColor
        self.backgroundSpinnerView.activityIndicatorViewStyle = themeRepository.spinnerStyle
    }
}
