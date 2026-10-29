public func counted(_ count: Int, _ singular: String) -> String {
    "\(count.formatted()) \(count == 1 ? singular : singular + "s")"
}
