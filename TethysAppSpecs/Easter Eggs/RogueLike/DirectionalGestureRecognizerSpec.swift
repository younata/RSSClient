import UIKit
import Quick
import Nimble
@testable import Tethys

final class DirectionalGestureRecognizerSpec: QuickSpec {
    override func spec() {
        var subject: DirectionalGestureRecognizer!

        var observer: DirectionalGestureObserver!
        var view: UIView!

        beforeEach {
            observer = DirectionalGestureObserver()
            view = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
            subject = DirectionalGestureRecognizer(target: observer, action: #selector(DirectionalGestureObserver.didRecognize(_:)))

            view.addGestureRecognizer(subject)
        }

        it("does not inform the gesture observer that anything happened yet") {
            expect(observer.observations).to(beEmpty())
        }

        it("sets the gesture recognizer's state to possible") {
            expect(subject.state).to(equal(.possible))
        }


        describe("when the user first taps") {
            var touch: FakeTouch!

            beforeEach {
                touch = FakeTouch()
                touch.currentLocation = CGPoint(x: 100, y: 100)
                subject.touchesBegan([touch], with: UIEvent())
            }

            it("updates the gesture's current state to began") {
                expect(subject.state).toEventually(equal(.began))
            }

            it("updates the observer") {
                expect(observer.observations).toEventually(haveCount(1))
                expect(observer.observations.last).to(equal(DirectionalGestureState(state: .began, direction: .zero)))
            }

            context("if the user lifts their finger now") {
                beforeEach {
                    expect(observer.observations).toEventually(haveCount(1))
                    subject.touchesEnded([touch], with: UIEvent())
                }

                it("cancels the gesture recognizer") {
                    expect(subject.state).toEventually(equal(.possible))
                }

                it("updates the observer") {
                    expect(observer.observations).toEventually(haveCount(2))
                    expect(observer.observations.last).to(equal(DirectionalGestureState(state: .ended, direction: .zero)))
                }
            }

            context("if the user moves their finger just a little bit") {
                beforeEach {
                    expect(observer.observations).toEventually(haveCount(1))
                    touch.currentLocation = CGPoint(x: 130, y: 130)

                    subject.touchesMoved([touch], with: UIEvent())
                }

                it("doesn't do anything because the finger is within the deadzone") {
                    expect(subject.state).toEventually(equal(.began))
                    expect(observer.observations).to(haveCount(1))
                }
            }

            context("if the user moves their finger outside the deadzone (to the right)") {
                beforeEach {
                    expect(observer.observations).toEventually(haveCount(1))
                    touch.currentLocation = CGPoint(x: 150, y: 100)

                    subject.touchesMoved([touch], with: UIEvent())
                }

                it("marks the gesture as recognized") {
                    expect(subject.state).toEventually(equal(.changed))
                }

                it("sets the direction property") {
                    expect(subject.direction).toEventually(equal(CGVector(dx: 1, dy: 0)))
                }

                it("updates the observer") {
                    expect(observer.observations).toEventually(haveCount(2))
                    expect(observer.observations.last).to(equal(DirectionalGestureState(state: .changed, direction: CGVector(dx: 1, dy: 0))))
                }

                context("if the user moves their finger back into the deadzone") {
                    beforeEach {
                        expect(observer.observations).toEventually(haveCount(2))
                        touch.currentLocation = CGPoint(x: 120, y: 100)
                        subject.touchesMoved([touch], with: UIEvent())
                    }

                    it("keeps the gesture marked as recognized") {
                        expect(subject.state).toEventually(equal(.changed))
                    }

                    it("sets the direction property to zero") {
                        expect(subject.direction).toEventually(equal(CGVector(dx: 0, dy: 0)))
                    }

                    it("updates the observer") {
                        expect(observer.observations).toEventually(haveCount(3))
                        expect(observer.observations.last).to(equal(DirectionalGestureState(state: .changed, direction: .zero)))
                    }
                }

                context("if the user moves their finger to a different direction") {
                    beforeEach {
                        expect(observer.observations).toEventually(haveCount(2))
                        touch.currentLocation = CGPoint(x: 150, y: 150)
                        subject.touchesMoved([touch], with: UIEvent())
                    }

                    it("marks the gesture as changed") {
                        expect(subject.state).toEventually(equal(.changed))
                    }

                    it("sets the direction property to reflect the new direction") {
                        expect(subject.direction).toEventually(equal(CGVector(dx: sin(45.rads), dy: sin(45.rads))))
                    }

                    it("updates the observer") {
                        expect(observer.observations).toEventually(haveCount(3))
                        expect(observer.observations.last).to(equal(DirectionalGestureState(state: .changed, direction: CGVector(dx: sin(45.rads), dy: sin(45.rads)))))
                    }
                }

                context("if the user lifts their finger") {
                    beforeEach {
                        expect(observer.observations).toEventually(haveCount(2))
                        subject.touchesEnded([touch], with: UIEvent())
                    }

                    it("markse the gesture as ended") {
                        expect(subject.state).toEventually(equal(.possible))
                    }

                    it("sets the direction property to zero") {
                        expect(subject.direction).toEventually(equal(.zero))
                    }

                    it("updates the observer") {
                        expect(observer.observations).toEventually(haveCount(3))
                        expect(observer.observations.last).toEventually(equal(DirectionalGestureState(state: .ended, direction: .zero)))
                    }
                }
            }
        }
    }
}

extension UIGestureRecognizer.State: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .began: return ".began"
        case .possible: return ".possible"
        case .changed: return ".changed"
        case .ended: return ".ended"
        case .cancelled: return ".cancelled"
        case .failed: return ".failed"
        @unknown default:
            return "UIGestureRecognizer.State Unknown!"
        }
    }
}

