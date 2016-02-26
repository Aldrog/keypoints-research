import
    gtk3, glib, gobject, gdk_pixbuf, pixbuf_helper, sift

gtk3.init_with_argv()
var window = window_new()
var pixbuf: GdkPixBuf
var mainImage = image_new_from_pixbuf(pixbuf)

proc filter(widget: Widget, data: gpointer) {.cdecl.} =
    if pixbuf != nil:
        let keyP = siftPoints(pixbuf)
        #gaussianFilter(pixbuf, 2)
        let 
            kpcR: range[0..255] = 255
            kpcG: range[0..255] = 0
            kpcB: range[0..255] = 0
        for kp in keyP:
            pixbuf[kp.x, kp.y] = (kpcR, kpcG, kpcB)
        mainImage.set_from_pixbuf(pixbuf)

proc openImage(widget: Widget, data: gpointer) {.cdecl.} =
    var dialog = file_chooser_dialog_new("Open Image", window, FileChooserAction.OPEN,
                                         "Cancel", ResponseType.CANCEL,
                                         "Open", ResponseType.ACCEPT, nil)
    var res = run(dialog)
    if res == cast[gint](ResponseType.ACCEPT):
        let filename = cast[FileChooser](dialog).filename
        var err: GError
        pixbuf = new_from_file(filename, err)
        if pixbuf == nil:
            echo err.message
        else:
            mainImage.set_from_pixbuf(pixbuf)
    dialog.destroy

discard g_signal_connect(window, "destroy", g_callback(main_quit), nil)
window.border_width = 0
window.resizable = false

var windowTitlebar = header_bar_new()
windowTitlebar.title = "SIFT"
windowTitlebar.show_close_button = true
var startBtn = button_new()
startBtn.label = "Find Keypoints"
discard g_signal_connect(startBtn, "clicked", g_callback(main.filter), nil)
windowTitlebar.pack_start(startBtn)
var openBtn = button_new_from_icon_name("document-open", IconSize.Button)
discard g_signal_connect(openBtn, "clicked", g_callback(main.openImage), nil)
windowTitlebar.pack_end(openBtn)
window.titlebar = windowTitlebar

window.add(mainImage)

window.show_all
gtk3.main()

