import UIKit
import PureLayout
import SafariServices
import Ra
import Result
import rNewsKit

// swiftlint:disable file_length

extension Account: CustomStringConvertible {
    public var description: String {
        switch self {
        case .Pasiphae:
            return NSLocalizedString("SettingsViewController_Accounts_Pasiphae", comment: "")
        }
    }
}

public final class SettingsViewController: UIViewController, Injectable {
    fileprivate enum SettingsSection: CustomStringConvertible {
        case theme
        case quickActions
        case accounts
        case advanced
        case credits

        fileprivate init?(rawValue: Int, traits: UITraitCollection) {
            if rawValue == 0 {
                self = .theme
                return
            } else {
                let offset: Int
                switch traits.forceTouchCapability {
                case .available:
                    offset = 0
                case .unavailable, .unknown:
                    offset = 1
                }
                switch rawValue + offset {
                case 1:
                    self = .quickActions
                case 2:
                    self = .accounts
                case 3:
                    self = .advanced
                case 4:
                    self = .credits
                default:
                    return nil
                }
            }
        }

        static func numberOfSettings(_ traits: UITraitCollection) -> Int {
            if traits.forceTouchCapability == .available {
                return 5
            }
            return 4
        }

        fileprivate var rawValue: Int {
            switch self {
            case .theme: return 0
            case .quickActions: return 1
            case .accounts: return 2
            case .advanced: return 3
            case .credits: return 4
            }
        }

        fileprivate var description: String {
            switch self {
            case .theme:
                return NSLocalizedString("SettingsViewController_Table_Header_Theme", comment: "")
            case .quickActions:
                return NSLocalizedString("SettingsViewController_Table_Header_QuickActions", comment: "")
            case .accounts:
                return NSLocalizedString("SettinsgViewController_Table_Header_Accounts", comment: "")
            case .advanced:
                return NSLocalizedString("SettingsViewController_Table_Header_Advanced", comment: "")
            case .credits:
                return NSLocalizedString("SettingsViewController_Table_Header_Credits", comment: "")
            }
        }
    }

    fileprivate enum AdvancedSection: Int, CustomStringConvertible {
        case showReadingTimes = 0

        fileprivate var description: String {
            switch self {
            case .showReadingTimes:
                return NSLocalizedString("SettingsViewController_Advanced_ShowReadingTimes", comment: "")
            }
        }

        fileprivate static let numberOfOptions = 1
    }

    public let tableView = UITableView(frame: CGRect.zero, style: .grouped)

    fileprivate let themeRepository: ThemeRepository
    fileprivate let settingsRepository: SettingsRepository
    fileprivate let quickActionRepository: QuickActionRepository
    fileprivate let databaseUseCase: DatabaseUseCase
    fileprivate let accountRepository: AccountRepository
    fileprivate let loginViewController: (Void) -> LoginViewController

    fileprivate var oldTheme: ThemeRepository.Theme = .default

    fileprivate lazy var showReadingTimes: Bool = {
        return self.settingsRepository.showEstimatedReadingLabel
    }()

    // swiftlint:disable function_parameter_count
    public init(themeRepository: ThemeRepository,
                settingsRepository: SettingsRepository,
                quickActionRepository: QuickActionRepository,
                databaseUseCase: DatabaseUseCase,
                accountRepository: AccountRepository,
                loginViewController: (Void) -> LoginViewController) {
        self.themeRepository = themeRepository
        self.settingsRepository = settingsRepository
        self.quickActionRepository = quickActionRepository
        self.databaseUseCase = databaseUseCase
        self.accountRepository = accountRepository
        self.loginViewController = loginViewController

        super.init(nibName: nil, bundle: nil)
    }
    // swiftlint:enable function_parameter_count

