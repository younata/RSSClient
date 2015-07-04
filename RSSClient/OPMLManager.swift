import Foundation
import Ra

public class OPMLManager: Injectable {

    private let dataRepository: DataRepository
    private let mainQueue: NSOperationQueue
    private let importQueue: NSOperationQueue

    required public init(injector: Injector) {
        dataRepository = injector.create(DataRepository.self) as! DataRepository
        mainQueue = injector.create(kMainQueue) as! NSOperationQueue
        importQueue = injector.create(kBackgroundQueue) as! NSOperationQueue
    }

    public func importOPML(opml: NSURL, completion: ([Feed]) -> Void) {
        do {
            let text = try String(contentsOfURL: opml, encoding: NSUTF8StringEncoding)
            let parser = OPMLParser(text: text)
            parser.success {items in
                var feeds : [Feed] = []

                for item in items {
                    if item.isQueryFeed() {
                        if let title = item.title, let query = item.query {
                            let newFeed = self.dataRepository.synchronousNewFeed()
                            newFeed.title = title
                            newFeed.query = query
                            newFeed.summary = item.summary ?? ""
                            for tag in (item.tags ?? []) {
                                newFeed.addTag(tag)
                            }
                            feeds.append(newFeed)
                        }
                    } else {
                        if let feedURL = item.xmlURL {
                            let newFeed = self.dataRepository.synchronousNewFeed()
                            newFeed.url = NSURL(string: feedURL)
                            for tag in item.tags ?? [] {
                                newFeed.addTag(tag)
                            }
                            feeds.append(newFeed)
                        }
                    }
                }
                self.mainQueue.addOperationWithBlock {
                    completion(feeds)
                }
            }
            parser.failure {error in
                self.mainQueue.addOperationWithBlock {
                    completion([])
                }
            }

            importQueue.addOperation(parser)
        } catch _ {
            completion([])
        }
    }

    private func generateOPMLContents(feeds: [Feed]) -> String {
        func sanitize(str: String?) -> String {
            if str == nil {
                return ""
            }
            var s = str!
            s = s.stringByReplacingOccurrencesOfString("\"", withString: "&quot;")
            s = s.stringByReplacingOccurrencesOfString("'", withString: "&apos;")
            s = s.stringByReplacingOccurrencesOfString("<", withString: "&gt;")
            s = s.stringByReplacingOccurrencesOfString(">", withString: "&lt;")
            s = s.stringByReplacingOccurrencesOfString("&", withString: "&amp;")
            return s
        }

        var ret = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n"
        ret += "<opml version=\"2.0\">\n    <body>\n"
        for feed in feeds.filter({return $0.query == nil}) {
            let title = "title=\"\(sanitize(feed.title))\""
            let url = "xmlUrl=\"\(sanitize(feed.url?.absoluteString))\""
            let tags: String
            if feed.tags.count != 0 {
                let tagsList: String = ",".join(feed.tags)
                tags = "tags=\"\(tagsList)\""
            } else {
                tags = ""
            }
            let line = "<outline \(url) \(title) \(tags) type=\"rss\"/>"
            ret += "        \(line)\n"
        }
        ret += "    </body>\n</opml>"
        return ret
    }

    public func writeOPML() {
        let opmlLocation = documentsDirectory().stringByAppendingPathComponent("rnews.opml")
        dataRepository.feeds {feeds in
            do {
                try self.generateOPMLContents(feeds).writeToFile(opmlLocation, atomically: true,
                    encoding: NSUTF8StringEncoding)
            } catch _ {}
        }
    }
}