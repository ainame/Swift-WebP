import Foundation

struct ResourceAccessHelper {
    static func getExamplImagePath(of filename: String = "jiro.jpg") -> String {
        let currentFileURL = URL(fileURLWithPath: String(#file))
        return currentFileURL.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("iOS Example")
            .appendingPathComponent("Resources")
            .appendingPathComponent(filename, isDirectory: false)
            .path
    }
}
