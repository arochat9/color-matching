import Foundation

/// Paint is modelled as a reflectance curve sampled every 10 nm from 400 to 700 nm.
/// Mixing happens on those curves (see `Mixer`), and only the result is turned into a screen color.
/// That is what makes blue + yellow come out green instead of the gray you get from averaging RGB.
public enum Spectral {
    public static let wavelengths: [Double] = Array(stride(from: 400.0, through: 700.0, by: 10.0))
    public static var bandCount: Int { wavelengths.count }

    /// Converts a reflectance curve to an sRGB color, viewed under daylight (D65).
    public static func srgb(fromReflectance reflectance: [Double]) -> SRGB {
        SRGB(xyz: xyz(fromReflectance: reflectance))
    }

    public static func xyz(fromReflectance reflectance: [Double]) -> XYZ {
        var x = 0.0, y = 0.0, z = 0.0
        for i in 0..<bandCount {
            let r = reflectance[i]
            x += weights[i].x * r
            y += weights[i].y * r
            z += weights[i].z * r
        }
        return XYZ(x: x, y: y, z: z)
    }

    /// Builds a curve by evaluating `f` at each wavelength (in nm).
    public static func curve(_ f: (Double) -> Double) -> [Double] {
        wavelengths.map { min(max(f($0), 0.001), 1) }
    }

    /// Smooth step from `low` to `high` centered at `center` nm.
    public static func sigmoid(_ nm: Double, center: Double, width: Double, low: Double, high: Double) -> Double {
        low + (high - low) / (1 + exp(-(nm - center) / width))
    }

    /// Asymmetric Gaussian bump.
    public static func lobe(_ nm: Double, center: Double, left: Double, right: Double) -> Double {
        let s = nm < center ? left : right
        let t = (nm - center) / s
        return exp(-0.5 * t * t)
    }

    // Wyman, Sloan & Shirley (2013) analytic fit of the CIE 1931 2° color matching functions.
    static func colorMatching(_ nm: Double) -> (x: Double, y: Double, z: Double) {
        let x = 1.056 * lobe(nm, center: 599.8, left: 37.9, right: 31.0)
            + 0.362 * lobe(nm, center: 442.0, left: 16.0, right: 26.7)
            - 0.065 * lobe(nm, center: 501.1, left: 20.4, right: 26.2)
        let y = 0.821 * lobe(nm, center: 568.8, left: 46.9, right: 40.5)
            + 0.286 * lobe(nm, center: 530.9, left: 16.3, right: 31.1)
        let z = 1.217 * lobe(nm, center: 437.0, left: 11.8, right: 36.0)
            + 0.681 * lobe(nm, center: 459.0, left: 26.0, right: 13.8)
        return (x, y, z)
    }

    /// Black-body radiation at 6504 K, a close stand-in for daylight.
    static func daylight(_ nm: Double) -> Double {
        let l = nm * 1e-9
        return 1 / (pow(l, 5) * (exp(1.4388e-2 / (l * 6504)) - 1))
    }

    /// Per-band illuminant × CMF weights, scaled so a perfect reflector lands exactly on D65 white.
    static let weights: [(x: Double, y: Double, z: Double)] = {
        let raw = wavelengths.map { nm -> (x: Double, y: Double, z: Double) in
            let e = daylight(nm)
            let c = colorMatching(nm)
            return (e * c.x, e * c.y, e * c.z)
        }
        let sx = raw.reduce(0) { $0 + $1.x }
        let sy = raw.reduce(0) { $0 + $1.y }
        let sz = raw.reduce(0) { $0 + $1.z }
        return raw.map { (
            x: $0.x * XYZ.d65.x / sx,
            y: $0.y * XYZ.d65.y / sy,
            z: $0.z * XYZ.d65.z / sz
        ) }
    }()
}
