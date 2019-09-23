import XCTest
import Nimble

class TethysAcceptanceTests: XCTestCase {
        
    override func setUp() {
        super.setUp()

        self.continueAfterFailure = false
        setupSnapshot(XCUIApplication())

        XCUIApplication().launch()
    }

    override func tearDown() {
        super.tearDown()
    }

    func waitForThingToExist(_ thing: AnyObject) {
        self.waitForPredicate(NSPredicate(format: "exists == true"), object: thing)
    }

    func waitForPredicate(_ predicate: NSPredicate, object: AnyObject) {
        self.expectation(for: predicate, evaluatedWith: object, handler: nil)
        self.waitForExpectations(timeout: 10, handler: nil)
    }

    func loadWebFeed() {
        let app = XCUIApplication()

        self.waitForThingToExist(app.navigationBars["Feeds"])
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 5))
        app.navigationBars["Feeds"].buttons["Add"].tap()

        let enterUrlTextField = app.textFields["Enter URL"]
        self.waitForThingToExist(enterUrlTextField)
        expect(app.keyboards.element.exists).to(beTrue(), description: "Expected to show a keyboard")
        app.typeText("blog.rachelbrindle.com")
        app.buttons["Return"].tap()

        let addFeedButton = app.toolbars.buttons["Add Feed"]
        self.waitForThingToExist(addFeedButton)
        addFeedButton.tap()

        self.waitForThingToExist(app.cells["Rachel Brindle"])
    }

    func assertShareShows(shareButtonName: String, app: XCUIApplication) {
        app.buttons[shareButtonName].tap()

        let element: XCUIElement
        if app.buttons["Cancel"].exists {
            element = app.buttons["Cancel"]
        } else if app.otherElements["PopoverDismissRegion"].exists {
            element = app.otherElements["PopoverDismissRegion"]
        } else {
            return fail("No way to dismiss share sheet")
        }
        element.tap()
    }

    func testMakingScreenshots() {
        let app = XCUIApplication()

        self.waitForThingToExist(app.navigationBars["Feeds"])
        assertFirstLaunch(app: app)

        self.loadWebFeed()

        snapshot("01-feedsList", waitForLoadingIndicator: false)

        app.cells["Rachel Brindle"].tap()

        self.waitForThingToExist(app.navigationBars["Rachel Brindle"])

        snapshot("02-articlesList", waitForLoadingIndicator: false)

        self.assertShareShows(shareButtonName: "ArticleListController_ShareFeed", app: app)

        app.staticTexts["Homemade thermostat for my apartment"].tap()

        self.waitForThingToExist(app.navigationBars["Homemade thermostat for my apartment"])

        snapshot("03-article", waitForLoadingIndicator: false)

        self.assertShareShows(shareButtonName: "ArticleViewController_ShareArticle", app: app)
    }

    func testAppIconView() {
        let app = XCUIApplication()

        self.waitForThingToExist(app.navigationBars["Feeds"])

        app.buttons["Settings"].tap()

        self.waitForThingToExist(app.navigationBars["Settings"])

        app.cells["App Icon"].tap()

        self.waitForThingToExist(app.navigationBars["App Icon"])

        expect(app.buttons["AppIcon Default"].isSelected).toEventually(beTrue())
        expect(app.buttons["AppIcon Black"].isSelected).to(beFalse())

        expect(app.buttons["AppIcon Default"].isEnabled).to(beFalse())
        expect(app.buttons["AppIcon Black"].isEnabled).to(beTrue())

        app.buttons["AppIcon Black"].tap()

        expect(app.buttons["AppIcon Default"].isSelected).toEventually(beFalse())
        expect(app.buttons["AppIcon Black"].isSelected).to(beTrue())

        expect(app.buttons["AppIcon Default"].isEnabled).to(beTrue())
        expect(app.buttons["AppIcon Black"].isEnabled).to(beFalse())
    }
}
