import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testLocalSensitiveDataBackupExcluderMarksDirectoryAsExcluded() throws {
    let directoryUrl = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: directoryUrl,
      withIntermediateDirectories: true
    )
    defer {
      try? FileManager.default.removeItem(at: directoryUrl)
    }

    let excluded = try LocalSensitiveDataBackupExcluder()
      .excludeDirectory(atPath: directoryUrl.path)
    let values = try directoryUrl.resourceValues(forKeys: [.isExcludedFromBackupKey])

    XCTAssertTrue(excluded)
    XCTAssertEqual(values.isExcludedFromBackup, true)
  }

}
