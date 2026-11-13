import RainGraph

for scenario in Scenario.allCases {
    let copy = RainCopy(scenario.forecast)
    let (value, gap) = copy.circular
    let label = gap ?? ""
    print(scenario.rawValue.padding(toLength: 34, withPad: " ", startingAt: 0),
          "| \(value) \(label)".padding(toLength: 12, withPad: " ", startingAt: 0),
          "| \(copy.headline)".padding(toLength: 26, withPad: " ", startingAt: 0),
          "| \(copy.detail ?? "")".padding(toLength: 28, withPad: " ", startingAt: 0),
          "| \(copy.short)")
}
