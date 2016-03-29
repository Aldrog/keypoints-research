import gtk3, glib, gobject, gdk_pixbuf, pixbuf_helper
import processes

type
    MainWin* = object
        w*: WindowPtr
        titleBar*: HeaderBarPtr
        kpBtn*: ButtonPtr
        openBtn*: ButtonPtr
        pixbuf*: GdkPixBufPtr
        img*: ImagePtr
        pBar*: ProgressBarPtr
        #currentProc*: Thread[void]
        curProcChannel*: Channel[EvProcessProgress[seq[tuple[x, y: int]]]]

proc addImage*(mwin: var MainWin, filename: cstring): bool =
    var err: GError
    mwin.pixbuf = newFromFile(filename, err)
    if mwin.pixbuf == nil:
        return false
    else:
        mwin.img.setFromPixbuf(mwin.pixbuf)
        return true

proc newMainWin*(): MainWin =
    result.w = windowNew()
    result.titleBar = headerBarNew()
    result.kpBtn = buttonNewWithLabel("Find Keypoints")
    result.openBtn = buttonNewFromIconName("document-open", IconSize.Button)
    #result.pixbuf
    result.img = imageNewFromPixbuf(result.pixbuf)
    result.pBar = progressBarNew()

    var mainContainer = boxNew(Orientation.Vertical, 0)
    discard gSignalConnect(result.w, "destroy", gCallback(mainQuit), nil)
    result.w.borderWidth = 0
    result.w.resizable = false

    result.titleBar.title = "SIFT"
    result.titleBar.showCloseButton = true
    result.kpBtn.sensitive = false
    result.titleBar.packStart(result.kpBtn)
    result.titleBar.packEnd(result.openBtn)
    result.w.titlebar = result.titleBar

    mainContainer.pack_start(result.img, true, false, 0)
    mainContainer.pack_end(result.pBar, true, false, 0)
    result.w.add(mainContainer)

proc show*(mwin: MainWin) =
    mwin.w.showAll

