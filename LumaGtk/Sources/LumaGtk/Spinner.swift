import Adw
import Gtk

#if HAS_ADW_SPINNER
typealias Spinner = Adw.Spinner

func makeSpinner() -> Spinner {
    Spinner()
}
#else
typealias Spinner = Gtk.Spinner

func makeSpinner() -> Spinner {
    let spinner = Spinner()
    spinner.spinning = true
    return spinner
}
#endif
