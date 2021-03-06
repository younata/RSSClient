import UIKit
import PureLayout
import SafariServices
import Result
import TethysKit
import SwiftUI

// swiftlint:disable file_length

public final class SettingsViewController: UIViewController {
    public let tableView = UITableView(frame: CGRect.zero, style: .grouped)

    fileprivate let settingsRepository: SettingsRepository
    fileprivate let opmlService: OPMLService
    fileprivate let mainQueue: OperationQueue
    fileprivate let accountService: AccountService
    fileprivate let messenger: Messenger
    fileprivate let appIconChanger: AppIconChanger
    fileprivate let loginController: LoginController
    fileprivate let documentationViewController: (Documentation) -> DocumentationViewController
    fileprivate let appIconChangeController: () -> UIViewController
    fileprivate let easterEggViewController: () -> UIViewController

    fileprivate lazy var showReadingTimes: Bool = { return self.settingsRepository.showEstimatedReadingLabel }()
    fileprivate lazy var refreshControlStyle: RefreshControlStyle = { return self.settingsRepository.refreshControl }()

    fileprivate var account: Account?

    public init(settingsRepository: SettingsRepository,
                opmlService: OPMLService,
                mainQueue: OperationQueue,
                accountService: AccountService,
                messenger: Messenger,
                appIconChanger: AppIconChanger,
                loginController: LoginController,
                documentationViewController: @escaping (Documentation) -> DocumentationViewController,
                appIconChangeController: @escaping () -> UIViewController,
                easterEggViewController: @escaping () -> UIViewController) {
        self.settingsRepository = settingsRepository
        self.opmlService = opmlService
        self.mainQueue = mainQueue
        self.accountService = accountService
        self.messenger = messenger
        self.appIconChanger = appIconChanger
        self.loginController = loginController
        self.documentationViewController = documentationViewController
        self.appIconChangeController = appIconChangeController
        self.easterEggViewController = easterEggViewController

        super.init(nibName: nil, bundle: nil)
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
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Generic_Close", comment: ""),
                                                                style: .plain, target: self,
                                                                action: #selector(SettingsViewController.didTapDismiss))

        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdges(with: .zero)

        self.tableView.register(TableViewCell.self, forCellReuseIdentifier: "cell")
        self.tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: "switch")

        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.allowsMultipleSelection = true

        self.accountService.accounts().then { results in
            self.mainQueue.addOperation {
                self.account = results.compactMap { $0.value }.first { $0.kind == .inoreader }
                self.reloadTable()
            }
        }

