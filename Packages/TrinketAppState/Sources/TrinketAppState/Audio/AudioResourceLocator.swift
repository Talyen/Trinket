import Foundation

enum AudioResourceLocator {
    nonisolated static func url(
        resourceName: String,
        fileExtension: String,
        subdirectory: String? = nil,
    ) -> URL? {
        if let direct = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) {
            return direct
        }
        if let subdirectory {
            if let sub = Bundle.main.url(
                forResource: resourceName,
                withExtension: fileExtension,
                subdirectory: subdirectory,
            ) {
                return sub
            }
            if let mediaSub = Bundle.main.url(
                forResource: resourceName,
                withExtension: fileExtension,
                subdirectory: "Media/\(subdirectory)",
            ) {
                return mediaSub
            }
        }
        return nil
    }
}
