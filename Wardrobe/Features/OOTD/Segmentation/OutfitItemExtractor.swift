import CoreGraphics
import Foundation
import UIKit

/// A source-photo cut-out ready for the OOTD review flow.
struct OutfitItem {
    let category: GarmentCategory
    let cutoutPNG: Data
    let cutoutImage: UIImage
    let mask: UIImage
    /// Fraction of the full source image occupied by this item (0...1).
    let pixelAreaShare: Double
}

struct OutfitItemExtractor {
    let minimumAreaShare: Double

    init(minimumAreaShare: Double = 0.015) {
        self.minimumAreaShare = max(0, minimumAreaShare)
    }

    func extract(from map: ClothLabelMap, image: UIImage) -> [OutfitItem] {
        guard map.width > 0, map.height > 0, map.labels.count == map.width * map.height,
              let source = normalizedCGImage(image) else { return [] }
        let labels = map.labels
        let personArea = labels.reduce(into: 0) { if $1 != ClothClass.background.rawValue { $0 += 1 } }
        guard personArea > 0 else { return [] }

        let areas = Dictionary(grouping: labels, by: { $0 }).mapValues(\.count)
        let bottomKind: UInt8 = (areas[ClothClass.skirt.rawValue, default: 0] > areas[ClothClass.pants.rawValue, default: 0])
            ? ClothClass.skirt.rawValue : ClothClass.pants.rawValue
        var groups: [(Set<UInt8>, GarmentCategory)] = [
            ([ClothClass.upperClothes.rawValue], .tShirt),
            ([ClothClass.pants.rawValue, ClothClass.skirt.rawValue, ClothClass.dress.rawValue], .pants),
            ([ClothClass.leftShoe.rawValue, ClothClass.rightShoe.rawValue], .shoes),
            ([ClothClass.bag.rawValue], .accessory), ([ClothClass.hat.rawValue], .accessory),
            ([ClothClass.scarf.rawValue], .accessory), ([ClothClass.belt.rawValue], .accessory),
            ([ClothClass.sunglasses.rawValue], .accessory)
        ]
        // Dress is a dress only when it dominates the combined top and bottom pixels.
        let dressArea = areas[ClothClass.dress.rawValue, default: 0]
        let topArea = areas[ClothClass.upperClothes.rawValue, default: 0]
        let pantsArea = areas[ClothClass.pants.rawValue, default: 0]
        let skirtArea = areas[ClothClass.skirt.rawValue, default: 0]
        let dominantDress = dressArea > topArea + pantsArea + skirtArea
        if dominantDress {
            groups[1] = ([ClothClass.dress.rawValue], .dress)
        } else {
            groups[1] = ([bottomKind == ClothClass.skirt.rawValue ? ClothClass.skirt.rawValue : ClothClass.pants.rawValue,
                          bottomKind == ClothClass.skirt.rawValue ? ClothClass.pants.rawValue : ClothClass.skirt.rawValue,
                          ClothClass.dress.rawValue], bottomKind == ClothClass.skirt.rawValue ? .skirt : .pants)
        }

        return groups.compactMap { classSet, category in
            var binary = labels.map { classSet.contains($0) }
            if !dominantDress && classSet.contains(ClothClass.dress.rawValue) {
                let bottomArea = pantsArea + skirtArea
                guard dressArea < bottomArea else { return nil }
                let bottomLabels: Set<UInt8> = [ClothClass.pants.rawValue, ClothClass.skirt.rawValue]
                let dressComponents = components(in: labels.map { $0 == ClothClass.dress.rawValue }, width: map.width, height: map.height)
                for component in dressComponents {
                    let touchesBottom = component.contains { index in
                        let x=index % map.width, y=index / map.width
                        return (-1...1).contains { dy in (-1...1).contains { dx in
                            let nx=x+dx, ny=y+dy
                            return nx >= 0 && nx < map.width && ny >= 0 && ny < map.height && bottomLabels.contains(labels[ny*map.width+nx])
                        }}
                    }
                    if !touchesBottom { for index in component { binary[index] = false } }
                }
            }
            guard let primary = largestComponent(in: binary, width: map.width, height: map.height) else { return nil }
            let cutoff = Int(ceil(Double(personArea) * 0.005))
            let keep = components(in: binary, width: map.width, height: map.height).filter { component in
                component.count >= cutoff && (component.contains(where: { primary.contains($0) }) || component.distance(to: primary, width: map.width) <= 8)
            }
            binary = Array(repeating: false, count: binary.count)
            for component in keep { for index in component { binary[index] = true } }
            guard !binary.allSatisfy({ !$0 }) else { return nil }
            binary = close(binary, width: map.width, height: map.height, radius: 2)
            fillSmallHoles(&binary, width: map.width, height: map.height, maximum: Int(Double(binary.filter { $0 }.count) * 0.02))
            let count = binary.filter { $0 }.count
            let share = Double(count) / Double(map.width * map.height)
            guard share >= minimumAreaShare,
                  let rendered = render(binary, mapWidth: map.width, mapHeight: map.height, source: source, transform: map.sourceToModelTransform, category: category, share: share) else { return nil }
            return rendered
        }
    }

