/* dbivport.h

	Provides macros that enable greater portability between DBI versions.

	This file should be *copied* and included in driver distributions
	and #included into the source, after #include DBIXS.h

	New driver releases should include an updated copy of dbivport.h
	from the most recent DBI release.
*/

#ifndef DBI_VPORT_H
#define DBI_VPORT_H

#ifndef DBIh_SET_ERR_CHAR
/* Emulate DBIh_SET_ERR_CHAR
	Only uses the err_i, errstr and state parameters.
*/
#define DBIh_SET_ERR_CHAR(h, imp_xxh, err_c, err_i, errstr, state, method) \
        sv_setiv(DBIc_ERR(imp_xxh), err_i); \
        sv_setpv(DBIc_STATE(imp_xxh), state); \
        sv_setpv(DBIc_ERRSTR(imp_xxh), errstr)
#endif

#endif /* !DBI_VPORT_H */
