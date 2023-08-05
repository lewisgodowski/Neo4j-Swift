import PackStream

extension Structure {
  var subType: ResponseItem.Type? {
    if signature == 78, items.count >= 3 { return Node.self }
    if signature == 80, items.count >= 3 { return Path.self }
    if signature == 88, items.count >= 3 { return Point.self }
    if signature == 82, items.count >= 5 { return Relationship.self }
    if signature == 114, items.count >= 3 { return UnboundRelationship.self }
    return nil
  }
}