        self.applyTheme()
        self.reloadTable()
    }

    private func applyTheme() {
        self.tableView.backgroundColor = Theme.backgroundColor
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

    public override var canBecomeFirstResponder: Bool { return true }

    public override var keyCommands: [UIKeyCommand]? {
        let save = UIKeyCommand(input: "s", modifierFlags: .command,
                                action: #selector(SettingsViewController.didTapSave))
        let dismiss = UIKeyCommand(input: "w", modifierFlags: .command,
                                   action: #selector(SettingsViewController.didTapDismiss))

        save.discoverabilityTitle = NSLocalizedString("SettingsViewController_Commands_Save", comment: "")
        dismiss.discoverabilityTitle = NSLocalizedString("SettingsViewController_Commands_Close", comment: "")

        return [save, dismiss]
    }

    @objc fileprivate func didTapDismiss() {
        let presenter = self.presentingViewController ?? self.navigationController?.presentingViewController
        if let presentingController = presenter {
            presentingController.dismiss(animated: true, completion: nil)
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }

    @objc fileprivate func didTapSave() {
        self.settingsRepository.showEstimatedReadingLabel = self.showReadingTimes
        self.settingsRepository.refreshControl = self.refreshControlStyle
        self.didTapDismiss()
    }

    fileprivate func reloadTable() {
        self.tableView.reloadData()
        let currentRefreshStyleIndexPath = IndexPath(row: self.refreshControlStyle.rawValue,
                                                     section: SettingsSection.refresh.rawValue)
        self.tableView.selectRow(at: currentRefreshStyleIndexPath, animated: false, scrollPosition: .none)
    }
}

extension SettingsViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return SettingsSection.numberOfSettings()
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection sectionNum: Int) -> Int {
        guard let section = SettingsSection(rawValue: sectionNum) else {
            return 0
        }
        switch section {
        case .account:
            return 1
        case .refresh:
            return 2
        case .other:
            return OtherSection.numberOfOptions(appIconChanger: self.appIconChanger)
        case .credits:
            return 3
        }
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = SettingsSection(rawValue: indexPath.section) else {
            return TableViewCell()
        }
        switch section {
        case .account:
            return self.accountCell(indexPath: indexPath)
        case .refresh:
            return self.refreshCell(indexPath: indexPath)
        case .other:
            return self.otherCell(indexPath: indexPath)
        case .credits:
            return self.creditCell(indexPath: indexPath)
        }
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection sectionNum: Int) -> String? {
        guard let section = SettingsSection(rawValue: sectionNum) else { return nil }
        return section.description
    }

    private func accountCell(indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
        cell.textLabel?.text = NSLocalizedString("SettingsViewController_Account_Inoreader", comment: "")
        cell.accessibilityTraits = [.button]
        cell.accessibilityHint = nil
        if let account = self.account {
            cell.detailTextLabel?.text = account.username
            cell.accessibilityLabel = NSLocalizedString(
                "SettingsViewController_Account_Accessibility_InoreaderExists",
                comment: ""
            )
            cell.accessibilityValue = account.username
            cell.accessibilityHint = NSLocalizedString(
                "SettingsViewController_Account_Accessibility_InoreaderExists_Hint",
                comment: ""
            )
        } else {
            cell.detailTextLabel?.text = NSLocalizedString("SettingsViewController_Account_Add", comment: "")
            cell.accessibilityLabel = NSLocalizedString("SettingsViewController_Account_Add", comment: "")
            cell.accessibilityValue = NSLocalizedString("SettingsViewController_Account_Inoreader", comment: "")
        }
        return cell
    }

    private func refreshCell(indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
        guard let refreshStyle = RefreshControlStyle(rawValue: indexPath.row) else { return cell }
        cell.textLabel?.text = refreshStyle.description
        cell.accessibilityLabel = refreshStyle.accessibilityLabel
        cell.accessibilityTraits = [.button]
        return cell
    }

    private func otherCell(indexPath: IndexPath) -> UITableViewCell {
        let row = OtherSection(rowIndex: indexPath.row, appIconChanger: self.appIconChanger)!
        var tableCell: UITableViewCell
        switch row {
        case .showReadingTimes:
            let cell = self.tableView.dequeueReusableCell(withIdentifier: "switch",
                                                     for: indexPath) as! SwitchTableViewCell
            cell.onTapSwitch = {_ in }
            cell.theSwitch.isOn = self.showReadingTimes
            cell.accessibilityLabel = NSLocalizedString("SettingsViewController_Other_Accessibility_ShowReadingTimes",
                                                        comment: "")
            cell.onTapSwitch = {aSwitch in
                self.showReadingTimes = aSwitch.isOn
                self.navigationItem.rightBarButtonItem?.isEnabled = true
                cell.accessibilityValue = aSwitch.isOn ?
                    NSLocalizedString("Generic_Enabled", comment: "") :
                    NSLocalizedString("Generic_Disabled", comment: "")
            }
            tableCell = cell
            cell.accessibilityValue = self.showReadingTimes ?
                NSLocalizedString("Generic_Enabled", comment: "") :
                NSLocalizedString("Generic_Disabled", comment: "")
            cell.accessibilityHint = NSLocalizedString(
                "SettingsViewController_Other_ShowReadingTimes_AccessibilityHint",
                comment: ""
            )
        case .exportOPML:
            let cell = self.tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
            cell.accessibilityTraits = [.button]
            cell.accessibilityLabel = NSLocalizedString("SettingsViewController_Other_ExportOPML_Accessibility",
                                                        comment: "")
            tableCell = cell
        case .appIcon:
            let cell = self.tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
            cell.accessibilityTraits = [.button]
            cell.accessibilityLabel = NSLocalizedString("SettingsViewController_AlternateIcons_Accessibility_Title",
                                                        comment: "")
            tableCell = cell
        case .gitVersion:
            let cell = self.tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
            tableCell = cell

            let versionText = Bundle.main.infoDictionary?["CurrentVersion"] as? String
            cell.detailTextLabel?.text = versionText
            cell.accessibilityValue = versionText
            cell.accessibilityTraits = [.button]
            cell.accessibilityLabel = row.description
            cell.accessibilityHint = NSLocalizedString("SettingsviewController_Credits_Version_AccessibilityHint",
                                                       comment: "")
        }
        tableCell.textLabel?.text = row.description
        return tableCell
    }

    private func creditCell(indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
        cell.accessibilityTraits = [.button]
        if indexPath.row == 0 {
            let name = NSLocalizedString("SettingsViewController_Credits_MainDeveloper_Name", comment: "")
            let title = NSLocalizedString("SettingsViewController_Credits_MainDeveloper_Detail", comment: "")
            cell.textLabel?.text = name
            cell.detailTextLabel?.text = title
            cell.accessibilityLabel = NSLocalizedString("SettingsViewController_Credits_Accessibility_Credit",
                                                        comment: "")
            cell.accessibilityValue = "\(name), \(title)"
        } else if indexPath.row == 1 {
            cell.textLabel?.text = NSLocalizedString("SettingsViewController_Credits_Libraries", comment: "")
            cell.detailTextLabel?.text = ""
            cell.accessibilityLabel = cell.textLabel?.text
        } else if indexPath.row == 2 {
            cell.textLabel?.text = NSLocalizedString("SettingsViewController_Credits_Icons", comment: "")
            cell.detailTextLabel?.text = ""
            cell.accessibilityLabel = cell.textLabel?.text
        }
        return cell
    }
}

extension SettingsViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard let section = SettingsSection(rawValue: indexPath.section) else { return }

        switch section {
        case .refresh:
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        default:
            break
        }
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard SettingsSection(rawValue: indexPath.section) == .account else { return false }
        return self.account != nil
    }

    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard SettingsSection(rawValue: indexPath.section) == .account, let account = self.account else { return nil }

        let actions = UISwipeActionsConfiguration(actions: [
            UIContextualAction(
                style: .destructive,
                title: NSLocalizedString("SettingsViewController_Account_Logout_Title", comment: ""),
                handler: { [weak self] (_, _, callback) in
                    self?.accountService.logout(of: account).then { [weak self] (result: Result<Void, TethysError>) in
                        switch result {
                        case .success:
                            self?.account = nil
                            tableView.reloadRows(at: [indexPath], with: .right)
                            callback(true)
                        case .failure(let error):
                            callback(false)
                            self?.messenger.error(
                                title: NSLocalizedString("SettingsViewController_Account_Logout_Error", comment: ""),
                                message: error.localizedDescription
                            )
                        }
                    }
            })
        ])
        actions.performsFirstActionWithFullSwipe = true
        return actions
    }

    @objc(tableView:commitEditingStyle:forRowAtIndexPath:)
    public func tableView(_ tableView: UITableView,
                          commit editingStyle: UITableViewCell.EditingStyle,
                          forRowAt indexPath: IndexPath) {}

    public func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath,
                          point: CGPoint) -> UIContextMenuConfiguration? {
        guard SettingsSection(rawValue: indexPath.section) == .credits else {
            return nil
        }
        return UIContextMenuConfiguration(
            identifier: indexPath as NSIndexPath,
            previewProvider: { [weak self] in
                if indexPath.row == 0 {
                    guard let url = URL(string: "https://twitter.com/younata") else { return nil }
                    return SFSafariViewController(url: url)
                } else if indexPath.row == 1 {
                    return self?.documentationViewController(.libraries)
                } else if indexPath.row == 2 {
                    return self?.documentationViewController(.icons)
                } else {
                    return nil
                }
            },
            actionProvider: { elements in
                return UIMenu(title: "", children: elements)
        })
    }

    public func tableView(_ tableView: UITableView,
                          willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
                          animator: UIContextMenuInteractionCommitAnimating) {
        animator.addCompletion { [weak self] in
            guard let viewController = animator.previewViewController else { return }
            if viewController.isKind(of: SFSafariViewController.self) {
                let indexPath = IndexPath(row: SettingsSection.credits.rawValue, section: 0)
                viewController.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
                self?.present(viewController, animated: true, completion: nil)
            } else {
                self?.navigationController?.pushViewController(viewController, animated: true)
            }
        }
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let section = SettingsSection(rawValue: indexPath.section) else { return }
        switch section {
        case .account:
            self.didTapAccountCell(indexPath: indexPath)
        case .refresh:
            self.didTapRefreshCell(indexPath: indexPath)
        case .other:
            self.didTapOtherCell(tableView: tableView, indexPath: indexPath)
        case .credits:
            self.didTapCreditCell(tableView: tableView, indexPath: indexPath)
        }
    }

    private func didTapAccountCell(indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        self.loginController.window = self.view.window
        self.loginController.begin().then { result in
            switch result {
            case .success(let account):
                self.account = account
                self.tableView.reloadRows(at: [indexPath], with: .right)
            case .failure(.network(_, .cancelled)):
                break
            default:
                self.messenger.warning(
                    title: NSLocalizedString("SettingsViewController_Account_Error_Title", comment: ""),
                    message: NSLocalizedString("SettingsViewController_Account_Error_Message", comment: "")
                )
            }
        }
    }

    private func didTapRefreshCell(indexPath: IndexPath) {
        guard let refreshControlStyle = RefreshControlStyle(rawValue: indexPath.row) else { return }
        self.refreshControlStyle = refreshControlStyle
        self.navigationItem.rightBarButtonItem?.isEnabled = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        self.reloadTable()
    }

    private func didTapOtherCell(tableView: UITableView, indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard let otherSection = OtherSection(rowIndex: indexPath.row, appIconChanger: self.appIconChanger) else {
            return
        }

        switch otherSection {
        case .exportOPML:
            _ = self.opmlService.writeOPML().then {
                switch $0 {
                case let .success(url):
                    self.mainQueue.addOperation {
                        let shareSheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        shareSheet.popoverPresentationController?.sourceView = tableView
                        shareSheet.popoverPresentationController?.sourceRect = tableView.rectForRow(at: indexPath)
                        self.present(shareSheet, animated: true, completion: nil)
                    }
                case .failure:
                    self.mainQueue.addOperation {
                        self.messenger.error(
                            title: NSLocalizedString("SettingsViewController_Other_ExportOPML_Error_Title",
                                                     comment: ""),
                            message: NSLocalizedString("SettingsViewController_Other_ExportOPML_Error_Message",
                                                       comment: "")
                        )
                    }
                }
            }
        case .appIcon:
            self.navigationController?.pushViewController(self.appIconChangeController(), animated: true)
        case .gitVersion:
            self.navigationController?.pushViewController(self.easterEggViewController(), animated: true)
        case .showReadingTimes:
            guard let cell = tableView.cellForRow(at: indexPath) as? SwitchTableViewCell else {
                return
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            cell.theSwitch.setOn(!cell.theSwitch.isOn, animated: true)
            cell.onTapSwitch?(cell.theSwitch)
        }
    }

    private func didTapCreditCell(tableView: UITableView, indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if indexPath.row == 0 {
            guard let url = URL(string: "https://twitter.com/younata") else { return }
            let viewController = SFSafariViewController(url: url)
            viewController.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)
            self.present(viewController, animated: true, completion: nil)
        } else if indexPath.row == 1 {
            let viewController = self.documentationViewController(.libraries)
            self.navigationController?.pushViewController(viewController, animated: true)
        } else if indexPath.row == 2 {
            let viewController = self.documentationViewController(.icons)
            self.navigationController?.pushViewController(viewController, animated: true)
        }
    }
}
