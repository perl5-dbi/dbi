/* @(#)$Id: dbd_xsh.h,v 11.3 2003/02/26 17:56:01 timbo Exp $
 *
 * Copyright 2000-2002 Tim Bunce
 * Copyright 2002      Jonathan Leffler
 *
 * These prototypes are for dbdimp.c funcs used in the XS file.
 * These names are #defined to driver specific names by the
 * dbdimp.h file in the driver source.
 */

void     dbd_init _((dbistate_t *dbistate));

int      dbd_discon_all _((SV *drh, imp_drh_t *imp_drh));

/* Support for dbd_dr_data_sources and dbd_db_do added to Driver.xst in DBI v1.33 */
/* dbd_dr_data_sources: optional: defined by a driver that calls a C */
/* function to get the list of data sources */
AV	*dbd_dr_data_sources(SV *drh, imp_drh_t *imp_drh, SV *attrs);

int      dbd_db_login6 _((SV *dbh, imp_dbh_t *imp_dbh, char *dbname, char *uid, char *pwd, SV*attribs));
int      dbd_db_login  _((SV *dbh, imp_dbh_t *imp_dbh, char *dbname, char *uid, char *pwd)); /* deprecated */
/* Note: interface of dbd_db_do changed in v1.33 */
/* Old prototype: dbd_db_do _((SV *sv, char *statement)); */
/* dbd_db_do: optional: defined by a driver if the DBI default version is too slow */
int      dbd_db_do4 _((SV *dbh, imp_dbh_t *imp_dbh, char *statement, SV *params));
int      dbd_db_commit     _((SV *dbh, imp_dbh_t *imp_dbh));
int      dbd_db_rollback   _((SV *dbh, imp_dbh_t *imp_dbh));
int      dbd_db_disconnect _((SV *dbh, imp_dbh_t *imp_dbh));
void     dbd_db_destroy    _((SV *dbh, imp_dbh_t *imp_dbh));
int      dbd_db_STORE_attrib _((SV *dbh, imp_dbh_t *imp_dbh, SV *keysv, SV *valuesv));
SV      *dbd_db_FETCH_attrib _((SV *dbh, imp_dbh_t *imp_dbh, SV *keysv));

int      dbd_st_prepare _((SV *sth, imp_sth_t *imp_sth, char *statement, SV *attribs));
int      dbd_st_rows    _((SV *sth, imp_sth_t *imp_sth));
int      dbd_st_execute _((SV *sth, imp_sth_t *imp_sth));
AV      *dbd_st_fetch   _((SV *sth, imp_sth_t *imp_sth));
int      dbd_st_finish3 _((SV *sth, imp_sth_t *imp_sth, int from_destroy));
int      dbd_st_finish  _((SV *sth, imp_sth_t *imp_sth)); /* deprecated */
void     dbd_st_destroy _((SV *sth, imp_sth_t *imp_sth));
int      dbd_st_blob_read _((SV *sth, imp_sth_t *imp_sth,
                int field, long offset, long len, SV *destrv, long destoffset));
int      dbd_st_STORE_attrib _((SV *sth, imp_sth_t *imp_sth, SV *keysv, SV *valuesv));
SV      *dbd_st_FETCH_attrib _((SV *sth, imp_sth_t *imp_sth, SV *keysv));

int      dbd_bind_ph  _((SV *sth, imp_sth_t *imp_sth,
                SV *param, SV *value, IV sql_type, SV *attribs,
				int is_inout, IV maxlen));

/* end of dbd_xsh.h */
