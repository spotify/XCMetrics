import XCTest

import XCMetricsBackendLibTests
import XCMetricsPluginsTests
import XCMetricsTests

var tests = [XCTestCaseEntry]()
tests += XCMetricsBackendLibTests.__allTests()
tests += XCMetricsPluginsTests.__allTests()
tests += XCMetricsTests.__allTests()

XCTMain(tests)