    public required convenience init(injector: Injector) {
        self.init(
            themeRepository: injector.create(ThemeRepository)!,
            settingsRepository: injector.create(SettingsRepository)!,
            quickActionRepository: injector.create(QuickActionRepository)!,
            databaseUseCase: injector.create(DatabaseUseCase)!,
            accountRepository: injector.create(AccountRepository)!,
            loginViewController: { injector.create(LoginViewController)! }
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = NSLocalizedString("SettingsViewController_Title", comment: "")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save,
            target: self,
            action: #selector(SettingsViewController.didTapSave))
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
            target: self,
            action: #selector(SettingsViewController.didTapDismiss))

        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsetsZero)

        self.tableView.register(TableViewCell.self, forCellReuseIdentifier: "cell")
        self.tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: "switch")

        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.allowsMultipleSelection = true

        self.themeRepository.addSubscriber(self)

        self.oldTheme = self.themeRepository.theme
        self.reloadTable()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.splitViewController?.setNeedsStatusBarAppearanceUpdate()
        self.reloadTable()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        self.reloadTable()
    }

    public override func canBecomeFirstResponder() -> Bool { return true }

    public override var keyCommands: [UIKeyCommand]? {
        var commands: [UIKeyCommand] = []

        for (idx, theme) in ThemeRepository.Theme.array().enumerated() {
            guard theme != self.themeRepository.theme else {
                continue
            }

            let keyCommand = UIKeyCommand(input: "\(idx+1)", modifierFlags: .command,
                                          action: #selector(SettingsViewController.didHitChangeTheme(_:)))
            let title = NSLocalizedString("SettingsViewController_Commands_Theme", comment: "")
            keyCommand.discoverabilityTitle = String(NSString.localizedStringWithFormat(title as NSString, theme.description))
            commands.append(keyCommand)
        }

        let save = UIKeyCommand(input: "s", modifierFlags: .command,
                                action: #selector(SettingsViewController.didTapSave))
        let dismiss = UIKeyCommand(input: "w", modifierFlags: .command,
                                   action: #selector(SettingsViewController.didTapDismiss))

        save.discoverabilityTitle = NSLocalizedString("SettingsViewController_Commands_Save", comment: "")
        dismiss.discoverabilityTitle = NSLocalizedString("SettingsViewController_Commands_Dismiss", comment: "")

        commands.append(save)
        commands.append(dismiss)

        return commands
    }

    @objc fileprivate func didHitChangeTheme(_ keyCommand: UIKeyCommand) {}

    @objc fileprivate func didTapDismiss() {
        if self.oldTheme != self.themeRepository.theme {
            self.themeRepository.theme = self.oldTheme
        }
        self.navigationController?.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    @objc fileprivate func didTapSave() {
        self.oldTheme = self.themeRepository.theme
        self.settingsRepository.showEstimatedReadingLabel = self.showReadingTimes
        self.didTapDismiss()
    }

    fileprivate func reloadTable() {
        self.tableView.reloadData()
        let selectedIndexPath = IndexPath(row: self.themeRepository.theme.rawValue,
                                            section: SettingsSection.theme.rawValue)
        self.tableView.selectRow(at: selectedIndexPath, animated: false, scrollPosition: .none)
    }

    fileprivate func titleForQuickAction(_ row: Int) -> String {
        let quickActions = self.quickActionRepository.quickActions
        if row >= quickActions.count {
            let title: String
            if quickActions.count == 0 {
                title = NSLocalizedString("SettingsViewController_QuickActions_AddFirst", comment: "")
            } else {
                title = NSLocalizedString("SettingsViewController_QuickActions_AddAdditional", comment: "")
            }
            return title
        } else {
            let action = quickActions[row]
            return action.localizedTitle
        }
    }

    fileprivate func feedForQuickAction(_ row: Int, feeds: [Feed]) -> Feed? {
        let quickActions = self.quickActionRepository.quickActions
        guard row < quickActions.count else { return nil }

        let quickAction = quickActions[row]

        return feeds.objectPassingTest({$0.title == quickAction.localizedTitle})
    }
}

extension SettingsViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.navigationController?.navigationBar.barStyle = self.themeRepository.barStyle
        self.view.backgroundColor = self.themeRepository.backgroundColor

        func colorWithDefault(_ color: UIColor) -> UIColor? {
            return self.themeRepository.theme == .default ? nil : color
        }

        self.tableView.backgroundColor = colorWithDefault(self.themeRepository.backgroundColor)
        for section in 0..<self.tableView.numberOfSections {
            let headerView = self.tableView.headerView(forSection: section)
            headerView?.textLabel?.textColor = colorWithDefault(self.themeRepository.tintColor)
        }
    }
}

extension SettingsViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return SettingsSection.numberOfSettings(self.traitCollection)
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection sectionNum: Int) -> Int {
        guard let section = SettingsSection(rawValue: sectionNum, traits: self.traitCollection) else {
            return 0
        }
        switch section {
        case .theme:
            return 2
        case .quickActions:
            if self.quickActionRepository.quickActions.count == 3 {
                return 3
            }
            return self.quickActionRepository.quickActions.count + 1
        case .accounts:
            return 1
        case .advanced:
            return AdvancedSection.numberOfOptions
        case .credits:
            return 1
        }
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = SettingsSection(rawValue: (indexPath as NSIndexPath).section, traits: self.traitCollection) else {
            return TableViewCell()
        }
        switch section {
        case .theme:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
            guard let theme = ThemeRepository.Theme(rawValue: (indexPath as NSIndexPath).row) else {
                return cell
            }
            cell.themeRepository = self.themeRepository
            cell.textLabel?.text = theme.description
            return cell
        case .quickActions:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
            cell.themeRepository = self.themeRepository

            cell.textLabel?.text = self.titleForQuickAction((indexPath as NSIndexPath).row)

            return cell
        case .accounts:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
            cell.themeRepository = self.themeRepository

            let row = Account(rawValue: indexPath.row)!
            cell.textLabel?.text = row.description
            cell.detailTextLabel?.text = self.accountRepository.loggedIn()

            return cell
        case .advanced:
            let cell = tableView.dequeueReusableCell(withIdentifier: "switch",
                for: indexPath) as! SwitchTableViewCell
            let row = AdvancedSection(rawValue: (indexPath as NSIndexPath).row)!
            cell.textLabel?.text = row.description
            cell.themeRepository = self.themeRepository
            cell.onTapSwitch = {_ in }
            switch row {
            case .showReadingTimes:
                cell.theSwitch.isOn = self.showReadingTimes
                cell.onTapSwitch = {aSwitch in
                    self.showReadingTimes = aSwitch.isOn
                    self.navigationItem.rightBarButtonItem?.isEnabled = true
                }
            }
            return cell
        case .credits:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
            cell.themeRepository = self.themeRepository
            cell.textLabel?.text = NSLocalizedString("SettingsViewController_Credits_MainDeveloper_Name", comment: "")
            cell.detailTextLabel?.text =
                NSLocalizedString("SettingsViewController_Credits_MainDeveloper_Detail", comment: "")
            return cell
        }
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection sectionNum: Int) -> String? {
        guard let section = SettingsSection(rawValue: sectionNum, traits: self.traitCollection) else {
            return nil
        }
        return section.description
    }
}