    private func normalizedCGImage(_ image: UIImage) -> CGImage? {
        guard let cg = image.cgImage else { return nil }
        if image.imageOrientation == .up { return cg }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }.cgImage
    }

    private func render(_ mask: [Bool], mapWidth: Int, mapHeight: Int, source: CGImage, transform: ClothImageTransform, category: GarmentCategory, share: Double) -> OutfitItem? {
        let width = source.width, height = source.height
        var bytes = [UInt8](repeating: 0, count: width * height)
        // Bilinear sample of the 512 label mask; threshold at 0.5 then soften a one-pixel edge.
        for y in 0..<height { for x in 0..<width {
            let modelX = CGFloat(x) * transform.modelSize.width / CGFloat(width)
            let modelY = CGFloat(y) * transform.modelSize.height / CGFloat(height)
            let fx = Double(modelX) * Double(mapWidth - 1) / Double(max(1, Int(transform.modelSize.width) - 1))
            let fy = Double(modelY) * Double(mapHeight - 1) / Double(max(1, Int(transform.modelSize.height) - 1))
            let x0 = Int(fx), y0 = Int(fy), x1 = min(mapWidth - 1, x0 + 1), y1 = min(mapHeight - 1, y0 + 1)
            let a = fx - Double(x0), b = fy - Double(y0)
            let v = (mask[y0 * mapWidth + x0] ? 1.0 : 0) * (1-a)*(1-b) + (mask[y0 * mapWidth + x1] ? 1.0 : 0) * a*(1-b) + (mask[y1 * mapWidth + x0] ? 1.0 : 0) * (1-a)*b + (mask[y1 * mapWidth + x1] ? 1.0 : 0) * a*b
            bytes[y * width + x] = UInt8(v >= 0.5 ? 255 : 0)
        }}
        // Feather only the boundary pixels by one source pixel.
        let hardMask = bytes
        for y in 0..<height { for x in 0..<width where hardMask[y*width+x] == 0 {
            if [(-1,0),(1,0),(0,-1),(0,1)].contains(where: { dx,dy in
                let nx=x+dx, ny=y+dy
                return nx>=0 && nx<width && ny>=0 && ny<height && hardMask[ny*width+nx] != 0
            }) { bytes[y*width+x] = 96 }
        }}
        guard let bounds = bounds(of: bytes, width: width, height: height) else { return nil }
        let padX = Int(ceil(Double(bounds.width) * 0.04)), padY = Int(ceil(Double(bounds.height) * 0.04))
        let rect = CGRect(x: max(0, bounds.minX-padX), y: max(0, bounds.minY-padY), width: min(width, bounds.maxX+padX)-max(0,bounds.minX-padX), height: min(height,bounds.maxY+padY)-max(0,bounds.minY-padY))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let maskImage = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            UIColor.white.setFill()
            for y in 0..<height {
                var x = 0
                while x < width {
                    guard bytes[y * width + x] > 127 else { x += 1; continue }
                    let start = x
                    while x < width && bytes[y * width + x] > 127 { x += 1 }
                    context.fill(CGRect(x: start, y: y, width: x - start, height: 1))
                }
            }
        }
        guard let fullCutout = try? MaskEditingService().makingCutout(from: UIImage(cgImage: source), using: maskImage) else { return nil }
        let cropSize = rect.integral.size
        let cropFormat = UIGraphicsImageRendererFormat()
        cropFormat.scale = 1
        cropFormat.opaque = false
        let cutout = UIGraphicsImageRenderer(size: cropSize, format: cropFormat).image { _ in
            fullCutout.draw(at: CGPoint(x: -rect.integral.minX, y: -rect.integral.minY))
        }
        return OutfitItem(category: category, cutoutPNG: cutout.pngData() ?? Data(), cutoutImage: cutout, mask: maskImage, pixelAreaShare: share)
    }

    private func bounds(of values: [UInt8], width: Int, height: Int) -> (minX:Int,minY:Int,maxX:Int,maxY:Int,width:Int,height:Int)? {
        var x0=width, y0=height, x1 = -1, y1 = -1
        for i in values.indices where values[i] > 127 { let x=i%width, y=i/width; x0=min(x0,x); y0=min(y0,y); x1=max(x1,x); y1=max(y1,y) }
        return x1 < 0 ? nil : (x0,y0,x1+1,y1+1,x1-x0+1,y1-y0+1)
    }

    private func components(in mask: [Bool], width: Int, height: Int) -> [[Int]] {
        var seen = [Bool](repeating: false, count: mask.count), result = [[Int]]()
        for start in mask.indices where mask[start] && !seen[start] {
            var queue=[start], head=0; seen[start]=true
            while head < queue.count { let i=queue[head]; head += 1; let x=i%width,y=i/width
                for (nx,ny) in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)] where nx>=0 && nx<width && ny>=0 && ny<height {
                    let n=ny*width+nx; if mask[n] && !seen[n] { seen[n]=true; queue.append(n) }
                }
            }
            result.append(queue)
        }
        return result
    }
    private func largestComponent(in mask:[Bool],width:Int,height:Int)->Set<Int>? { components(in:mask,width:width,height:height).max(by:{$0.count<$1.count}).map(Set.init) }
    private func close(_ input:[Bool],width:Int,height:Int,radius:Int)->[Bool] {
        func morph(_ source:[Bool],dilate:Bool)->[Bool] { (0..<source.count).map { i in let x=i%width,y=i/width; var found = !dilate
            for dy in -radius...radius { for dx in -radius...radius where dx*dx+dy*dy<=radius*radius { let nx=x+dx,ny=y+dy; let value=nx>=0 && nx<width && ny>=0 && ny<height ? source[ny*width+nx] : false; if dilate && value { found=true }; if !dilate && !value { found=false } } }
            return found
        }}
        return morph(morph(input,dilate:true),dilate:false)
    }
    private func fillSmallHoles(_ mask:inout [Bool],width:Int,height:Int,maximum:Int) {
        let inverse=mask.map(!), holes=components(in:inverse,width:width,height:height)
        for hole in holes where hole.count <= maximum && !hole.contains(where:{ let x=$0%width,y=$0/width; return x==0 || y==0 || x==width-1 || y==height-1 }) { for i in hole { mask[i]=true } }
    }
}

private extension Array where Element == Int {
    func distance(to other:Set<Int>,width:Int)->Int {
        let nearby = Set(other)
        for d in 1...8 {
            for i in self {
                let x = i % width
                let y = i / width
                for dy in -d...d {
                    for dx in -d...d where Swift.max(abs(dx), abs(dy)) == d {
                        let nx = x + dx
                        let ny = y + dy
                        if nx >= 0 && nx < width && ny >= 0 && nearby.contains(ny * width + nx) {
                            return d
                        }
                    }
                }
            }
        }
        return Int.max
    }
}
