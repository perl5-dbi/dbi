# http://sourceware.org/gdb/current/onlinedocs/gdb/

set breakpoint pending on
b __asan_report_error
set args -Mblib t/50dbm_simple.t