extension SettingsViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard let section = SettingsSection(rawValue: (indexPath as NSIndexPath).section, traits: self.traitCollection) else {
            return
        }

        if section == .theme {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let section = SettingsSection(rawValue: (indexPath as NSIndexPath).section, traits: self.traitCollection)
            , section == .quickActions || section == .accounts else { return false }
        if section == .quickActions {
            return (indexPath as NSIndexPath).row < self.quickActionRepository.quickActions.count
        }
        return true
    }

    public func tableView(_ tableView: UITableView,
        editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard self.tableView(tableView, canEditRowAt: indexPath) else { return nil }

        guard let section = SettingsSection(rawValue: (indexPath as NSIndexPath).section, traits: self.traitCollection) else {return nil}
        switch section {
        case .quickActions:
            let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
            let deleteAction = UITableViewRowAction(style: .default, title: deleteTitle) {_, indexPath in
                self.quickActionRepository.quickActions.remove(at: (indexPath as NSIndexPath).row)
                if self.quickActionRepository.quickActions.count != 2 {
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                } else {
                    tableView.reloadRows(at: [
                        indexPath, IndexPath(row: 2, section: (indexPath as NSIndexPath).section)
                        ], with: .automatic)
                }
            }
            return [deleteAction]
        case .accounts:
            guard self.accountRepository.loggedIn() != nil else { return [] }
            let logOutTitle = NSLocalizedString("SettingsViewController_Accounts_Log_Out", comment: "")
            let logOutAction = UITableViewRowAction(style: .default, title: logOutTitle) {_ in
                self.accountRepository.logOut()
                tableView.reloadRows(at: [indexPath], with: .left)
            }
            return [logOutAction]
        default:
            return nil
        }
    }

    public func tableView(_ tableView: UITableView,
        commit editingStyle: UITableViewCellEditingStyle,
        forRowAt indexPath: IndexPath) {}

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let section = SettingsSection(rawValue: (indexPath as NSIndexPath).section, traits: self.traitCollection) else { return }
        switch section {
        case .theme:
            guard let theme = ThemeRepository.Theme(rawValue: (indexPath as NSIndexPath).row) else { return }
            self.themeRepository.theme = theme
            self.navigationItem.rightBarButtonItem?.isEnabled = true
            self.tableView.reloadData()
            self.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        case .quickActions:
            tableView.deselectRow(at: indexPath, animated: false)
            self.didTapQuickActionCell(indexPath)
        case .accounts:
            tableView.deselectRow(at: indexPath, animated: false)
            let loginViewController = self.loginViewController()
            loginViewController.accountType = Account(rawValue: indexPath.row)
            self.navigationController?.pushViewController(loginViewController, animated: true)
        case .advanced:
            tableView.deselectRow(at: indexPath, animated: false)
        case .credits:
            tableView.deselectRow(at: indexPath, animated: false)
            guard let url = URL(string: "https://twitter.com/younata") else { return }
            let viewController = SFSafariViewController(url: url)
            self.present(viewController, animated: true, completion: nil)
        }
    }

    fileprivate func didTapQuickActionCell(_ indexPath: IndexPath) {
        let feedsListController = FeedsListController()
        feedsListController.themeRepository = self.themeRepository
        feedsListController.navigationItem.title = self.titleForQuickAction((indexPath as NSIndexPath).row)

        let quickActions = self.quickActionRepository.quickActions
        self.databaseUseCase.feeds().then {
            if case let Result.Success(feeds) = $0 {
                if !quickActions.isEmpty {
                    let quickActionFeeds = quickActions.indices.reduce([Feed]()) {
                        guard let feed = self.feedForQuickAction($1, feeds: feeds) else { return $0 }
                        return $0 + [feed]
                    }
                    feedsListController.feeds = feeds.filter { !quickActionFeeds.contains($0) }
                } else {
                    feedsListController.feeds = feeds
                }
            }
        }
        feedsListController.tapFeed = {feed, _ in
            let newQuickAction = UIApplicationShortcutItem(type: "com.rachelbrindle.rssclient.viewfeed",
                localizedTitle: feed.title)
            if indexPath.row < quickActions.count {
                self.quickActionRepository.quickActions[indexPath.row] = newQuickAction
            } else {
                self.quickActionRepository.quickActions.append(newQuickAction)
                if self.quickActionRepository.quickActions.count <= 3 {
                    let quickActionsCount = self.quickActionRepository.quickActions.count
                    let insertedIndexPath = NSIndexPath(forRow: quickActionsCount, inSection: indexPath.section)
                    self.tableView.insertRowsAtIndexPaths([insertedIndexPath], withRowAnimation: .Automatic)
                }
            }
            self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            self.navigationController?.popViewControllerAnimated(true)
        }
        self.navigationController?.pushViewController(feedsListController, animated: true)
    }
}
