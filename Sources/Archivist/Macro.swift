import ArchivistMacros

@attached(member, names: named(init), named(write))
@attached(extension, conformances: Archivable)
public macro Archivable() = #externalMacro(module: "ArchivistMacros", type: "ArchivableMacro")
