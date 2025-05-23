import Archivist
import XCTest

final class ReadableArchiveTests: XCTestCase {

  func testRawRepresentable() throws {
    enum S: String, RawRepresentable { case a, b }
    var r = ReadableArchive(BinaryBuffer("01610162")!)
    XCTAssertEqual(try r.read(rawValueOf: S.self), S.a)
    XCTAssertEqual(try r.read(rawValueOf: S.self), S.b)
    XCTAssertThrowsError(try r.readByte())
  }

  func testReadOrThrow() {
    enum S: String, RawRepresentable { case a, b }
    var r = ReadableArchive(BinaryBuffer("01610261")!)
    var c = () as Any
    XCTAssertEqual(try r.readOrThrow(rawValueOf: S.self, in: &c), S.a)
    XCTAssertThrowsError(try r.readOrThrow(rawValueOf: S.self, in: &c))
  }

  func testByte() {
    var r = ReadableArchive(BinaryBuffer("abcd")!)
    XCTAssertEqual(try r.readByte(), 0xab)
    XCTAssertEqual(try r.readByte(), 0xcd)
    XCTAssertThrowsError(try r.readByte())
  }

  func testInteger() {
    var r = ReadableArchive(BinaryBuffer("ff0000ff")!)
    XCTAssertEqual(try r.read(UInt16.self, endianness: .little), 0xff)
    XCTAssertEqual(try r.read(UInt16.self, endianness: .big), 0xff)
    XCTAssertThrowsError(try r.readByte())
  }

  func testFloatingPoint() {
    var r = ReadableArchive(BinaryBuffer("cdcccccccccc10404010cccccccccccd")!)
    XCTAssertEqual(try r.read(Double.self, endianness: .little), 4.2)
    XCTAssertEqual(try r.read(Double.self, endianness: .big), 4.2)
    XCTAssertThrowsError(try r.readByte())
  }

  func testSignedLEB128() {
    var r = ReadableArchive(BinaryBuffer("2a7e8001")!)
    XCTAssertEqual(try r.readSignedLEB128(), 42)
    XCTAssertEqual(try r.readSignedLEB128(), -2)
    XCTAssertEqual(try r.readSignedLEB128(), 128)
    XCTAssertThrowsError(try r.readByte())

    var s = ReadableArchive(BinaryBuffer("b9aadefc86ff909268")!)
    XCTAssertEqual(try s.readSignedLEB128(), -1719174423445531335)
    XCTAssertThrowsError(try r.readByte())
  }

  func testUnsignedLEB128() {
    var r = ReadableArchive(BinaryBuffer("2a028001")!)
    XCTAssertEqual(try r.readUnsignedLEB128(), 42)
    XCTAssertEqual(try r.readUnsignedLEB128(), 2)
    XCTAssertEqual(try r.readUnsignedLEB128(), 128)
    XCTAssertThrowsError(try r.readByte())
  }

}
