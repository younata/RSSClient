import UIKit
import Muon
import rNewsKit

public class FeedViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    public var feed: rNewsKit.Feed? = nil {
        didSet {
            self.navigationItem.title = self.feed?.displayTitle ?? ""
            self.tableView.reloadData()
        }
    }

    private enum FeedSections: Int {
        case Title = 0
        case URL = 1
        case Summary = 2
        case Tags = 3

        var titleForSection: String {
            switch self {
            case .Title:
                return NSLocalizedString("Title", comment: "")
            case .URL:
                return NSLocalizedString("URL", comment: "")
            case .Summary:
                return NSLocalizedString("Summary", comment: "")
            case .Tags:
                return NSLocalizedString("Tags", comment: "")
            }
        }
    }

    public lazy var tableView: UITableView = {
        let tableView = UITableView(forAutoLayout: ())
        tableView.registerClass(TableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.registerClass(TextFieldCell.self, forCellReuseIdentifier: "text")
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        return tableView
    }()

    private lazy var dataWriter: DataWriter? = {
        return self.injector?.create(DataWriter.self) as? DataWriter
    }()

    private lazy var urlSession: NSURLSession = {
        return self.injector!.create(NSURLSession.self) as! NSURLSession
    }()

    private lazy var operationQueue: NSOperationQueue = {
        return self.injector!.create(kBackgroundQueue) as! NSOperationQueue
    }()

    private lazy var themeRepository: ThemeRepository = {
        return self.injector!.create(ThemeRepository.self) as! ThemeRepository
    }()

    private let intervalFormatter = NSDateIntervalFormatter()

    public override func viewDidLoad() {
        super.viewDidLoad()

        let dismissTitle = NSLocalizedString("Dismiss", comment: "")
        let dismissButton = UIBarButtonItem(title: dismissTitle, style: .Plain, target: self, action: "dismiss")
        self.navigationItem.leftBarButtonItem = dismissButton

        let saveTitle = NSLocalizedString("Save", comment: "")
        let saveButton = UIBarButtonItem(title: saveTitle, style: .Plain, target: self, action: "save")
        self.navigationItem.rightBarButtonItem = saveButton
        self.navigationItem.title = self.feed?.displayTitle ?? ""

        self.view.addSubview(tableView)
        tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)

        self.intervalFormatter.calendar = NSCalendar.currentCalendar()
        self.intervalFormatter.dateStyle = .MediumStyle
        self.intervalFormatter.timeStyle = .ShortStyle

        self.themeRepository.addSubscriber(self)
    }

    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    internal func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    internal func save() {
        if let theFeed = feed {
            dataWriter?.saveFeed(theFeed)
        }
        dismiss()
    }

    private func showTagEditor(tagIndex: Int) -> TagEditorViewController {
        let tagEditor = self.injector!.create(TagEditorViewController.self) as! TagEditorViewController
        tagEditor.feed = self.feed
        if tagIndex < self.feed?.tags.count {
            tagEditor.tagIndex = tagIndex
            tagEditor.tagPicker.textField.text = self.feed?.tags[tagIndex]
        }
        self.navigationController?.pushViewController(tagEditor, animated: true)
        return tagEditor
    }

    // MARK: - Table view data source

    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        let numSection = 4
        return (feed == nil ? 0 : numSection)
    }

    public func tableView(tableView: UITableView, numberOfRowsInSection sectionNum: Int) -> Int {
        if feed == nil {
            return 0
        }
        if let section = FeedSections(rawValue: sectionNum) where section == .Tags {
            return feed!.tags.count + 1
        }
        return 1
    }

    public func tableView(tableView: UITableView, titleForHeaderInSection sectionNum: Int) -> String? {
        if let section = FeedSections(rawValue: sectionNum) {
            return section.titleForSection
        }
        return nil
    }

    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let section = FeedSections(rawValue: indexPath.section) ?? .Title

        switch (section) {
        case .Title:
            let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! TableViewCell
            cell.textLabel?.text = ""
            cell.themeRepository = self.themeRepository
            if let title = feed?.tags.filter({$0.hasPrefix("~")}).first {
                cell.textLabel?.text = title.substringFromIndex(title.startIndex.successor())
            } else if let title = feed?.displayTitle where !title.isEmpty {
                cell.textLabel?.text = title
            }
            return cell
        case .URL:
            let tc = tableView.dequeueReusableCellWithIdentifier("text", forIndexPath: indexPath) as! TextFieldCell
            tc.onTextChange = {(_) in } // remove any previous onTextChange for setting stuff here.
            tc.themeRepository = self.themeRepository
            tc.textField.text = self.feed?.url?.absoluteString
            tc.showValidator = true
            tc.onTextChange = {(text) in
                if let txt = text, url = NSURL(string: txt) {
                    self.urlSession.dataTaskWithURL(url) {data, response, error in
                        if let response = response as? NSHTTPURLResponse {
                            if let data = data,
                               let nstext = NSString(data: data, encoding: NSUTF8StringEncoding) where response.statusCode == 200 {
                                let string = String(nstext)
                                let fp = Muon.FeedParser(string: string)
                                fp.failure {_ in
                                    tc.setValid(false)
                                }
                                fp.success {_ in
                                    tc.setValid(true)
                                }
                                self.operationQueue.addOperation(fp)
                            } else {
                                tc.setValid(false)
                            }
                        } else {
                            tc.setValid(false)
                        }
                    }.resume()
                }
                return
            }
            return tc
        case .Summary:
            let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! TableViewCell
            cell.textLabel?.text = ""
            cell.themeRepository = self.themeRepository
            if let summary = feed?.tags.filter({$0.hasPrefix("`")}).first {
                cell.textLabel?.text = summary.substringFromIndex(summary.startIndex.successor())
            } else if let summary = feed?.displaySummary where !summary.isEmpty  {
                cell.textLabel?.text = summary
            } else {
                cell.textLabel?.text = NSLocalizedString("No summary available", comment: "")
                cell.textLabel?.textColor = UIColor.grayColor()
            }
            return cell
        case .Tags:
            let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! TableViewCell
            cell.textLabel?.text = ""
            cell.themeRepository = self.themeRepository
            if let tags = feed?.tags {
                if indexPath.row == tags.count {
                    cell.textLabel?.text = NSLocalizedString("Add Tag", comment: "")
                    cell.textLabel?.textColor = UIColor.darkGreenColor()
                } else {
                    cell.textLabel?.text = tags[indexPath.row]
                }
            }
            return cell
        }
    }

    public func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        let isTagsSection = FeedSections(rawValue: indexPath.section) == .Tags
        let isEditableTag = indexPath.row != (tableView.numberOfRowsInSection(FeedSections.Tags.rawValue) - 1)

        return isTagsSection && isEditableTag
    }

    public func tableView(tableView: UITableView,
        editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
            if feed == nil || FeedSections(rawValue: indexPath.section) != .Tags {
                return nil
            }
            let deleteTitle = NSLocalizedString("Delete", comment: "")
            let delete = UITableViewRowAction(style: .Default, title: deleteTitle, handler: {(_, indexPath) in
                if let feed = self.feed {
                    let tag = feed.tags[indexPath.row]
                    feed.removeTag(tag)
                    tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
                    if tag.hasPrefix("~") {
                        let indexPath = NSIndexPath(forRow: 0, inSection: 0)
                        tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
                    } else if tag.hasPrefix("`") {
                        let indexPath = NSIndexPath(forRow: 0, inSection: 1)
                        tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
                    }
                }
            })
            let editTitle = NSLocalizedString("Edit", comment: "")
            let edit = UITableViewRowAction(style: .Normal, title: editTitle, handler: {(_, indexPath) in
                self.showTagEditor(indexPath.row)
            })
            return [delete, edit]
    }

    public func tableView(tableView: UITableView,
        commitEditingStyle _: UITableViewCellEditingStyle,
        forRowAtIndexPath _: NSIndexPath) {}

    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)

        if FeedSections(rawValue: indexPath.section) == .Tags,
            let count = feed?.tags.count where indexPath.row == count {
                showTagEditor(indexPath.row)
        }
    }
}

extension FeedViewController: ThemeRepositorySubscriber {
    public func didChangeTheme() {
        self.tableView.backgroundColor = self.themeRepository.backgroundColor
        self.tableView.separatorColor = self.themeRepository.textColor

        self.navigationController?.navigationBar.barStyle = self.themeRepository.barStyle
    }
}
