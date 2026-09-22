public extension AccessibilityID {
    enum Voyage {
        public static let modeCard = "Voyage Mode Card"
        public static let screen = "Voyage Screen"
        public static let progress = "Voyage Progress"
        public static let options = "Voyage Options"
        public static let confirmAbandon = "Confirm Abandon Voyage"
        public static let refresh = "Refresh Voyages"
        public static let abandon = "Abandon Voyage"
        public static let completed = "Voyage Complete"
        public static func row(_ id: String) -> String {
            "Voyage Row \(id)"
        }

        public static func artwork(_ id: String) -> String {
            "Voyage Artwork \(id)"
        }

        public static func action(_ id: String) -> String {
            "Voyage Action \(id)"
        }

        public static func detail(_ id: String) -> String {
            "Voyage Detail \(id)"
        }

        public static func party(_ id: String) -> String {
            "Voyage Party \(id)"
        }
    }
}
