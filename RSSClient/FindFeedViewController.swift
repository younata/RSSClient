//
//  FindFeedViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/28/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit
import WebKit

class FindFeedViewController: UIViewController, WKNavigationDelegate, UITextFieldDelegate, MWFeedParserDelegate {
    let webContent = WKWebView(forAutoLayout: ())
    let loadingBar = UIProgressView(progressViewStyle: .Bar)
    let navField = UITextField(frame: CGRectMake(0, 0, 200, 30))
    private var rssLink: String? = nil
    
    var addFeedButton: UIBarButtonItem! = nil
    var back: UIBarButtonItem! = nil
    var forward: UIBarButtonItem! = nil
    
    var feeds: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        webContent.navigationDelegate = self
        self.view.addSubview(webContent)
        webContent.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        
        webContent.addObserver(self, forKeyPath: "estimatedProgress", options: .New, context: nil)
        
        back = UIBarButtonItem(title: "<", style: .Plain, target: webContent, action: "goBack")
        forward = UIBarButtonItem(title: ">", style: .Plain, target: webContent, action: "goForward")
        addFeedButton = UIBarButtonItem(title: NSLocalizedString("Add Feed", comment: ""), style: .Plain, target: self, action: "save")
        back.enabled = false
        forward.enabled = false
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Dismiss", comment: ""), style: .Plain, target: self, action: "dismiss")
        self.navigationItem.rightBarButtonItems = [forward, back]
        
        self.navigationItem.titleView = navField
        navField.delegate = self
        navField.borderStyle = .Bezel
        navField.autocapitalizationType = .None
        navField.keyboardType = .URL
        loadingBar.progress = 0
        
        let navFieldShownString = "findfeedviewcontroller.navfield.shown"
        if (NSUserDefaults.standardUserDefaults().boolForKey(navFieldShownString) == false) {
            let popTip = AMPopTip()
            let popTipText = NSAttributedString(string: NSLocalizedString("Enter the URL for the feed or website here", comment: ""),
                                                attributes: [NSFontAttributeName: UIFont.preferredFontForTextStyle(UIFontTextStyleBody)])
            let width = CGRectGetWidth(self.view.bounds) / 2.0
            let size = popTipText.boundingRectWithSize(CGSizeMake(width, CGFloat.max), options: .UsesFontLeading, context: nil).size
            popTip.showAttributedText(popTipText, direction: AMPopTipDirection.Up, maxWidth: ceil(size.width), inView: self.view, fromFrame: CGRectMake(width, -10, 0, 0))
            NSUserDefaults.standardUserDefaults().setBool(true, forKey: navFieldShownString)
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        feeds = DataManager.sharedInstance().feeds().map({return $0.url;})
    }
    
    deinit {
        webContent.removeObserver(self, forKeyPath: "estimatedProgress")
    }
    
    func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func save() {
        if let rl = rssLink {
            DataManager.sharedInstance().newFeed(rl, withICO: nil)
        }
        dismiss()
    }
    
    override func observeValueForKeyPath(keyPath: String!, ofObject object: AnyObject!, change: [NSObject : AnyObject]!, context: UnsafeMutablePointer<Void>) {
        if (keyPath == "estimatedProgress" && object as NSObject == webContent) {
            loadingBar.progress = Float(webContent.estimatedProgress)
        }
    }
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if !textField.text.lowercaseString.hasPrefix("http") {
            textField.text = "http://\(textField.text)"
        }
        if let url = NSURL.URLWithString(textField.text) {
            self.webContent.loadRequest(NSURLRequest(URL: NSURL(string: textField.text)))
        }
        self.navigationItem.rightBarButtonItems = [self.forward, self.back]
        let feedParser = MWFeedParser(feedURL: NSURL(string: textField.text))
        feedParser.feedParseType = ParseTypeInfoOnly
        feedParser.delegate = self
        feedParser.parse()
        textField.text = ""
        textField.resignFirstResponder()
        
        return true
    }
    
    // MARK: MWFeedParserDelegate
    
    func feedParser(parser: MWFeedParser!, didParseFeedInfo info: MWFeedInfo!) {
        parser.stopParsing()
        if (!contains(feeds, info.url.absoluteString!)) {
            let alert = UIAlertController(title: NSLocalizedString("Feed Detected", comment: ""), message: NSString.localizedStringWithFormat(NSLocalizedString("Save %@?", comment: ""), info.url), preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Don't Save", comment: ""), style: .Cancel, handler: {(alertAction: UIAlertAction!) in
                print("") // this is bullshit
                alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("Save", comment: ""), style: .Default, handler: {(_) in
                alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
                self.dismiss()
            }))
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: WKNavigationDelegate
    
    func webView(webView: WKWebView!, didFinishNavigation navigation: WKNavigation!) {
        self.navigationItem.titleView = self.navField
        self.navField.text = webView.title
        forward.enabled = webView.canGoForward
        back.enabled = webView.canGoBack
        
        let discover = NSString.stringWithContentsOfFile(NSBundle.mainBundle().pathForResource("findFeeds", ofType: "js")!, encoding: NSUTF8StringEncoding, error: nil)
        webView.evaluateJavaScript(discover, completionHandler: {(res: AnyObject!, error: NSError?) in
            if let str = res as? String {
                if (!contains(self.feeds, str)) {
                    self.rssLink = str
                    self.navigationItem.rightBarButtonItems = [self.addFeedButton, self.forward, self.back]
                }
            } else {
                self.rssLink = nil
            }
            if (error != nil) {
                println("Error executing javascript: \(error)")
            }
        })
    }
    
    func webView(webView: WKWebView!, didFailNavigation navigation: WKNavigation!, withError error: NSError!) {
        self.navigationItem.titleView = self.navField
    }
    
    func webView(webView: WKWebView!, didStartProvisionalNavigation navigation: WKNavigation!) {
        println("loading navigation: \(navigation)")
        loadingBar.progress = 0
        self.navigationItem.titleView = loadingBar
    }
}
