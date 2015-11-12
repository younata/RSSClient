import Quick
import Nimble
import rNews
import Ra
import UIKit

private class FakeThemeSubscriber: NSObject, ThemeRepositorySubscriber {
    private var didCallChangeTheme = false
    private func didChangeTheme() {
        didCallChangeTheme = true
    }
}

class ThemeRepositorySpec: QuickSpec {
    override func spec() {
        var subject: ThemeRepository! = nil
        var injector: Injector! = nil
        var userDefaults: FakeUserDefaults! = nil
        var subscriber: FakeThemeSubscriber! = nil



        beforeEach {
            injector = Injector()

            userDefaults = FakeUserDefaults()
            injector.bind(NSUserDefaults.self, to: userDefaults)

            subject = injector.create(ThemeRepository.self) as! ThemeRepository

            subscriber = FakeThemeSubscriber()
            subject.addSubscriber(subscriber)
            subscriber.didCallChangeTheme = false
        }

        it("adding a subscriber should immediately call didChangeTheme on it") {
            let newSubscriber = FakeThemeSubscriber()
            subject.addSubscriber(newSubscriber)
            expect(newSubscriber.didCallChangeTheme).to(beTruthy())
            expect(subscriber.didCallChangeTheme).to(beFalsy())
        }

        it("has a default theme of .Default") {
            expect(subject.theme).to(equal(ThemeRepository.Theme.Default))
        }

        it("has a default background color of white") {
            expect(subject.backgroundColor).to(equal(UIColor.whiteColor()))
        }

        it("has a default text color of black") {
            expect(subject.textColor).to(equal(UIColor.blackColor()))
        }

        it("uses 'github2' as the default article css") {
            expect(subject.articleCSSFileName).to(equal("github2"))
        }

        it("has a default tint color of white") {
            expect(subject.tintColor).to(equal(UIColor.whiteColor()))
        }

        it("uses 'mac_classic' as the default syntax highlight file name") {
            expect(subject.syntaxHighlightFile).to(equal("mac_classic"))
        }

        it("uses UIBarStyleDefault as the default barstyle") {
            expect(subject.barStyle).to(equal(UIBarStyle.Default))
        }

        sharedExamples("a changed theme") {(sharedContext: SharedExampleContext) in
            it("changes the background color") {
                let expectedColor = sharedContext()["background"] as? UIColor
                expect(expectedColor).toNot(beNil())
                expect(subject.backgroundColor).to(equal(expectedColor))
            }

            it("changes the text color") {
                let expectedColor = sharedContext()["text"] as? UIColor
                expect(expectedColor).toNot(beNil())
                expect(subject.textColor).to(equal(expectedColor))
            }

            it("changes the tint color") {
                let expectedColor = sharedContext()["tint"] as? UIColor
                expect(expectedColor).toNot(beNil())
                expect(subject.tintColor).to(equal(expectedColor))
            }

            it("changes the articleCss") {
                let expectedCss = sharedContext()["article"] as? String
                expect(expectedCss).toNot(beNil())
                expect(subject.articleCSSFileName).to(equal(expectedCss))
            }

            it("changes the syntax highlight file name") {
                let expectedSyntax = sharedContext()["syntax"] as? String
                expect(expectedSyntax).toNot(beNil())
                expect(subject.syntaxHighlightFile).to(equal(expectedSyntax))
            }

            it("changes the barstyle") {
                let expectedBarStyle = UIBarStyle(rawValue: sharedContext()["barStyle"] as! Int)
                expect(expectedBarStyle).toNot(beNil())
                expect(subject.barStyle).to(equal(expectedBarStyle))
            }

            it("informs subscribers") {
                expect(subscriber.didCallChangeTheme).to(beTruthy())
            }

            it("persists the change if it is not ephemeral") {
                let otherRepo = injector.create(ThemeRepository.self) as! ThemeRepository
                if (sharedContext()["ephemeral"] as? Bool != true) {
                    let expectedBackground = sharedContext()["background"] as? UIColor
                    expect(expectedBackground).toNot(beNil())

                    let expectedText = sharedContext()["text"] as? UIColor
                    expect(expectedText).toNot(beNil())

                    let expectedCss = sharedContext()["article"] as? String
                    expect(expectedCss).toNot(beNil())

                    let expectedTint = sharedContext()["tint"] as? UIColor
                    expect(expectedTint).toNot(beNil())

                    let expectedSyntax = sharedContext()["syntax"] as? String
                    expect(expectedSyntax).toNot(beNil())

                    let expectedBarStyle = UIBarStyle(rawValue: sharedContext()["barStyle"] as! Int)
                    expect(expectedBarStyle).toNot(beNil())

                    expect(otherRepo.backgroundColor).to(equal(expectedBackground))
                    expect(otherRepo.textColor).to(equal(expectedText))
                    expect(otherRepo.articleCSSFileName).to(equal(expectedCss))
                    expect(otherRepo.tintColor).to(equal(expectedTint))
                    expect(otherRepo.syntaxHighlightFile).to(equal(expectedSyntax))
                    expect(otherRepo.barStyle).to(equal(expectedBarStyle))
                } else {
                    let expectedBackground = UIColor.whiteColor()
                    let expectedText = UIColor.blackColor()
                    let expectedCss = "github2"
                    let expectedTint = UIColor.whiteColor()
                    let expectedSyntax = "mac_classic"
                    let expectedBarStyle = UIBarStyle.Default

                    expect(otherRepo.backgroundColor).to(equal(expectedBackground))
                    expect(otherRepo.textColor).to(equal(expectedText))
                    expect(otherRepo.articleCSSFileName).to(equal(expectedCss))
                    expect(otherRepo.tintColor).to(equal(expectedTint))
                    expect(otherRepo.syntaxHighlightFile).to(equal(expectedSyntax))
                    expect(otherRepo.barStyle).to(equal(expectedBarStyle))
                }
            }
        }

        describe("setting the theme") {
            context("of a persistant repository") {
                context("to .Dark") {
                    beforeEach {
                        subject.theme = .Dark
                    }

                    itBehavesLike("a changed theme") {
                        return [
                            "background": UIColor.blackColor(),
                            "text": UIColor.whiteColor(),
                            "article": "darkhub2",
                            "tint": UIColor.darkGrayColor(),
                            "syntax": "twilight",
                            "barStyle": UIBarStyle.Black.rawValue,
                        ]
                    }
                }

                context("to .Default") {
                    beforeEach {
                        subject.theme = .Default
                    }

                    itBehavesLike("a changed theme") {
                        return [
                            "background": UIColor.whiteColor(),
                            "text": UIColor.blackColor(),
                            "article": "github2",
                            "tint": UIColor.whiteColor(),
                            "syntax": "mac_classic",
                            "barStyle": UIBarStyle.Default.rawValue,
                        ]
                    }
                }
            }

            context("of an ephemeral repository") {
                beforeEach {
                    subject = ThemeRepository(userDefaults: nil)

                    subscriber = FakeThemeSubscriber()
                    subject.addSubscriber(subscriber)
                    subscriber.didCallChangeTheme = false
                }
                
                context("to .Dark") {
                    beforeEach {
                        subject.theme = .Dark
                    }

                    itBehavesLike("a changed theme") {
                        return [
                            "background": UIColor.blackColor(),
                            "text": UIColor.whiteColor(),
                            "article": "darkhub2",
                            "tint": UIColor.darkGrayColor(),
                            "syntax": "twilight",
                            "barStyle": UIBarStyle.Black.rawValue,
                            "ephemeral": true,
                        ]
                    }
                }

                context("to .Default") {
                    beforeEach {
                        subject.theme = .Default
                    }

                    itBehavesLike("a changed theme") {
                        return [
                            "background": UIColor.whiteColor(),
                            "text": UIColor.blackColor(),
                            "article": "github2",
                            "tint": UIColor.whiteColor(),
                            "syntax": "mac_classic",
                            "barStyle": UIBarStyle.Default.rawValue,
                            "ephemeral": true,
                        ]
                    }
                }
            }
        }
    }
}