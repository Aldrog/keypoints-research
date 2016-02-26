import 
    math, sequtils, colors, gdk_pixbuf, pixbuf_helper

proc brightness(c: tuple[r, g, b: range[0..255]]): float =
    toFloat(c.r + c.g + c.b)

type BMap = seq[seq[float]]
type Octave = seq[BMap]

proc newBMap(w, h: int): BMap =
    newSeqWith(h, newSeq[float](w))

proc width(bm: BMap): int =
    bm[0].len
proc height(bm: BMap): int =
    bm.len

proc newOctave(n, w, h: int): Octave =
    newSeqWith(n, newBMap(w, h))

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

proc gaussianFilter*(img: GdkPixBuf, r: float) =
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


proc resample(img: BMap, k: int): BMap =
    result = newBMap(toInt(img.width / k) + 1, toInt(img.height / k) + 1)
    for y in 0..<img.height:
        for x in 0..<img.width:
            result[toInt(y / k)][toInt(x / k)] = img[y][x] / toFloat(k^2)

proc buildOctaves(img: BMap, N: int, k: float): seq[Octave] =
    result.newSeq(0)
    const sigma0 = 1.6
    var sigma = sigma0
    var curImg = img
    while true:
        if min(curImg.width, curImg.height) <= 10:
            return
        var octave = newOctave(N, curImg.width, curImg.height)
        for i in 0..N:
            for y in 0..<curImg.height:
                for x in 0..<curImg.width:
                    let g = gaussianCoef(curImg, x, y, sigma * pow(k, (i+1).float))
                    if i < N:
                        octave[i][y][x] += g
                    if i > 0:
                        octave[i - 1][y][x] -= g
        result.add(octave)
        curImg = resample(curImg, 2)
        sigma *= 2

proc siftPoints*(img: GdkPixBuf): seq[tuple[x, y: int]] =
    result.newSeq(0)
    const N = 8
    const k = pow(2, 1/N)
    var imgBMap = newBMap(img.width, img.height)
    for y in 0..<img.height:
        for x in 0..<img.width:
            imgBMap[y][x] = img[x, y].brightness
    let octaves = buildOctaves(imgBMap, N, k)
    for oct in octaves:
        for i in 1..<(N - 1):
            for y in 1..<(oct[0].height - 1):
                for x in 1..<(oct[0].width - 1):
                    var kp = true
                    for di in -1..1:
                        for dx in -1..1:
                            for dy in -1..1:
                                if (di != 0 or dx != 0 or dy != 0) and
                                        oct[i][y][x] <= oct[i + di][y + dy][x + dx]:
                                    kp = false
                    if kp:
                        result.add((x, y))
                    else:
                        kp = true
                        for di in -1..1:
                            for dx in -1..1:
                                for dy in -1..1:
                                    if (di != 0 or dx != 0 or dy != 0) and
                                            oct[i][y][x] >= oct[i + di][y + dy][x + dx]:
                                        kp = false
                        if kp:
                            result.add((x, y))
                    if kp: echo x, " ", y
    for y in 0..<img.height:
        for x in 0..<img.width:
            let
                r: range[0..255] = (octaves[0][N - 1][y][x] / 3).int + 127
                g: range[0..255] = (octaves[0][N - 1][y][x] / 3).int + 127
                b: range[0..255] = (octaves[0][N - 1][y][x] / 3).int + 127
            #img[x, y] = (r, g, b)

