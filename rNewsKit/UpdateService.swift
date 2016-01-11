import Foundation
import Muon

protocol NetworkClientDelegate: class {
    func didDownloadImage(image: Image, url: NSURL)
    func didDownloadFeed(feed: Muon.Feed, url: NSURL)
    func didDownloadData(data: NSData, url: NSURL)
    func didFailToDownloadDataFromUrl(url: NSURL, error: NSError?)
}

class URLSessionDelegate: NSObject, NSURLSessionDownloadDelegate {
    weak var delegate: NetworkClientDelegate?

    func URLSession(_ : NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL url: NSURL) {
        guard let data = NSData(contentsOfURL: url) else { return }
        let originalUrl = downloadTask.originalRequest?.URL ?? NSURL()
        if downloadTask.response?.MIMEType?.hasPrefix("image") == true, let image = Image(data: data) {
            self.delegate?.didDownloadImage(image, url: originalUrl)
            return
        } else if let str = String(data: data, encoding: NSUTF8StringEncoding) {
            let feedParser = Muon.FeedParser(string: str)
            feedParser.failure { _ in
                self.delegate?.didDownloadData(data, url: originalUrl)
            }
            feedParser.success { feed in
                self.delegate?.didDownloadFeed(feed, url: originalUrl)
            }
            feedParser.start()
            return
        }
        self.delegate?.didDownloadData(data, url: originalUrl)
    }

    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        let url = task.originalRequest?.URL ?? NSURL()
        self.delegate?.didFailToDownloadDataFromUrl(url, error: error)
    }
}

protocol UpdateServiceType: class {
    func updateFeed(feed: Feed, callback: (Feed, NSError?) -> Void)
}

class UpdateService: UpdateServiceType, NetworkClientDelegate {
    private let dataService: DataService
    private let urlSession: NSURLSession

    private var callbacksInProgress: [NSURL: (feed: Feed, callback: ((Feed, NSError?) -> Void))] = [:]

    init(dataService: DataService, urlSession: NSURLSession, urlSessionDelegate: URLSessionDelegate) {
        self.dataService = dataService
        self.urlSession = urlSession
        urlSessionDelegate.delegate = self
    }

    func updateFeed(feed: Feed, callback: (Feed, NSError?) -> Void) {
        guard let url = feed.url else {
            callback(feed, nil)
            return
        }
        self.callbacksInProgress[url] = (feed, callback)
        self.urlSession.downloadTaskWithURL(url).resume()
    }

    // MARK: NetworkClientDelegate

    func didDownloadFeed(muonFeed: Muon.Feed, url: NSURL) {
        guard let feedCallback = self.callbacksInProgress[url] else { return }
        self.callbacksInProgress.removeValueForKey(url)
        let feed = feedCallback.feed
        let callback = feedCallback.callback
        self.dataService.updateFeed(feed, info: muonFeed) {
            if feed.image == nil, let imageUrl = muonFeed.imageURL where !imageUrl.absoluteString.isEmpty {
                self.callbacksInProgress[imageUrl] = feedCallback
                self.urlSession.downloadTaskWithURL(imageUrl).resume()
            } else {
                callback(feed, nil)
            }
        }
    }

    func didDownloadImage(image: Image, url: NSURL) {
        guard let imageCallback = self.callbacksInProgress[url] else { return }
        self.callbacksInProgress.removeValueForKey(url)
        let feed = imageCallback.feed
        let callback = imageCallback.callback
        feed.image = image
        self.dataService.saveFeed(feed) {
            callback(feed, nil)
        }
    }

    func didDownloadData(data: NSData, url: NSURL) {}

    func didFailToDownloadDataFromUrl(url: NSURL, error: NSError?) {
        guard error != nil, let callback = self.callbacksInProgress[url] else { return }
        self.callbacksInProgress.removeValueForKey(url)
        let feed = callback.feed
        let function = callback.callback
        function(feed, error)
    }
}
