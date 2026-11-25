#if canImport(UIKit) && os(iOS)
    import UIKit

    /// Background time from `UIApplication`, resolved at run time.
    ///
    /// `UIApplication.shared` is unavailable in app extensions, and a package that names it breaks the build of any
    /// extension that links SentinelKit. So the application is looked up dynamically, and not at all inside an
    /// extension (`.appex`), where no extra time is asked for.
    final class UIKitBackgroundTasks: BackgroundTaskRunning {

        // MARK: - Properties

        private var application: UIApplication? {
            guard Bundle.main.bundleURL.pathExtension != "appex" else {
                return nil
            }

            return (UIApplication.self as AnyObject).value(forKey: "sharedApplication") as? UIApplication
        }

        // MARK: - Initializer

        nonisolated init() {}

        // MARK: - BackgroundTaskRunning

        func begin(name: String, expiration: @escaping @MainActor @Sendable () -> Void) -> BackgroundTaskID? {
            guard let application else {
                return nil
            }

            let identifier = application.beginBackgroundTask(withName: name, expirationHandler: expiration)

            return identifier == .invalid ? nil : BackgroundTaskID(rawValue: identifier.rawValue)
        }

        func end(_ identifier: BackgroundTaskID) {
            application?.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: identifier.rawValue))
        }
    }
#endif
