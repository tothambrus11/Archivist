import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

public struct ArchivableMacro {
}

extension ArchivableMacro: ExtensionMacro {

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    // Nothing to do if there is an explicit conformance already.
    if protocols.isEmpty { return [] }

    let s: DeclSyntax = """
    extension \(type.trimmed): Archivable {}
    """
    return [s.cast(ExtensionDeclSyntax.self)]
  }

}

extension ArchivableMacro: MemberMacro {

  public static func expansion<Decl: DeclGroupSyntax, Context: MacroExpansionContext>(
    of attribute: AttributeSyntax,
    providingMembersOf decl: Decl,
    in context: Context
  ) throws -> [DeclSyntax] {
    if let d = decl.as(EnumDeclSyntax.self) {
      try expansion(of: attribute, providingMembersOf: d, in: context)
    } else if let d = decl.as(StructDeclSyntax.self) {
      try expansion(of: attribute, providingMembersOf: d, in: context)
    } else {
      throw MacroExpansionErrorMessage(
        "@Archivable can only be attached to an enum or struct declaration.")
    }
  }

  /// Returns the expansion of the macro attached to an enum declaration.
  public static func expansion<Context: MacroExpansionContext>(
    of attribute: AttributeSyntax,
    providingMembersOf declaration: EnumDeclSyntax,
    in context: Context
  ) throws -> [DeclSyntax] {
    let cs = declaration.memberBlock.members
      .compactMap({ (m) in m.decl.as(EnumCaseDeclSyntax.self) })
    let es = cs.flatMap(\.elements)

    let i = try enumDeserializer(es, in: context)
    let w = try enumSerializer(es, in: context)
    return [DeclSyntax(i), DeclSyntax(w)]
  }

  /// Returns the expansion of the macro attached to a struct declaration.
  public static func expansion<Context: MacroExpansionContext>(
    of attribute: AttributeSyntax,
    providingMembersOf declaration: StructDeclSyntax,
    in context: Context
  ) throws -> [DeclSyntax] {
    let (bs, ds) = archivableMembers(of: declaration)
    for d in ds {
      context.diagnose(d)
    }

    let i = try structDeserializer(bs, in: context)
    let w = try structSerializer(bs, in: context)
    return [DeclSyntax(i), DeclSyntax(w)]
  }

  /// Returns the deserializer for an enum containing `es`.
  private static func enumDeserializer<Context: MacroExpansionContext>(
    _ es: [EnumCaseElementSyntax], in context: Context
  ) throws -> InitializerDeclSyntax {
    if es.isEmpty {
      return try InitializerDeclSyntax(deserializerHead(in: context)) { "fatalError()" }
    } else {
      return try InitializerDeclSyntax(deserializerHead(in: context)) {
        try SwitchExprSyntax("switch try archive.readByte()") {
          for (i, e) in es.enumerated() {
            SwitchCaseSyntax("case \(raw: i):") { ExprSyntax("self = \(rhs(e))") }
          }
          SwitchCaseSyntax("default:") { "throw ArchiveError.invalidInput" }
        }
      }
    }

    func rhs(_ e: EnumCaseElementSyntax) -> ExprSyntax {
      let callee = ExprSyntax(".\(e.name)")
      if let clause = e.parameterClause, !clause.parameters.isEmpty {
        return ExprSyntax(
          FunctionCallExprSyntax(callee: callee) {
            for p in clause.parameters {
              LabeledExprSyntax(
                // label: p.firstName.map(String.init(describing:)),
                label: p.firstName?.text,
                expression: ExprSyntax("try archive.read(\(p.type).self, in: &context)"))
            }
          })
      } else {
        return callee
      }
    }
  }

  /// Returns the serializer for an enum containing `es`.
  private static func enumSerializer<Context: MacroExpansionContext>(
    _ es: [EnumCaseElementSyntax], in context: Context
  ) throws -> FunctionDeclSyntax {
    return try FunctionDeclSyntax(serializerHead(in: context)) {
      try SwitchExprSyntax("switch self") {
        for (i, e) in es.enumerated() {
          let (p, ns) = pattern(e)
          SwitchCaseSyntax(p) {
            ExprSyntax("archive.write(byte: \(raw: i))")
            for n in ns { ExprSyntax("try archive.write(\(n), in: &context)") }
          }
        }
      }
    }

    func pattern(_ e: EnumCaseElementSyntax) -> (SyntaxNodeString, [TokenSyntax]) {
      if let clause = e.parameterClause, !clause.parameters.isEmpty {
        let ns = (0 ..< clause.parameters.count).map({ (i) in context.makeUniqueName("x\(i)") })
        let ss = ns.map(\.text).joined(separator: ", ")
        return (SyntaxNodeString("case let .\(e.name)(\(raw: ss)):"), ns)
      } else {
        return (SyntaxNodeString("case .\(e.name):"), [])
      }
    }
  }

  /// Returns the members of `declaration` that must be archived.
  private static func archivableMembers(
    of declaration: StructDeclSyntax
  ) -> ([PatternBindingSyntax], [Diagnostic]) {
    var bs: [PatternBindingSyntax] = []
    var ds: [Diagnostic] = []

    for m in declaration.memberBlock.members {
      guard
        let v = m.decl.as(VariableDeclSyntax.self),
        !v.modifiers.contains(where: isOneOf([.keyword(.static), .keyword(.lazy)])),
        !v.isComputedProperty,
        !v.bindings.isEmpty
      else { continue }

      if v.bindings.count > 1 {
        let m = MacroExpansionErrorMessage("@Archivable does not support binding lists.")
        ds.append(.init(node: v, message: m))
      } else if let b = v.bindings.first, (!v.isLet || b.initializer == nil) {
        bs.append(b)
      }
    }

    return (bs, ds)
  }

  /// Returns the deserializer for a struct containing `bs`.
  private static func structDeserializer<Context: MacroExpansionContext>(
    _ bs: [PatternBindingSyntax], in context: Context
  ) throws -> InitializerDeclSyntax {
    try InitializerDeclSyntax(deserializerHead(in: context)) {
      for b in bs {
        "self.\(b.pattern) = try archive.read(\(b.typeSyntax), in: &context)"
      }
    }
  }

  /// Returns the serializer for a struct containing `bs`.
  private static func structSerializer<Context: MacroExpansionContext>(
    _ bs: [PatternBindingSyntax], in context: Context
  ) throws -> FunctionDeclSyntax {
    try FunctionDeclSyntax(serializerHead(in: context)) {
      for b in bs {
        "try archive.write(\(b.pattern), in: &context)"
      }
    }
  }

  private static func deserializerHead<Context: MacroExpansionContext>(
    in context: Context
  ) -> SyntaxNodeString {
    let a = context.makeUniqueName("Archive")
    return """
      public init<\(a)>(
        from archive: inout ReadableArchive<\(a)>, in context: inout Any
      ) throws
      """
  }

  private static func serializerHead<Context: MacroExpansionContext>(
    in context: Context
  ) -> SyntaxNodeString {
    let a = context.makeUniqueName("Archive")
    return """
    public func write<\(a)>(
      to archive: inout WriteableArchive<\(a)>, in context: inout Any
    ) throws
    """
  }

}

@main
struct ArchivistMacros: CompilerPlugin {

  var providingMacros: [Macro.Type] = [ArchivableMacro.self]

}
