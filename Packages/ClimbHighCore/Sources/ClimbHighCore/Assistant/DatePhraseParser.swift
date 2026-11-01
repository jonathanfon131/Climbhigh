import Foundation

/// A date/time phrase found inside a sentence.
public struct DatePhraseMatch: Equatable, Sendable {
    /// When the phrase points to (whole minute).
    public let date: Date
    /// The sentence with the date/time words removed, original capitalization kept.
    public let remainder: String
}

/// Understands everyday date phrases in typed or spoken text, e.g.
/// "in 20 minutes", "tomorrow at 5pm", "friday", "next monday at 8:30",
/// "march 5th", "3/14", "tonight", "at noon", "in two hours".
///
/// Rules for a time without am/pm:
/// - "morning / afternoon / evening / tonight" nearby decides it.
/// - 1–6 means afternoon/evening (nobody sets a reminder for 3 AM by voice).
/// - 7–11 means morning, unless the morning time already passed today and
///   the evening one hasn't — then evening.
/// - A named day with no time uses `defaultTime` (9:00 AM).
public struct DatePhraseParser: Sendable {
    public var calendar: Calendar
    public var defaultTime: TimeOfDay

    public init(calendar: Calendar = .current, defaultTime: TimeOfDay = TimeOfDay(hour: 9)) {
        self.calendar = calendar
        self.defaultTime = defaultTime
    }

    public func parse(_ input: String, now: Date) -> DatePhraseMatch? {
        var text = Self.normalize(input)

        let relative = takeRelative(from: &text)
        let day = takeDay(from: &text)
        let partOfDay = takePartOfDay(from: &text) ?? day?.impliedPartOfDay
        let clock = takeClockTime(from: &text)

        guard relative != nil || day != nil || partOfDay != nil || clock != nil,
              let date = resolve(relative: relative, day: day, partOfDay: partOfDay, clock: clock, now: now)
        else { return nil }

        let remainder = Self.restoreCase(of: Self.tidy(text), from: input)
        return DatePhraseMatch(date: ReminderSchedule.wholeMinute(date), remainder: remainder)
    }
}

// MARK: - The pieces a phrase can contain

private struct RelativeAmount {
    let value: Int
    let component: Calendar.Component
}

private enum DayReference {
    case today, tonight, tomorrow, dayAfterTomorrow
    /// 1 = Sunday … 7 = Saturday. "next friday" excludes today.
    case weekday(Int, excludingToday: Bool)
    case monthDay(month: Int, day: Int)

    var impliedPartOfDay: PartOfDay? {
        if case .tonight = self { return .night }
        return nil
    }
}

private enum PartOfDay {
    case morning, afternoon, evening, night

    var defaultTime: TimeOfDay {
        switch self {
        case .morning: TimeOfDay(hour: 9)
        case .afternoon: TimeOfDay(hour: 15)
        case .evening: TimeOfDay(hour: 19)
        case .night: TimeOfDay(hour: 20)
        }
    }
}

private struct ClockTime {
    enum Meridiem { case am, pm }
    var hour: Int
    var minute: Int
    var meridiem: Meridiem?
}

// MARK: - Finding phrases (each one removes what it matched from `text`)

extension DatePhraseParser {
    private func takeRelative(from text: inout String) -> RelativeAmount? {
        if let match = text.firstMatch(of: #/\bin half an? hour\b/#) {
            text.removeSubrange(match.range)
            return RelativeAmount(value: 30, component: .minute)
        }
        guard let match = text.firstMatch(of: #/\bin (\d{1,4}|an?) (minutes?|mins?|hours?|hrs?|days?|weeks?)\b/#) else {
            return nil
        }
        let value = Int(match.output.1) ?? 1 // "a" / "an" → 1
        let unit = match.output.2
        let component: Calendar.Component =
            unit.hasPrefix("m") ? .minute :
            unit.hasPrefix("h") ? .hour :
            unit.hasPrefix("d") ? .day : .weekOfYear
        text.removeSubrange(match.range)
        return RelativeAmount(value: value, component: component)
    }

