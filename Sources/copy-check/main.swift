import RainGraph

for scenario in Scenario.allCases {
    let copy = RainCopy(scenario.forecast)
    let (lead, value, unit) = copy.circular()
    let label = [lead, value, unit].compactMap { $0 }.joined(separator: " ")
    print(scenario.rawValue.padding(toLength: 34, withPad: " ", startingAt: 0),
          "| \(label)".padding(toLength: 12, withPad: " ", startingAt: 0),
          "| \(copy.headline)".padding(toLength: 26, withPad: " ", startingAt: 0),
          "| \(copy.detail ?? "")".padding(toLength: 28, withPad: " ", startingAt: 0),
          "| \(copy.short)")
}
