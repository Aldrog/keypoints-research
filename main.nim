import
    gtk3, glib, gobject, xlib, gdk_pixbuf, pixbuf_helper,
    math, threadpool
import processes, gui, sift

discard XInitThreads()
gtk3.init_with_argv()
var win = newMainWin()

proc setKeyPoints(kp: seq[tuple[x, y: int]]) =
    let 
        r: range[0..255] = 255
        g: range[0..255] = 0
        b: range[0..255] = 0
    for point in kp:
        win.pixbuf[point.x, point.y] = (r, g, b)
    win.img.set_from_pixbuf(win.pixbuf)
    win.kpBtn.sensitive = true
    win.openBtn.sensitive = true
    win.pBar.fraction = 0

proc checkProgress(gp: gpointer): gboolean {.cdecl.} =
    var w = cast[ptr MainWin](gp)
    let data = sift.pChannel.tryRecv()
    if data.dataAvailable:
        let pEv = data.msg
        if pEv.completed:
            setKeyPoints(pEv.res)
            w.kpBtn.sensitive = true
            w.openBtn.sensitive = true
            return false
        else:
            w.pBar.fraction = pEv.progress.gdouble
    return true

proc startSearch(widget: Widget, data: gpointer) {.cdecl.} =
    if win.pixbuf != nil:
        win.kpBtn.sensitive = false
        win.openBtn.sensitive = false
        discard gIdleAdd(checkProgress, addr(win))
        spawn siftPoints(win.pixbuf, 8, 1.6, pow(2, 1/8))

proc openImage(widget: Widget, data: gpointer) {.cdecl.} =
    var dialog = fileChooserDialogNew("Open Image", win.w, FileChooserAction.Open,
                                      "Cancel", ResponseType.Cancel,
                                      "Open", ResponseType.Accept, nil)
    var res = run(dialog)
    if res == cast[gint](ResponseType.Accept):
        let filename = cast[FileChooser](dialog).filename
        if win.addImage(filename):
            win.kpBtn.sensitive = true
    dialog.destroy

discard gSignalConnect(win.kpBtn, "clicked", gCallback(main.startSearch), nil)
discard gSignalConnect(win.openBtn, "clicked", gCallback(main.openImage), nil)

win.show()
gtk3.main()

