import Cocoa
import rNewsKit

class FeedsList: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var feeds : [Feed] = []
    
    weak var tableView: NSTableView? = nil {
        didSet {
            tableView?.setDelegate(self)
            tableView?.setDataSource(self)
        }
    }
    
//    var dataManager : DataManager? = nil
    var onFeedSelection : (Feed) -> Void = {(_) in }
    
    override init() {
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reload", name: "UpdatedFeed", object: nil)
    }
    
    func reload() {
        feeds = []
//        feeds = dataManager?.feeds().sorted {(f1: Feed, f2: Feed) in
//            let f1Unread = f1.unreadArticles(self.dataManager!)
//            let f2Unread = f2.unreadArticles(self.dataManager!)
//            if f1Unread != f2Unread {
//                return f1Unread > f2Unread
//            }
//            if f1.title == nil {
//                return true
//            } else if f2.title == nil {
//                return false
//            }
//            return f1.title < f2.title
//        } ?? []
        if feeds.count == 0 {
            
        }
        tableView?.reloadData()
    }
    
    func heightForFeed(feed: Feed, width: CGFloat) -> CGFloat {
        var height : CGFloat = 16.0
        let attributes = [NSFontAttributeName: NSFont.systemFontOfSize(12)]
        let title = NSAttributedString(string: feed.title, attributes: attributes)
        let summary = NSAttributedString(string: feed.summary, attributes: attributes)
        
        let titleBounds = title.boundingRectWithSize(NSMakeSize(width, CGFloat.max), options: NSStringDrawingOptions.UsesFontLeading)
        let summaryBounds = summary.boundingRectWithSize(NSMakeSize(width, CGFloat.max), options: NSStringDrawingOptions.UsesFontLeading)
        
        let titleHeight = ceil(titleBounds.width / width) * ceil(titleBounds.height)
        let summaryHeight = ceil(summaryBounds.width / width) * ceil(summaryBounds.height)
                
        height += titleHeight
        height += summaryHeight
        
        return max(30, height)
    }
    
    // MARK: NSTableViewDelegate
    
    func tableView(tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let feed = feeds[row]
        let feedView = FeedView(frame: NSMakeRect(0, 0, tableView.bounds.width, heightForFeed(feed, width: tableView.bounds.width - 16)))
        feedView.feed = feed
        return feedView
    }
    
    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return heightForFeed(feeds[row], width: tableView.bounds.width - 16)
    }
    
    func tableView(tableView: NSTableView, shouldSelectRow rowIndex: Int) -> Bool {
        onFeedSelection(feeds[rowIndex])
        return false
    }
    
    // MARK: NSTableViewDataSource
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return feeds.count
    }
}
