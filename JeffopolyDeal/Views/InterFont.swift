import SwiftUI

// Bundled Inter static weights (see project.yml UIAppFonts / Sources/CardKit/Fonts),
// matching the web app's Google Fonts "Inter:wght@400;600;700;800;900" import.
extension Font {
    static func interRegular(_ size: CGFloat) -> Font { .custom("Inter-Regular", size: size) }
    static func interSemiBold(_ size: CGFloat) -> Font { .custom("Inter-SemiBold", size: size) }
    static func interBold(_ size: CGFloat) -> Font { .custom("Inter-Bold", size: size) }
    static func interExtraBold(_ size: CGFloat) -> Font { .custom("Inter-ExtraBold", size: size) }
    static func interBlack(_ size: CGFloat) -> Font { .custom("Inter-Black", size: size) }
}