import XCTest

final class CGVectorLinearAlgebraSpec: XCTestCase {
    func testNormalization() {
        expect(CGVector(dx: 10, dy: 0).normalized()).to(equal(CGVector(dx: 1, dy: 0)))
        expect(CGVector(dx: 0, dy: 5).normalized()).to(equal(CGVector(dx: 0, dy: 1)))
        expect(CGVector(dx: 1, dy: 1).normalized()).to(equal(CGVector(dx: sin(45.rads), dy: sin(45.rads))))
    }

    func testPointSubtraction() {
        expect(CGPoint(x: 10, y: 10) - CGPoint(x: 15, y: 17)).to(equal(CGVector(dx: -5, dy: -7)))
        expect(CGPoint(x: 15, y: 17) - CGPoint(x: 11, y: 12)).to(equal(CGVector(dx: 4, dy: 5)))
    }

    func testPointVectorAddition() {
        expect(CGPoint(x: 10, y: 10) + CGVector(dx: 5, dy: 2)).to(equal(CGPoint(x: 15, y: 12)))
        var a = CGPoint(x: 10, y: 10)
        a += CGVector(dx: 5, dy: 2)
        expect(a).to(equal(CGPoint(x: 15, y: 12)))
    }

    func testPerformance() {
        self.measure {
            for _ in 0..<1_000 {
                _ = CGVector(dx: 30000000, dy: 40000000).normalized()
            }
        }
    }
}

extension Double {
    var rads: Double {
        return self * .pi / 180
    }
}

struct DirectionalGestureState: Equatable {
    let state: UIGestureRecognizer.State
    let direction: CGVector
}

@objc final class DirectionalGestureObserver: NSObject {
    var observations: [DirectionalGestureState] = []

    @objc func didRecognize(_ gestureRecognizer: DirectionalGestureRecognizer) {
        self.observations.append(DirectionalGestureState(state: gestureRecognizer.state, direction: gestureRecognizer.direction))
    }
}

class FakeTouch: UITouch {
    var currentLocation: CGPoint = .zero
    override func location(in view: UIView?) -> CGPoint {
        return self.currentLocation
    }
}
