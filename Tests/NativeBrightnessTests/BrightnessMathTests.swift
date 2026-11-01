import XCTest
@testable import NativeBrightness

final class BrightnessMathTests: XCTestCase {
    func testClampsBrightnessToSafeRange() {
        XCTAssertEqual(BrightnessMath.clamped(-0.2), 0)
        XCTAssertEqual(BrightnessMath.clamped(1.2), 1)
        XCTAssertEqual(BrightnessMath.clamped(0.42), 0.42)
        XCTAssertEqual(BrightnessMath.clamped(.infinity), 1)
        XCTAssertEqual(BrightnessMath.clamped(.nan), 1)
    }

    func testRoundsPercentageForDisplay() {
        XCTAssertEqual(BrightnessMath.percentage(0.0), 0)
        XCTAssertEqual(BrightnessMath.percentage(0.504), 50)
        XCTAssertEqual(BrightnessMath.percentage(0.995), 100)
    }
}
