import Foundation

/// Shared bundle lookup for generated audio catalogs.
///
/// Single home for the audio catalogs' packaged-location fallback order: `<subdirectory>/` first, then
/// `Media/<subdirectory>/`, with a top-level lookup last so a stray
/// top-level file can never shadow the packaged asset.
public enum MediaResourceLocator {
    public nonisolated static func url(
        resourceName: String,
        fileExtension: String?,
        subdirectory: String? = nil,
    ) -> URL? {
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
        return Bundle.main.url(forResource: resourceName, withExtension: fileExtension)
    }
}
