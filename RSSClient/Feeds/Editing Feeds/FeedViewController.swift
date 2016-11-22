import UIKit
import Muon
import Ra
import rNewsKit

public final class FeedViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, Injectable {
    public var feed: rNewsKit.Feed? = nil {
        didSet {
            self.navigationItem.title = self.feed?.displayTitle ?? ""
            self.feedURL = feed?.url
            self.tableView.reloadData()
        }
    }

    private enum FeedSections: Int {
        case title = 0
        case url = 1
        case summary = 2
        case tags = 3

        var titleForSection: String {
            switch self {
            case .title:
                return NSLocalizedString("FeedViewController_Table_Header_Title", comment: "")
            case .url:
                return NSLocalizedString("FeedViewController_Table_Header_URL", comment: "")
            case .summary:
                return NSLocalizedString("FeedViewController_Table_Header_Summary", comment: "")
            case .tags:
                return NSLocalizedString("FeedViewController_Table_Header_Tags", comment: "")
            }
        }
    }

    public lazy var tableView: UITableView = {
        let tableView = UITableView(forAutoLayout: ())
        tableView.register(TableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(TextFieldCell.self, forCellReuseIdentifier: "text")
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        return tableView
    }()

    private var feedURL: URL? = nil

    private let feedRepository: DatabaseUseCase
    private let urlSession: URLSession
    private let themeRepository: ThemeRepository
    private let tagEditorViewController: (Void) -> TagEditorViewController

    private let intervalFormatter = DateIntervalFormatter()

    public init(feedRepository: DatabaseUseCase,
                urlSession: URLSession,
                themeRepository: ThemeRepository,
                tagEditorViewController: @escaping (Void) -> TagEditorViewController) {
        self.feedRepository = feedRepository
        self.urlSession = urlSession
        self.themeRepository = themeRepository
        self.tagEditorViewController = tagEditorViewController

        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            feedRepository: injector.create(kind: DatabaseUseCase.self)!,
            urlSession: injector.create(kind: URLSession.self)!,
            themeRepository: injector.create(kind: ThemeRepository.self)!,
            tagEditorViewController: {injector.create(kind: TagEditorViewController.self)!}
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        let dismissTitle = NSLocalizedString("Generic_Dismiss", comment: "")
        let dismissButton = UIBarButtonItem(title: dismissTitle, style: .plain, target: self,
                                            action: #selector(FeedViewController.dismissFromNavigation))
        self.navigationItem.leftBarButtonItem = dismissButton

        let saveTitle = NSLocalizedString("Generic_Save", comment: "")
        let saveButton = UIBarButtonItem(title: saveTitle, style: .plain, target: self, action:

            #selector(FeedViewController.save))
        self.navigationItem.rightBarButtonItem = saveButton
        self.navigationItem.title = self.feed?.displayTitle ?? ""

        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero)

        self.intervalFormatter.calendar = NSCalendar.current
        self.intervalFormatter.dateStyle = .medium
        self.intervalFormatter.timeStyle = .short

        self.themeRepository.addSubscriber(self)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }

    @objc fileprivate func dismissFromNavigation() {
        self.navigationController?.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    @objc fileprivate func save() {
        if let theFeed = self.feed {
            if let theFeedURL = self.feedURL, theFeedURL != theFeed.url {
                theFeed.url = theFeedURL
            }
            _ = self.feedRepository.saveFeed(theFeed)
        }
        self.dismissFromNavigation()
    }

    private func showTagEditor(_ tagIndex: Int) -> TagEditorViewController {
        let tagEditorViewController = self.tagEditorViewController()
        tagEditorViewController.feed = self.feed
        if tagIndex < (self.feed?.tags.count ?? 0) {
            tagEditorViewController.tagIndex = tagIndex
            tagEditorViewController.tagPicker.textField.text = self.feed?.tags[tagIndex]
        }
        self.navigationController?.pushViewController(tagEditorViewController, animated: true)
        return tagEditorViewController
    }

    // MARK: - Table view data source

    public func numberOfSections(in tableView: UITableView) -> Int {
        let numSection = 4
        return (feed == nil ? 0 : numSection)
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection sectionNum: Int) -> Int {
        if feed == nil {
            return 0
        }
        if let section = FeedSections(rawValue: sectionNum), section == .tags {
            return feed!.tags.count + 1
        }
        return 1
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection sectionNum: Int) -> String? {
        if let section = FeedSections(rawValue: sectionNum) {
            return section.titleForSection
        }
        return nil
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = FeedSections(rawValue: (indexPath as NSIndexPath).section) ?? .title
        switch section {
        case .title:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
            cell.textLabel?.text = ""
            cell.themeRepository = self.themeRepository
            if let title = feed?.displayTitle, !title.isEmpty {
                cell.textLabel?.text = title
            }
            return cell
        case .url:
            return self.textFieldCell(indexPath)
        case .summary:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
            cell.textLabel?.text = ""
            cell.themeRepository = self.themeRepository
            if let summary = feed?.displaySummary, !summary.isEmpty {
                cell.textLabel?.text = summary
            } else {
                cell.textLabel?.text = NSLocalizedString("FeedViewController_Cell_Summary_Placeholder", comment: "")
                cell.textLabel?.textColor = UIColor.gray
            }
            return cell
        case .tags:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
            cell.textLabel?.text = ""
            cell.themeRepository = self.themeRepository
            if let tags = feed?.tags {
                if indexPath.row == tags.count {
                    cell.textLabel?.text = NSLocalizedString("FeedViewController_Cell_AddTag", comment: "")
                    cell.textLabel?.textColor = UIColor.darkGreen()
                } else {
                    cell.textLabel?.text = tags[indexPath.row]
                }
            }
            return cell
        }
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let isTagsSection = FeedSections(rawValue: (indexPath as NSIndexPath).section) == .tags
        let isEditableTag = indexPath.row != (tableView.numberOfRows(inSection: FeedSections.tags.rawValue) - 1)

        return isTagsSection && isEditableTag
    }

    public func tableView(_ tableView: UITableView,
        editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
            if feed == nil || FeedSections(rawValue: indexPath.section) != .tags {
                return nil
            }
            let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
            let delete = UITableViewRowAction(style: .default, title: deleteTitle, handler: {(_, indexPath) in
                if let feed = self.feed {
                    let tag = feed.tags[indexPath.row]
                    feed.removeTag(tag)
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                    if tag.hasPrefix("~") {
                        let indexPath = IndexPath(row: 0, section: 0)
                        tableView.reloadRows(at: [indexPath], with: .none)
                    } else if tag.hasPrefix("`") {
                        let indexPath = IndexPath(row: 0, section: 1)
                        tableView.reloadRows(at: [indexPath], with: .none)
                    }
                }
            })
            let editTitle = NSLocalizedString("Generic_Edit", comment: "")
            let edit = UITableViewRowAction(style: .normal, title: editTitle, handler: {(_, indexPath) in
                _ = self.showTagEditor(indexPath.row)
            })
            return [delete, edit]
    }

    public func tableView(_ tableView: UITableView,
        commit _: UITableViewCellEditingStyle,
        forRowAt _: IndexPath) {}

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        if FeedSections(rawValue: indexPath.section) == .tags,
            let count = feed?.tags.count,
            indexPath.row == count {
                _ = showTagEditor(indexPath.row)
        }
    }

    private func textFieldCell(_ indexPath: IndexPath) -> TextFieldCell {
        let tc = tableView.dequeueReusableCell(withIdentifier: "text", for: indexPath) as! TextFieldCell
        tc.onTextChange = {(_) in } // remove any previous onTextChange for setting stuff here.
        tc.themeRepository = self.themeRepository
        tc.textField.text = self.feed?.url.absoluteString
        tc.showValidator = true
        if #available(iOS 10.0, *) {
            tc.textField.textContentType = .URL
        }
        tc.textField.returnKeyType = .done
        tc.onTextChange = {(text) in
            if let txt = text, let url = URL(string: txt) {
                self.urlSession.dataTask(with: url) {data, response, error in
                    if let response = response as? HTTPURLResponse {
                        if let data = data,
                            let nstext = NSString(data: data, encoding: String.Encoding.utf8.rawValue),
                            response.statusCode == 200 {
                                let string = String(nstext)
                                let fp = Muon.FeedParser(string: string)
                                _ = fp.failure {_ in tc.setValid(false) }
                                _ = fp.success {_ in
                                    tc.setValid(true)
                                    self.feedURL = url
                                }
                                fp.start()
                        } else { tc.setValid(false) }
                    } else { tc.setValid(false) }
                }.resume()
            }
            return
        }
        return tc
    }
}

extension FeedViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.tableView.backgroundColor = themeRepository.backgroundColor
        self.tableView.separatorColor = themeRepository.textColor
        self.tableView.indicatorStyle = themeRepository.scrollIndicatorStyle

        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
        self.navigationController?.navigationBar.titleTextAttributes = [
            NSForegroundColorAttributeName: themeRepository.textColor
        ]
    }
}
