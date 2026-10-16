import Foundation

/// A gamma-encoded sRGB color with components in 0...1.
public struct SRGB: Hashable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    /// Parses "#RRGGBB" or "RRGGBB".
    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        r = Double((value >> 16) & 0xFF) / 255
        g = Double((value >> 8) & 0xFF) / 255
        b = Double(value & 0xFF) / 255
    }

    public var hex: String {
        func byte(_ c: Double) -> Int { Int((min(max(c, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b))
    }

    public var lab: Lab { Lab(xyz: xyz) }

    public var xyz: XYZ {
        let lr = SRGB.linearize(r), lg = SRGB.linearize(g), lb = SRGB.linearize(b)
        return XYZ(
            x: 0.4124564 * lr + 0.3575761 * lg + 0.1804375 * lb,
            y: 0.2126729 * lr + 0.7151522 * lg + 0.0721750 * lb,
            z: 0.0193339 * lr + 0.1191920 * lg + 0.9503041 * lb
        )
    }

    public init(xyz: XYZ) {
        let lr = 3.2404542 * xyz.x - 1.5371385 * xyz.y - 0.4985314 * xyz.z
        let lg = -0.9692660 * xyz.x + 1.8760108 * xyz.y + 0.0415560 * xyz.z
        let lb = 0.0556434 * xyz.x - 0.2040259 * xyz.y + 1.0572252 * xyz.z
        r = SRGB.encode(lr)
        g = SRGB.encode(lg)
        b = SRGB.encode(lb)
    }

    static func linearize(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    static func encode(_ c: Double) -> Double {
        let c = min(max(c, 0), 1)
        return c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
    }
}

public struct XYZ: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// D65 reference white.
    public static let d65 = XYZ(x: 0.95047, y: 1.0, z: 1.08883)
}

/// CIE L*a*b* (D65).
public struct Lab: Hashable, Sendable {
    public var l: Double
    public var a: Double
    public var b: Double

    public init(l: Double, a: Double, b: Double) {
        self.l = l
        self.a = a
        self.b = b
    }

    public init(xyz: XYZ) {
        func f(_ t: Double) -> Double {
            t > 216.0 / 24389.0 ? cbrt(t) : (24389.0 / 27.0 * t + 16) / 116
        }
        let fx = f(xyz.x / XYZ.d65.x)
        let fy = f(xyz.y / XYZ.d65.y)
        let fz = f(xyz.z / XYZ.d65.z)
        l = 116 * fy - 16
        a = 500 * (fx - fy)
        b = 200 * (fy - fz)
    }

    public var chroma: Double { (a * a + b * b).squareRoot() }

    /// Hue angle in degrees, 0..<360.
    public var hue: Double {
        let h = atan2(b, a) * 180 / .pi
        return h >= 0 ? h : h + 360
    }
}

public enum ColorDifference {
    /// CIEDE2000 color difference. Roughly: < 1 is invisible, 2–3 is "barely noticeable", > 10 is obviously different.
    public static func deltaE2000(_ c1: Lab, _ c2: Lab) -> Double {
        func rad(_ d: Double) -> Double { d * .pi / 180 }
        let pow25to7: Double = pow(25.0, 7.0)

        let cBar = (c1.chroma + c2.chroma) / 2
        let g: Double = 0.5 * (1 - (pow(cBar, 7.0) / (pow(cBar, 7.0) + pow25to7)).squareRoot())
        let a1p = (1 + g) * c1.a
        let a2p = (1 + g) * c2.a
        let c1p = (a1p * a1p + c1.b * c1.b).squareRoot()
        let c2p = (a2p * a2p + c2.b * c2.b).squareRoot()

        func hueP(_ x: Double, _ y: Double) -> Double {
            if x == 0 && y == 0 { return 0 }
            let h = atan2(y, x) * 180 / .pi
            return h >= 0 ? h : h + 360
        }
        let h1p = hueP(a1p, c1.b)
        let h2p = hueP(a2p, c2.b)

        let dLp = c2.l - c1.l
        let dCp = c2p - c1p
        var dhp = 0.0
        if c1p * c2p != 0 {
            dhp = h2p - h1p
            if dhp > 180 { dhp -= 360 } else if dhp < -180 { dhp += 360 }
        }
        let dHp: Double = 2 * (c1p * c2p).squareRoot() * sin(rad(dhp / 2))

        let lBarP = (c1.l + c2.l) / 2
        let cBarP = (c1p + c2p) / 2
        var hBarP = h1p + h2p
        if c1p * c2p != 0 {
            if abs(h1p - h2p) > 180 {
                hBarP = (h1p + h2p < 360) ? (h1p + h2p + 360) / 2 : (h1p + h2p - 360) / 2
            } else {
                hBarP = (h1p + h2p) / 2
            }
        }

        let t1: Double = 0.17 * cos(rad(hBarP - 30))
        let t2: Double = 0.24 * cos(rad(2 * hBarP))
        let t3: Double = 0.32 * cos(rad(3 * hBarP + 6))
        let t4: Double = 0.20 * cos(rad(4 * hBarP - 63))
        let t: Double = 1 - t1 + t2 + t3 - t4
        let dTheta: Double = 30 * exp(-pow((hBarP - 275) / 25, 2.0))
        let rc: Double = 2 * (pow(cBarP, 7.0) / (pow(cBarP, 7.0) + pow25to7)).squareRoot()
        let lMinus50Sq: Double = (lBarP - 50) * (lBarP - 50)
        let sl: Double = 1 + 0.015 * lMinus50Sq / (20 + lMinus50Sq).squareRoot()
        let sc: Double = 1 + 0.045 * cBarP
        let sh: Double = 1 + 0.015 * cBarP * t
        let rt: Double = -sin(rad(2 * dTheta)) * rc

        let lTerm = dLp / sl
        let cTerm = dCp / sc
        let hTerm = dHp / sh
        let sum: Double = lTerm * lTerm + cTerm * cTerm + hTerm * hTerm
        return (sum + rt * cTerm * hTerm).squareRoot()
    }
}
