import Quick
import Nimble
import rNews

class ValidatorViewSpec: QuickSpec {
    override func spec() {
        var subject: ValidatorView! = nil

        beforeEach {
            subject = ValidatorView()
        }

        describe("beginValidating") {
            beforeEach {
                subject.beginValidating()
            }

            it("should move to an in-progress validating state") {
                expect(subject.state).to(equal(ValidatorView.ValidatorState.Validating))
            }

            it("should start the progressIndicator") {
                expect(subject.progressIndicator.isAnimating()) == true
            }

            context("upon successful validation") {
                beforeEach {
                    subject.endValidating(true)
                }

                it("should move to a successful validating state") {
                    expect(subject.state).to(equal(ValidatorView.ValidatorState.Valid))
                }

                it("should stop the progressIndicator") {
                    expect(subject.progressIndicator.isAnimating()) == false
                }

                it("should hide the progressIndicator") {
                    expect(subject.progressIndicator.hidden) == true
                }
            }

            context("upon failing to validate") {
                beforeEach {
                    subject.endValidating(false)
                }

                it("should move to an invalid validating state") {
                    expect(subject.state).to(equal(ValidatorView.ValidatorState.Invalid))
                }

                it("should stop the progressIndicator") {
                    expect(subject.progressIndicator.isAnimating()) == false
                }

                it("should hide the progressIndicator") {
                    expect(subject.progressIndicator.hidden) == true
                }
            }
        }
    }
}
