import glib, gdk_pixbuf
export GdkPixBuf

proc `[]`*(pb: GdkPixBuf; x, y: int): tuple[r, g, b: range[0..255]] =
    let p = cast[ptr guchar](cast[ByteAddress](pb.pixels) + y * pb.rowstride + x * pb.n_channels)
    let 
        r = cast[range[0..255]](cast[ptr guchar](cast[ByteAddress](p) + 0)[])
        g = cast[range[0..255]](cast[ptr guchar](cast[ByteAddress](p) + 1)[])
        b = cast[range[0..255]](cast[ptr guchar](cast[ByteAddress](p) + 2)[])
    return (r, g, b)

proc `[]=`*(pb: GdkPixBuf; x, y: int, value: tuple[r, g, b: range[0..255]]) =
    let p = cast[ptr guchar](cast[ByteAddress](pb.pixels) + y * pb.rowstride + x * pb.n_channels)
    var 
        r = cast[ptr guchar](cast[ByteAddress](p) + 0)
        g = cast[ptr guchar](cast[ByteAddress](p) + 1)
        b = cast[ptr guchar](cast[ByteAddress](p) + 2)
    r[] = cast[guchar](value.r)
    g[] = cast[guchar](value.g)
    b[] = cast[guchar](value.b)

