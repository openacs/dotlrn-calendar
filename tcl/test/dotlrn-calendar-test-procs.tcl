ad_library {

        Automated tests for the dotlrn-calendar package.

        @author Héctor Romojaro <hector.romojaro@gmail.com>
        @creation-date 2019-09-05

}

aa_register_case \
    -cats {api smoke production_safe} \
    -procs {
        dotlrn_calendar::package_key
        dotlrn_calendar::my_package_key
        dotlrn_calendar::applet_key
    } \
    dotlrn_calendar__keys {

        Simple test for the various dotlrn_calendar::..._key procs.

        @author Héctor Romojaro <hector.romojaro@gmail.com>
        @creation-date 2019-09-05
} {
    aa_equals "Package key" "[dotlrn_calendar::package_key]" "calendar"
    aa_equals "My Package key" "[dotlrn_calendar::my_package_key]" "dotlrn-calendar"
    aa_equals "Applet key" "[dotlrn_calendar::applet_key]" "dotlrn_calendar"
}

# Local variables:
#    mode: tcl
#    tcl-indent-level: 4
#    indent-tabs-mode: nil
# End:
