import PackStream


extension PackProtocol {
  public var int: Int? {
    guard let intValue = intValue() else { return nil }

    return Int(intValue)
  }
}
