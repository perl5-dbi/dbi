#include "DBIXS.h"
#include "dbd_xsh.h"

#define dbd_discon_all(drh, imp_drh)		(drh=drh,imp_drh=imp_drh,1)
#define dbd_dr_data_sources(drh, imp_drh, attr)	(drh=drh,imp_drh=imp_drh,Nullav)
#define dbd_db_do4(dbh,imp_dbh,p3,p4)		(dbh=dbh,imp_dbh=imp_dbh,p3=p3,p4=p4,-2)
#define dbd_db_last_insert_id(dbh, imp_dbh, p3,p4,p5,p6, attr) \
	(dbh=dbh,imp_dbh=imp_dbh,p3=p3,p4=p4,p5=p5,p6=p6,&sv_undef)
#define dbd_take_imp_data(h, imp_xxh, p3)	(h=h,imp_xxh=imp_xxh,1)
#define dbd_st_rows(h, imp_xxh)			(h=h,imp_xxh=imp_xxh,1)
#define dbd_st_execute_for_fetch(sth, imp_sth, p3, p4) \
	(sth=sth,imp_sth=imp_sth,p3=p3,p4=p4,&sv_undef)

struct imp_drh_st {
    dbih_drc_t com;     /* MUST be first element in structure   */
};
struct imp_dbh_st {
    dbih_dbc_t com;     /* MUST be first element in structure   */
};
struct imp_sth_st {
    dbih_stc_t com;     /* MUST be first element in structure   */
};


DBISTATE_DECLARE;

MODULE = DBD::Perl    PACKAGE = DBD::Perl

INCLUDE: Perl.xsi

