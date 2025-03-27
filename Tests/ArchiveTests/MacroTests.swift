import Archivist
import XCTest

final class MacroTests: XCTestCase {

  func testSynthesizedRoundtrip() throws {
    let x = Stuff.c(x: 1, true, z: 2.0)
    let y = Thing(a: 1, b: 2.0, d: false)

    var w = WriteableArchive(BinaryBuffer())
    try w.write(x)
    try w.write(y)

    var r = ReadableArchive(w.finalize())
    XCTAssertEqual(try r.read(Stuff.self), x)
    XCTAssertEqual(try r.read(Thing.self), y)
  }

}

@Archivable
enum Stuff<T: Archivable & Equatable>: Equatable {

  /// A simple case with no associated value.
  case a

  /// A case with an arbitrary archivable associated value.
  case b(T)

  /// A case with two labeled associated values.
  case c(x: Int, Bool, z: T)

}

@Archivable
struct Thing<T: Archivable & Equatable>: Equatable {

  /// A simple archivable field.
  let a: Int

  /// A declaration with two bindings of an arbitrary archivable field.
  let b: T

  /// An immutable field with a default value.
  let c = true

  /// A mutable field with a default value.
  var d = true

  /// A computed property.
  var f: Int { 1 }

  init(a: Int, b: T, d: Bool = true) {
    self.a = a
    self.b = b
    self.d = d
  }

}
