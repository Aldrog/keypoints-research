import 
    math, sequtils, gdk_pixbuf, pixbuf_helper, threadpool
import processes

var octaveCount: int
var pChannel*: Channel[EvProcessProgress[seq[tuple[x, y: int]]]]
pChannel.open()

proc brightness(c: tuple[r, g, b: range[0..255]]): float =
    toFloat(c.r + c.g + c.b)

type BMap = seq[seq[float]]
type Octave = tuple
    dog: seq[BMap]
    scale: int

proc newBMap(w, h: int): BMap =
    newSeqWith(h, newSeq[float](w))

proc width(bm: BMap): int =
    bm[0].len
proc height(bm: BMap): int =
    bm.len

proc newOctave(n, w, h, sc: int): Octave =
    result.dog = newSeqWith(n, newBMap(w, h))
    result.scale = sc

proc multiplyBrightness(c: tuple[r, g, b: range[0..255]],
                        coef: float): tuple[r, g, b: range[0..255]] =
    var
        newR = toInt(c.r.float * coef)
        newG = toInt(c.g.float * coef)
        newB = toInt(c.b.float * coef)
    var r, g, b: range[0..255]
    if newR < 0: r = 0
    elif newR > 255: r = 255
    else: r = newR
    if newG < 0: g = 0
    elif newG > 255: g = 255
    else: g = newG
    if newB < 0: b = 0
    elif newB > 255: b = 255
    else: b = newB
    return (r, g, b)

proc gaussianCoef(img: BMap; x, y: int; radius: float): float =
    var gBrightness = 0'f64
    for i in -toInt(3*radius)..toInt(3*radius):
        for j in -toInt(3*radius)..toInt(3*radius):
            var imgx, imgy: int
            if x + i < 0: imgx = 0
            elif x + i >= img.width: imgx = img.width - 1
            else: imgx = x + i
            if y + j < 0: imgy = 0
            elif y + j >= img.height: imgy = img.height - 1
            else: imgy = y + j
            gBrightness += exp(-(pow(i.float, 2) + pow(j.float, 2)) /
                      (2*pow(radius.float, 2))) * img[imgy][imgx]
    gBrightness /= 2 * PI * pow(radius.float, 2)
    return gBrightness

proc gaussianFilter*(img: var GdkPixBuf, r: float) =
    var imgBMap = newBMap(img.width, img.height)
    for y in 0..<img.height:
        for x in 0..<img.width:
            imgBMap[y][x] = img[x, y].brightness
    for x in 0..<img.width:
        for y in 0..<img.height:
            let
                r: range[0..255] = (gaussianCoef(imgBMap, x, y, r) / 3).int
                g: range[0..255] = r
                b: range[0..255] = r
            img[x, y] = (r, g, b)

proc resample(img: var BMap, k: int) =
    var result = newBMap(ceil(img.width / k).int, ceil(img.height / k).int)
    for y in 0..<img.height:
        for x in 0..<img.width:
            let 
                resX = floor(x / k).int
                resY = floor(y / k).int
            var m = 1
            if resX >= result.width - 1:
                m *= k - (img.width mod k)
            else:
                m *= k
            if floor(y / k).int == result.height - 1:
                m *= k - (img.height mod k)
            else:
                m *= k
            result[resY][resX] += img[y][x] / toFloat(m)
    img = result

proc buildOctave(oct: ptr Octave; img: BMap; N: int; sigma, k: float; scale: int) {.thread.} =
    oct[] = newOctave(N, img.width, img.height, scale)
    for i in 0..N:
        for y in 0..<img.height:
            for x in 0..<img.width:
                let g = gaussianCoef(img, x, y, sigma * pow(k, (i+1).float))
                if i < N:
                    oct.dog[i][y][x] += g
                if i > 0:
                    oct.dog[i - 1][y][x] -= g

proc buildOctaves(img: BMap; N: int; sigma0, k: float): seq[Octave] =
    result.newSeq(ceil(log2(min(img.width, img.height).float)).int)
    octaveCount = 0
    var sigma = sigma0
    var curImg = img
    var curScale = 1
    for i in 0..result.high:
        buildOctave(addr result[i], curImg, N, sigma, k, curScale)
        sigma *= 2
        curImg.resample(2)
        curScale *= 2
        let ev = EvProcessProgress[seq[tuple[x, y: int]]](completed: false,
                                                          progress: i / result.len)
        pChannel.send(ev)

proc siftPoints*(img: GdkPixBuf; octaveSize: int; startRadius, radiusStep: float) {.thread.} =
    var result = newSeq[tuple[x, y: int]](0)
    var imgBMap = newBMap(img.width, img.height)
    for y in 0..<img.height:
        for x in 0..<img.width:
            imgBMap[y][x] = img[x, y].brightness
    let octaves = buildOctaves(imgBMap, octaveSize, startRadius, radiusStep)
    for oct in octaves:
        for i in 1..<(octaveSize - 1):
            for y in 1..<(oct.dog[0].height - 1):
                for x in 1..<(oct.dog[0].width - 1):
                    var kp = true
                    for di in -1..1:
                        for dx in -1..1:
                            for dy in -1..1:
                                if (di != 0 or dx != 0 or dy != 0) and
                                        oct.dog[i][y][x] <= oct.dog[i + di][y + dy][x + dx]:
                                    kp = false
                    if kp:
                        result.add((x, y))
                    else:
                        kp = true
                        for di in -1..1:
                            for dx in -1..1:
                                for dy in -1..1:
                                    if (di != 0 or dx != 0 or dy != 0) and
                                            oct.dog[i][y][x] >= oct.dog[i + di][y + dy][x + dx]:
                                        kp = false
                        if kp:
                            result.add((x * oct.scale, y * oct.scale))
                    #if kp: echo x, " ", y
    echo "Finished"
    let ev = EvProcessProgress[seq[tuple[x, y: int]]](completed: true, res: result)
    pChannel.send(ev)

