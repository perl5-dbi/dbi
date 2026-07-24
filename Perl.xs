/* This is a skeleton driver that only serves as a basic sanity check
   that the Driver.xst mechansim doesn't have compile-time errors in it.
   vim: ts=8:sw=4:expandtab
*/

#define PERL_NO_GET_CONTEXT
#include "DBIXS.h"
#include "dbd_xsh.h"

#undef DBIh_SET_ERR_CHAR        /* to syntax check emulation */
#include "dbivport.h"

DBISTATE_DECLARE;


struct imp_drh_st {
    dbih_drc_t com;     /* MUST be first element in structure   */
};
struct imp_dbh_st {
    dbih_dbc_t com;     /* MUST be first element in structure   */
};
struct imp_sth_st {
    dbih_stc_t com;     /* MUST be first element in structure   */
};



#define dbd_discon_all(drh, imp_drh)            ((void)drh, (void)imp_drh, 1)
#define dbd_dr_data_sources(drh, imp_drh, attr) ((void)drh, (void)imp_drh, (void)attr, Nullav)
#define dbd_db_do4_iv(dbh, imp_dbh, p3, p4)      ((void)dbh, (void)imp_dbh, (void)p3, (void)p4, -2)
#define dbd_db_last_insert_id(dbh, imp_dbh, p3, p4, p5, p6, attr) \
        ((void)dbh, (void)imp_dbh, (void)p3, (void)p4, (void)p5, (void)p6, (void)attr, &PL_sv_undef)
#define dbd_take_imp_data(h, imp_xxh, p3)       ((void)h, (void)imp_xxh, (void)p3, &PL_sv_undef)
#define dbd_st_execute_for_fetch(sth, imp_sth, p3, p4) \
        ((void)sth, (void)imp_sth, (void)p3, (void)p4, &PL_sv_undef)
#define dbd_db_STORE_attrib(dbh, imp_dbh, keysv, valuesv) \
        ((void)dbh, (void)imp_dbh, (void)keysv, (void)valuesv, 0)
#define dbd_db_FETCH_attrib(dbh, imp_dbh, keysv) \
        ((void)dbh, (void)imp_dbh, (void)keysv, &PL_sv_undef)
#define dbd_st_STORE_attrib(sth, imp_sth, keysv, valuesv) \
        ((void)sth, (void)imp_sth, (void)keysv, (void)valuesv, 0)
#define dbd_st_FETCH_attrib(sth, imp_sth, keysv) \
        ((void)sth, (void)imp_sth, (void)keysv, &PL_sv_undef)

#define dbd_st_bind_col(sth, imp_sth, param, ref, sql_type, attribs) \
        ((void)sth, (void)imp_sth, (void)param, (void)ref, (void)sql_type, (void)attribs, 1)
#define dbd_init(dbistate)                      ((void)dbistate)
#define dbd_db_login(dbh, imp_dbh, dbname, uid, pwd) \
        ((void)dbh, (void)imp_dbh, (void)dbname, (void)uid, (void)pwd, 1)
#define dbd_db_commit(dbh, imp_dbh)             ((void)dbh, (void)imp_dbh, 1)
#define dbd_db_rollback(dbh, imp_dbh)           ((void)dbh, (void)imp_dbh, 1)
#define dbd_db_disconnect(dbh, imp_dbh)         ((void)dbh, (void)imp_dbh, 1)
#define dbd_db_destroy(dbh, imp_dbh)            ((void)dbh, (void)imp_dbh)
#define dbd_db_data_sources(dbh, imp_dbh, attr) ((void)dbh, (void)imp_dbh, (void)attr, Nullav)
#define dbd_st_prepare(sth, imp_sth, statement, attribs) \
        ((void)sth, (void)imp_sth, (void)statement, (void)attribs, 0)
#define dbd_st_prepare_sv(sth, imp_sth, statement, attribs) \
        ((void)sth, (void)imp_sth, (void)statement, (void)attribs, 0)
#define dbd_st_execute(sth, imp_sth)            ((void)sth, (void)imp_sth, 0)
#define dbd_st_fetch(sth, imp_sth)              ((void)sth, (void)imp_sth, Nullav)
#define dbd_st_finish(sth, imp_sth)             ((void)sth, (void)imp_sth, 1)
#define dbd_st_destroy(sth, imp_sth)            ((void)sth, (void)imp_sth)
#define dbd_st_blob_read(sth, imp_sth, f, o, l, d, do) \
        ((void)sth, (void)imp_sth, (void)f, (void)o, (void)l, (void)d, (void)do, 0)
#define dbd_bind_ph(sth, imp_sth, p, v, t, a, io, m) \
        ((void)sth, (void)imp_sth, (void)p, (void)v, (void)t, (void)a, (void)io, (void)m, 1)

int     /* just to test syntax of macros etc */
dbd_st_rows(SV *h, imp_sth_t *imp_sth)
{
    dTHX;
    PERL_UNUSED_VAR(h);
    DBIh_SET_ERR_CHAR(h, imp_sth, 0, 1, "err msg", "12345", Nullch);
    return -1;
}


MODULE = DBD::Perl    PACKAGE = DBD::Perl

INCLUDE: Perl.xsi

# vim:sw=4:ts=8