    private func takeDay(from text: inout String) -> DayReference? {
        if let match = text.firstMatch(of: #/\b(?:the )?day after tomorrow\b/#) {
            text.removeSubrange(match.range)
            return .dayAfterTomorrow
        }
        if let match = text.firstMatch(of: #/\b(?:tomorrow|tmrw)\b/#) {
            text.removeSubrange(match.range)
            return .tomorrow
        }
        if let match = text.firstMatch(of: #/\btonight\b/#) {
            text.removeSubrange(match.range)
            return .tonight
        }
        if let match = text.firstMatch(of: #/\btoday\b/#) {
            text.removeSubrange(match.range)
            return .today
        }
        if let match = text.firstMatch(of: #/\b(?:on )?(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sept|sep|oct|nov|dec) (\d{1,2})(?:st|nd|rd|th)?\b/#),
           let month = Self.monthNumber(String(match.output.1)),
           let day = Int(match.output.2), (1...31).contains(day) {
            text.removeSubrange(match.range)
            return .monthDay(month: month, day: day)
        }
        if let match = text.firstMatch(of: #/\b(?:on )?(\d{1,2})\/(\d{1,2})\b/#),
           let month = Int(match.output.1), (1...12).contains(month),
           let day = Int(match.output.2), (1...31).contains(day) {
            text.removeSubrange(match.range)
            return .monthDay(month: month, day: day)
        }
        if let match = text.firstMatch(of: #/\b(?:(next|this|coming|on) )?(sunday|monday|tuesday|wednesday|thursday|friday|saturday)\b/#),
           let index = Self.weekdayNames.firstIndex(of: String(match.output.2)) {
            let qualifier = match.output.1.map { String($0) }
            let excludingToday = qualifier == "next"
            text.removeSubrange(match.range)
            return .weekday(index + 1, excludingToday: excludingToday)
        }
        return nil
    }

    private func takePartOfDay(from text: inout String) -> PartOfDay? {
        if let match = text.firstMatch(of: #/\b(?:this|in the) (morning|afternoon|evening)\b/#) {
            let word = match.output.1
            text.removeSubrange(match.range)
            return word == "morning" ? .morning : word == "afternoon" ? .afternoon : .evening
        }
        if let match = text.firstMatch(of: #/\bat night\b/#) {
            text.removeSubrange(match.range)
            return .night
        }
        return nil
    }

    private func takeClockTime(from text: inout String) -> ClockTime? {
        if let match = text.firstMatch(of: #/\b(?:at |by |around )?(noon|midday|midnight)\b/#) {
            let isMidnight = match.output.1 == "midnight"
            text.removeSubrange(match.range)
            return ClockTime(hour: isMidnight ? 0 : 12, minute: 0, meridiem: isMidnight ? .am : .pm)
        }
        if let match = text.firstMatch(of: #/\b(?:at |by |around )?(\d{1,2}):(\d{2}) ?(am|pm)?\b/#),
           let hour = Int(match.output.1), let minute = Int(match.output.2),
           let time = Self.validClock(hour: hour, minute: minute, meridiem: match.output.3.map { String($0) }) {
            text.removeSubrange(match.range)
            return time
        }
        if let match = text.firstMatch(of: #/\b(?:at |by |around )?(\d{1,2}) ?(am|pm)\b/#),
           let hour = Int(match.output.1),
           let time = Self.validClock(hour: hour, minute: 0, meridiem: String(match.output.2)) {
            text.removeSubrange(match.range)
            return time
        }
        if let match = text.firstMatch(of: #/\b(?:at|by|around) (\d{1,2})\b/#),
           let hour = Int(match.output.1),
           let time = Self.validClock(hour: hour, minute: 0, meridiem: nil) {
            text.removeSubrange(match.range)
            return time
        }
        return nil
    }

    private static func validClock(hour: Int, minute: Int, meridiem: String?) -> ClockTime? {
        guard (0...59).contains(minute) else { return nil }
        switch meridiem {
        case "am": return (1...12).contains(hour) ? ClockTime(hour: hour, minute: minute, meridiem: .am) : nil
        case "pm": return (1...12).contains(hour) ? ClockTime(hour: hour, minute: minute, meridiem: .pm) : nil
        default: return (0...23).contains(hour) ? ClockTime(hour: hour, minute: minute, meridiem: nil) : nil
        }
    }
}

// MARK: - Turning the pieces into a date

extension DatePhraseParser {
    private func resolve(relative: RelativeAmount?, day: DayReference?, partOfDay: PartOfDay?, clock: ClockTime?, now: Date) -> Date? {
        if let relative {
            guard let moved = calendar.date(byAdding: relative.component, value: relative.value, to: now) else { return nil }
            let isWholeDays = relative.component == .day || relative.component == .weekOfYear
            if isWholeDays, let time = timeOfDay(clock: clock, partOfDay: partOfDay, on: moved, now: now) {
                return time.on(moved, calendar: calendar)
            }
            return moved
        }

        let today = calendar.startOfDay(for: now)

        // Only a time was given: today if it's still ahead, otherwise tomorrow.
        guard let day else {
            guard let time = timeOfDay(clock: clock, partOfDay: partOfDay, on: today, now: now),
                  let candidate = time.on(today, calendar: calendar)
            else { return nil }
            return candidate > now ? candidate : calendar.date(byAdding: .day, value: 1, to: candidate)
        }

        guard let dayDate = date(for: day, today: today) else { return nil }
        let explicitTime = timeOfDay(clock: clock, partOfDay: partOfDay, on: dayDate, now: now)
        guard let candidate = (explicitTime ?? defaultTime).on(dayDate, calendar: calendar) else { return nil }
        guard candidate <= now else { return candidate }

        // The day+time already passed.
        switch day {
        case .weekday:
            return calendar.date(byAdding: .day, value: 7, to: candidate)
        case .today, .tonight:
            // "today" with no time after 9 AM → an hour from now.
            return explicitTime == nil ? now.addingTimeInterval(3600) : candidate
        default:
            return candidate
        }
    }

    private func date(for day: DayReference, today: Date) -> Date? {
        switch day {
        case .today, .tonight:
            return today
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: today)
        case .dayAfterTomorrow:
            return calendar.date(byAdding: .day, value: 2, to: today)
        case let .weekday(weekday, excludingToday):
            let current = calendar.component(.weekday, from: today)
            var delta = (weekday - current + 7) % 7
            if delta == 0 && excludingToday { delta = 7 }
            return calendar.date(byAdding: .day, value: delta, to: today)
        case let .monthDay(month, dayOfMonth):
            let year = calendar.component(.year, from: today)
            for candidateYear in [year, year + 1] {
                var parts = DateComponents()
                parts.year = candidateYear
                parts.month = month
                parts.day = dayOfMonth
                guard let date = calendar.date(from: parts),
                      calendar.component(.month, from: date) == month // rejects "feb 31"
                else { return nil }
                if date >= today { return date }
            }
            return nil
        }
    }

    private func timeOfDay(clock: ClockTime?, partOfDay: PartOfDay?, on day: Date, now: Date) -> TimeOfDay? {
        guard let clock else { return partOfDay?.defaultTime }
        var hour = clock.hour

        switch clock.meridiem {
        case .am:
            if hour == 12 { hour = 0 }
        case .pm:
            if hour < 12 { hour += 12 }
        case nil:
            if let partOfDay {
                if partOfDay != .morning, hour < 12 { hour += 12 }
            } else if (1...6).contains(hour) {
                hour += 12
            } else if (7...11).contains(hour), calendar.isDate(day, inSameDayAs: now),
                      let morning = TimeOfDay(hour: hour, minute: clock.minute).on(day, calendar: calendar),
                      let evening = TimeOfDay(hour: hour + 12, minute: clock.minute).on(day, calendar: calendar),
                      morning <= now, evening > now {
                hour += 12
            }
        }
        return TimeOfDay(hour: hour, minute: clock.minute)
    }
}

// MARK: - Text clean-up

extension DatePhraseParser {
    static let weekdayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

    static func monthNumber(_ name: String) -> Int? {
        let prefixes = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        return prefixes.firstIndex { name.hasPrefix($0) }.map { $0 + 1 }
    }

    /// Lowercases, turns "p.m." into "pm", strips punctuation, and turns
    /// spoken numbers into digits where they're clearly about time
    /// ("in five minutes" → "in 5 minutes", "at five thirty" → "at 5:30").
    static func normalize(_ input: String) -> String {
        var text = input.lowercased()
        for (from, to) in [("a.m.", "am"), ("p.m.", "pm"), ("o'clock", ""), ("o’clock", ""), ("’", "'")] {
            text = text.replacingOccurrences(of: from, with: to)
        }
        text = String(text.map { ",.!?;\"".contains($0) ? " " : $0 })
        return SpokenNumbers.digitize(collapseSpaces(text))
    }

    /// Removes leftover connector words such as a dangling "at" or "on".
    static func tidy(_ text: String) -> String {
        var words = collapseSpaces(text).split(separator: " ").map(String.init)
        let dangling: Set<String> = ["at", "on", "by", "in", "for", "around", "this", "the", "next"]
        while let last = words.last, dangling.contains(last) { words.removeLast() }
        return words.joined(separator: " ")
    }

    /// Puts back the original capitalization ("call john" → "call John").
    static func restoreCase(of lowered: String, from original: String) -> String {
        let originalWords = original.split(whereSeparator: \.isWhitespace).map(String.init)
        let trimSet = CharacterSet(charactersIn: ",.!?;\"")
        var cursor = 0
        var result: [String] = []
        for word in lowered.split(separator: " ").map(String.init) {
            var replacement = word
            var search = cursor
            while search < originalWords.count {
                let candidate = originalWords[search].trimmingCharacters(in: trimSet)
                if candidate.lowercased() == word {
                    replacement = candidate
                    cursor = search + 1
                    break
                }
                search += 1
            }
            result.append(replacement)
        }
        return result.joined(separator: " ")
    }

    static func collapseSpaces(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

/// Converts spoken number words to digits, only where they're about time.
enum SpokenNumbers {
    private static let small: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9,
        "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
        "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19
    ]
    private static let tens: [String: Int] = ["twenty": 20, "thirty": 30, "forty": 40, "fifty": 50]
    private static let units: Set<String> = [
        "minute", "minutes", "min", "mins", "hour", "hours", "hr", "hrs",
        "day", "days", "week", "weeks", "am", "pm"
    ]
    private static let leadIns: Set<String> = ["in", "at", "by", "around"]
    private static let clockLeadIns: Set<String> = ["at", "by", "around"]

    static func digitize(_ text: String) -> String {
        let tokens = text.split(separator: " ").map(String.init)
        var output: [String] = []
        var index = 0
        while index < tokens.count {
            guard let spoken = number(at: index, in: tokens) else {
                output.append(tokens[index])
                index += 1
                continue
            }
            let value = spoken.value
            let used = spoken.wordCount
            let previous = output.last ?? ""
            let next = index + used < tokens.count ? tokens[index + used] : ""
            guard leadIns.contains(previous) || units.contains(next) else {
                output.append(tokens[index])
                index += 1
                continue
            }
            // "at five thirty" → "at 5:30"
            if clockLeadIns.contains(previous), (1...12).contains(value),
               let minutes = number(at: index + used, in: tokens), (10...59).contains(minutes.value) {
                output.append(String(format: "%d:%02d", value, minutes.value))
                index += used + minutes.wordCount
                continue
            }
            output.append(String(value))
            index += used
        }
        return output.joined(separator: " ")
    }

    private struct SpokenNumber {
        let value: Int
        let wordCount: Int
    }

    /// The number spelled at `index` and how many words it used ("forty five" → 45, 2 words).
    private static func number(at index: Int, in tokens: [String]) -> SpokenNumber? {
        guard index < tokens.count else { return nil }
        let token = tokens[index]
        let hyphenated = token.split(separator: "-").map(String.init)
        if hyphenated.count == 2, let tensValue = tens[hyphenated[0]], let ones = small[hyphenated[1]], ones < 10 {
            return SpokenNumber(value: tensValue + ones, wordCount: 1)
        }
        if let tensValue = tens[token] {
            if index + 1 < tokens.count, let ones = small[tokens[index + 1]], ones < 10 {
                return SpokenNumber(value: tensValue + ones, wordCount: 2)
            }
            return SpokenNumber(value: tensValue, wordCount: 1)
        }
        if let value = small[token] { return SpokenNumber(value: value, wordCount: 1) }
        return nil
    }
}
