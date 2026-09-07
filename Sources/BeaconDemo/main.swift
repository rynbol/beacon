import Foundation
import BeaconKit

let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Singapore")!
    return c
}()
func at(_ m: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
    cal.date(from: DateComponents(year: 2026, month: m, day: d, hour: h, minute: mi))!
}
let now = at(8, 26, 14, 3)
let tasks = [
    TaskSnapshot(key: "k1", title: "Pay rent", due: at(8, 20, 9, 0)),          // 6 days past due
    TaskSnapshot(key: "k2", title: "Call the dentist", due: nil),               // undated
    TaskSnapshot(key: "k3", title: "Submit the expense report", due: at(8, 26, 15, 0)),
    TaskSnapshot(key: "k4", title: "Water the plants", due: at(8, 26, 15, 0)),  // same minute as k3
    TaskSnapshot(key: "k5", title: "Renew the Beacon signing profile", due: at(8, 27, 23, 30)),
]
let state = ["k1": TaskState(snoozeCount: 4)]   // snoozed four times already

let plan = Scheduler.plan(now: now, tasks: tasks, state: state, settings: .default, calendar: cal)

let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone
f.dateFormat = "EEE dd MMM HH:mm"
print("now = \(f.string(from: now))   slots used: \(plan.notifications.count)/50\n")
for n in plan.notifications {
    let when: String
    switch n.trigger {
    case .repeatingDaily(let h, let m): when = String(format: "daily %02d:%02d", h, m)
    case .oneShot(let d): when = f.string(from: d)
    }
    print(String(format: "%-11@ %-22@ %@", n.kind.rawValue as NSString, when as NSString, n.title))
}
