/* vim: ts=8:sw=4:expandtab
 *
 * $Id$
 *
 * Copyright (c) 2024-2025  DBI Team
 * Copyright (c) 1994-2024  Tim Bunce  Ireland.
 *
 * See COPYRIGHT section in DBI.pm for usage and distribution rights.
 */

#define IN_DBI_XS 1     /* see DBIXS.h */
#define PERL_NO_GET_CONTEXT

#include "DBIXS.h"      /* DBI public interface for DBD's written in C  */

# if (defined(_WIN32) && (! defined(HAS_GETTIMEOFDAY)))
#include <sys/timeb.h>
# endif

/* The XS dispatcher code can optimize calls to XS driver methods,
 * bypassing the usual call_sv() and argument handling overheads.
 * Just-in-case it causes problems there's an (undocumented) way
 * to disable it by setting an env var.
 */
static int use_xsbypass = 1; /* set in dbi_bootinit() */

#ifndef CvISXSUB
#define CvISXSUB(sv) CvXSUB(sv)
#endif

#define DBI_MAGIC '~'

/* HvMROMETA introduced in 5.9.5, but mro_meta_init not exported in 5.10.0 */
#if (PERL_REVISION == 5)
#  if (PERL_VERSION < 10)
#    define MY_cache_gen(stash) 0
#  else
#    if ((PERL_VERSION == 10) && (PERL_SUBVERSION == 0))
#      define MY_cache_gen(stash) \
          (HvAUX(stash)->xhv_mro_meta \
          ? HvAUX(stash)->xhv_mro_meta->cache_gen \
          : 0)
#    else
#      define MY_cache_gen(stash) HvMROMETA(stash)->cache_gen
#    endif
#  endif
#endif

/* If the tests fail with errors about 'setlinebuf' then try    */
/* deleting the lines in the block below except the setvbuf one */
#ifndef PerlIO_setlinebuf
# ifdef HAS_SETLINEBUF
#  define PerlIO_setlinebuf(f)        setlinebuf(f)
# else
#  ifndef USE_PERLIO
#   define PerlIO_setlinebuf(f)        setvbuf(f, Nullch, _IOLBF, 0)
#  endif
# endif
#endif

#if (PERL_REVISION == 5)
# if (PERL_VERSION < 8) || ((PERL_VERSION == 8) && (PERL_SUBVERSION == 0))
#  define DBI_save_hv_fetch_ent
# endif

/* prior to 5.8.9: when a CV is duped, the mg dup method is called,
 * then *afterwards*, any_ptr is copied from the old CV to the new CV.
 * This wipes out anything which the dup method did to any_ptr.
 * This needs working around */
# if defined(USE_ITHREADS) && (PERL_VERSION == 8) && (PERL_SUBVERSION < 9)
#  define BROKEN_DUP_ANY_PTR
# endif
#endif

/* types of method name */

typedef enum {
    methtype_ordinary, /* nothing special about this method name */
    methtype_DESTROY,
    methtype_FETCH,
    methtype_can,
    methtype_fetch_star, /* fetch*, i.e. fetch() or fetch_...() */
    methtype_set_err
} meth_types;


static imp_xxh_t *dbih_getcom      _((SV *h));
static imp_xxh_t *dbih_getcom2     _((pTHX_ SV *h, MAGIC **mgp));
static void       dbih_clearcom    _((imp_xxh_t *imp_xxh));
static int        dbih_logmsg      _((imp_xxh_t *imp_xxh, const char *fmt, ...));
static SV        *dbih_make_com    _((SV *parent_h, imp_xxh_t *p_imp_xxh, const char *imp_class, STRLEN imp_size, STRLEN extra, SV *copy));
static SV        *dbih_make_fdsv   _((SV *sth, const char *imp_class, STRLEN imp_size, const char *col_name));
static AV        *dbih_get_fbav    _((imp_sth_t *imp_sth));
static SV        *dbih_event       _((SV *h, const char *name, SV*, SV*));
static int        dbih_set_attr_k  _((SV *h, SV *keysv, int dbikey, SV *valuesv));
static SV        *dbih_get_attr_k  _((SV *h, SV *keysv, int dbikey));
static int       dbih_sth_bind_col _((SV *sth, SV *col, SV *ref, SV *attribs));

static int      set_err_char _((SV *h, imp_xxh_t *imp_xxh, const char *err_c, IV err_i, const char *errstr, const char *state, const char *method));
static int      set_err_sv   _((SV *h, imp_xxh_t *imp_xxh, SV *err, SV *errstr, SV *state, SV *method));
static int      quote_type _((int sql_type, int p, int s, int *base_type, void *v));
static int      sql_type_cast_svpv _((pTHX_ SV *sv, int sql_type, U32 flags, void *v));
static I32      dbi_hash _((const char *string, long i));
static void     dbih_dumphandle _((pTHX_ SV *h, const char *msg, int level));
static int      dbih_dumpcom _((pTHX_ imp_xxh_t *imp_xxh, const char *msg, int level));
static int      dbi_ima_free(pTHX_ SV* sv, MAGIC* mg);
#if defined(USE_ITHREADS) && !defined(BROKEN_DUP_ANY_PTR)
static int      dbi_ima_dup(pTHX_ MAGIC* mg, CLONE_PARAMS *param);
#endif
char *neatsvpv _((SV *sv, STRLEN maxlen));
SV * preparse(SV *dbh, const char *statement, IV ps_return, IV ps_accept, void *foo);
static meth_types get_meth_type(const char * const name);

struct imp_drh_st { dbih_drc_t com; };
struct imp_dbh_st { dbih_dbc_t com; };
struct imp_sth_st { dbih_stc_t com; };
struct imp_fdh_st { dbih_fdc_t com; };

/* identify the type of a method name for dispatch behaviour */
/* (should probably be folded into the IMA flags mechanism)  */

static meth_types
get_meth_type(const char * const name)
{
    switch (name[0]) {
    case 'D':
        if strEQ(name,"DESTROY")
            return methtype_DESTROY;
        break;
    case 'F':
        if strEQ(name,"FETCH")
            return methtype_FETCH;
        break;
    case 'c':
        if strEQ(name,"can")
            return methtype_can;
        break;
    case 'f':
        if strnEQ(name,"fetch", 5) /* fetch* */
            return methtype_fetch_star;
        break;
    case 's':
        if strEQ(name,"set_err")
            return methtype_set_err;
        break;
    }
    return methtype_ordinary;
}


/* Internal Method Attributes (attached to dispatch methods when installed) */
/* NOTE: when adding SVs to dbi_ima_t, update dbi_ima_dup() dbi_ima_free()
 * to ensure that they are duped and correctly ref-counted */

typedef struct dbi_ima_st {
    U8 minargs;
    U8 maxargs;
    IV hidearg;
    /* method_trace controls tracing of method calls in the dispatcher:
    - if the current trace flags include a trace flag in method_trace
    then set trace_level to min(2,trace_level) for duration of the call.
    - else, if trace_level < (method_trace & DBIc_TRACE_LEVEL_MASK)
    then don't trace the call
    */
    U32 method_trace;
    const char *usage_msg;
    U32 flags;
    meth_types meth_type;

    /* cached outer to inner method mapping */
    HV *stash;          /* the stash we found the GV in */
    GV *gv;             /* the GV containing the inner sub */
    U32 generation;     /* cache invalidation */
#ifdef BROKEN_DUP_ANY_PTR
    PerlInterpreter *my_perl; /* who owns this struct */
#endif

} dbi_ima_t;

/* These values are embedded in the data passed to install_method       */
#define IMA_HAS_USAGE             0x00000001  /* check parameter usage        */
#define IMA_FUNC_REDIRECT         0x00000002  /* is $h->func(..., "method")   */
#define IMA_KEEP_ERR              0x00000004  /* don't reset err & errstr     */
#define IMA_KEEP_ERR_SUB          0x00000008  /*  '' if in a nested call      */
#define IMA_NO_TAINT_IN           0x00000010  /* don't check for PL_tainted args */
#define IMA_NO_TAINT_OUT          0x00000020  /* don't taint results          */
#define IMA_COPY_UP_STMT          0x00000040  /* copy sth Statement to dbh    */
#define IMA_END_WORK              0x00000080  /* method is commit or rollback */
#define IMA_STUB                  0x00000100  /* donothing eg $dbh->connected */
#define IMA_CLEAR_STMT            0x00000200  /* clear Statement before call  */
#define IMA_UNRELATED_TO_STMT     0x00000400  /* profile as empty Statement   */
#define IMA_NOT_FOUND_OKAY        0x00000800  /* no error if not found        */
#define IMA_EXECUTE               0x00001000  /* do/execute: DBIcf_Executed   */
#define IMA_SHOW_ERR_STMT         0x00002000  /* dbh meth relates to Statement*/
#define IMA_HIDE_ERR_PARAMVALUES  0x00004000  /* ParamValues are not relevant */
#define IMA_IS_FACTORY            0x00008000  /* new h ie connect and prepare */
#define IMA_CLEAR_CACHED_KIDS     0x00010000  /* clear CachedKids before call */

#define DBIc_STATE_adjust(imp_xxh, state)                                \
    (SvOK(state)        /* SQLSTATE is implemented by driver   */        \
        ? (strEQ(SvPV_nolen(state),"00000") ? &PL_sv_no : sv_mortalcopy(state))\
        : (SvTRUE(DBIc_ERR(imp_xxh))                                     \
            ? sv_2mortal(newSVpvs("S1000")) /* General error    */       \
            : &PL_sv_no)                /* Success ("00000")    */       \
    )

#define DBI_LAST_HANDLE         g_dbi_last_h /* special fake inner handle */
#define DBI_IS_LAST_HANDLE(h)   ((DBI_LAST_HANDLE) == SvRV(h))
#define DBI_SET_LAST_HANDLE(h)  ((DBI_LAST_HANDLE) =  SvRV(h))
#define DBI_UNSET_LAST_HANDLE   ((DBI_LAST_HANDLE) =  &PL_sv_undef)
#define DBI_LAST_HANDLE_OK      ((DBI_LAST_HANDLE) != &PL_sv_undef)

#define DBIS_TRACE_LEVEL        (DBIS->debug & DBIc_TRACE_LEVEL_MASK)
#define DBIS_TRACE_FLAGS        (DBIS->debug)   /* includes level */

#ifdef PERL_LONG_MAX
#define MAX_LongReadLen PERL_LONG_MAX
#else
#define MAX_LongReadLen 2147483647L
#endif

#ifdef DBI_USE_THREADS
static char *dbi_build_opt = "-ithread";
#else
static char *dbi_build_opt = "-nothread";
#endif

/* 32 bit magic FNV-0 and FNV-1 prime */
#define FNV_32_PRIME ((UV)0x01000193)


/* perl doesn't know anything about the dbi_ima_t struct attached to the
 * CvXSUBANY(cv).any_ptr slot, so add some magic to the CV to handle
 * duping and freeing.
 */

static MGVTBL dbi_ima_vtbl = { 0, 0, 0, 0, dbi_ima_free,
                                    0,
#if defined(USE_ITHREADS) && !defined(BROKEN_DUP_ANY_PTR)
                                    dbi_ima_dup
#else
                                    0
#endif
#if (PERL_REVISION == 5)
# if (PERL_VERSION > 8) || ((PERL_VERSION == 8) && (PERL_SUBVERSION >= 9))
                                    , 0
# endif
#endif
                                    };

static int dbi_ima_free(pTHX_ SV* sv, PERL_UNUSED_DECL MAGIC* mg)
{
    dbi_ima_t *ima = (dbi_ima_t *)(CvXSUBANY((CV*)sv).any_ptr);
#ifdef BROKEN_DUP_ANY_PTR
    if (ima->my_perl != my_perl)
        return 0;
#endif
    SvREFCNT_dec(ima->stash);
    SvREFCNT_dec(ima->gv);
    Safefree(ima);
    return 0;
}

#if defined(USE_ITHREADS) && !defined(BROKEN_DUP_ANY_PTR)
static int dbi_ima_dup(pTHX_ MAGIC* mg, CLONE_PARAMS *param)
{
    dbi_ima_t *ima, *nima;
    CV *cv  = (CV*) mg->mg_ptr;
    CV *ncv = (CV*)ptr_table_fetch(PL_ptr_table, (cv));

    PERL_UNUSED_VAR(param);
    mg->mg_ptr = (char *)ncv;
    ima = (dbi_ima_t*) CvXSUBANY(cv).any_ptr;
    Newx(nima, 1, dbi_ima_t);
    *nima = *ima; /* structure copy */
    CvXSUBANY(ncv).any_ptr = nima;
    nima->stash = NULL;
    nima->gv    = NULL;
    return 0;
}
#endif



/* --- make DBI safe for multiple perl interpreters --- */
/*     Originally contributed by Murray Nesbitt of ActiveState, */
/*     but later updated to use MY_CTX */

#define MY_CXT_KEY "DBI::_guts" XS_VERSION

typedef struct {
    SV   *dbi_last_h;  /* maybe better moved into dbistate_t? */
    dbistate_t* dbi_state;
} my_cxt_t;

START_MY_CXT

#undef DBIS
#define DBIS                   (MY_CXT.dbi_state)

#define g_dbi_last_h            (MY_CXT.dbi_last_h)

/* allow the 'static' dbi_state struct to be accessed from other files */
dbistate_t**
_dbi_state_lval(pTHX)
{
    dMY_CXT;
    return &(MY_CXT.dbi_state);
}


/* --- */

static void *
malloc_using_sv(STRLEN len)
{
    dTHX;
    SV *sv = newSV(len ? len : 1);
    void *p = SvPVX(sv);
    memzero(p, len);
    return p;
}

static char *
savepv_using_sv(char *str)
{
    char *buf = malloc_using_sv(strlen(str));
    strcpy(buf, str);
    return buf;
}


/* --- support functions for concat_hash_sorted --- */

typedef struct str_uv_sort_pair_st {
    char *key;
    UV numeric;
} str_uv_sort_pair_t;

static int
_cmp_number(const void *val1, const void *val2)
{
    UV first  = ((str_uv_sort_pair_t *)val1)->numeric;
    UV second = ((str_uv_sort_pair_t *)val2)->numeric;

    if (first > second)
        return 1;
    if (first < second)
        return -1;
    /* only likely to reach here if numeric sort forced for non-numeric keys */
    /* fallback to comparing the key strings */
    return strcmp(
        ((str_uv_sort_pair_t *)val1)->key,
        ((str_uv_sort_pair_t *)val2)->key
    );
}

static int 
_cmp_str (const void *val1, const void *val2)
{
    return strcmp( *(char **)val1, *(char **)val2);
}

static char **
_sort_hash_keys (HV *hash, int num_sort, STRLEN *total_length)
{
    dTHX;
    I32 hv_len, key_len;
    HE *entry;
    char **keys;
    unsigned int idx = 0;
    STRLEN tot_len = 0;
    bool has_non_numerics = 0;
    str_uv_sort_pair_t *numbers;

    hv_len = hv_iterinit(hash);
    if (!hv_len)
        return 0;

    Newz(0, keys,    hv_len, char *);
    Newz(0, numbers, hv_len, str_uv_sort_pair_t);

    while ((entry = hv_iternext(hash))) {
        *(keys+idx) = hv_iterkey(entry, &key_len);
        tot_len += key_len;
        
        if (grok_number(*(keys+idx), key_len, &(numbers+idx)->numeric) != IS_NUMBER_IN_UV) {
            has_non_numerics = 1;
            (numbers+idx)->numeric = 0;
        }

        (numbers+idx)->key = *(keys+idx);
        ++idx;
    }

    if (total_length)
        *total_length = tot_len;

    if (num_sort < 0)
        num_sort = (has_non_numerics) ? 0 : 1;

    if (!num_sort) {
        qsort(keys, hv_len, sizeof(char*), _cmp_str);
    }
    else {
        qsort(numbers, hv_len, sizeof(str_uv_sort_pair_t), _cmp_number);
        for (idx = 0; idx < hv_len; ++idx)
            *(keys+idx) = (numbers+idx)->key;
    }

    Safefree(numbers);
    return keys;
}


static SV *
_join_hash_sorted(HV *hash, char *kv_sep, STRLEN kv_sep_len, char *pair_sep, STRLEN pair_sep_len, int use_neat, int num_sort)
{
        dTHX;
        I32 hv_len;
        STRLEN total_len = 0;
        char **keys;
        unsigned int i = 0;
        SV *return_sv;

        keys = _sort_hash_keys(hash, num_sort, &total_len);
        if (!keys)
            return newSVpvs("");

        if (!kv_sep_len)
            kv_sep_len = strlen(kv_sep);
        if (!pair_sep_len)
            pair_sep_len = strlen(pair_sep);

        hv_len = hv_iterinit(hash);
        /* total_len += Separators + quotes + term null */
        total_len += kv_sep_len*hv_len + pair_sep_len*hv_len+2*hv_len+1;
        return_sv = newSV(total_len);
        sv_setpv(return_sv, ""); /* quell undef warnings */

        for (i=0; i<hv_len; ++i) {
            SV **hash_svp = hv_fetch(hash, keys[i], strlen(keys[i]), 0);

            sv_catpv(return_sv, keys[i]); /* XXX keys can't contain nul chars */
            sv_catpvn(return_sv, kv_sep, kv_sep_len);

            if (!hash_svp) {    /* should never happen */
                warn("No hash entry with key '%s'", keys[i]);
                sv_catpvs(return_sv, "???");
                continue;
            }

            if (use_neat) {
                sv_catpv(return_sv, neatsvpv(*hash_svp,0));
            }
            else {
                if (SvOK(*hash_svp)) {
                     STRLEN hv_val_len;
                     char *hv_val = SvPV(*hash_svp, hv_val_len);
                     sv_catpvs(return_sv, "'");
                     sv_catpvn(return_sv, hv_val, hv_val_len);
                     sv_catpvs(return_sv, "'");
                }
                else sv_catpvs(return_sv, "undef");
            }

            if (i < hv_len-1)
                sv_catpvn(return_sv, pair_sep, pair_sep_len);
        }

        Safefree(keys);

        return return_sv;
}



/* handy for embedding into condition expression for debugging */
/*
static int warn1(char *s) { warn("%s", s); return 1; }
static int dump1(SV *sv)  { dTHX; sv_dump(sv); return 1; }
*/


/* --- */

static void
check_version(const char *name, int dbis_cv, int dbis_cs, int need_dbixs_cv, int drc_s,
        int dbc_s, int stc_s, int fdc_s)
{
    dTHX;
    dMY_CXT;
    static const char msg[] = "you probably need to rebuild the DBD driver (or possibly the DBI)";
    (void)need_dbixs_cv;
    if (dbis_cv != DBISTATE_VERSION || dbis_cs != sizeof(*DBIS))
        croak("DBI/DBD internal version mismatch (DBI is v%d/s%lu, DBD %s expected v%d/s%d) %s.\n",
            DBISTATE_VERSION, (long unsigned int)sizeof(*DBIS), name, dbis_cv, dbis_cs, msg);
    /* Catch structure size changes - We should probably force a recompile if the DBI   */
    /* runtime version is different from the build time. That would be harsh but safe.  */
    if (drc_s != sizeof(dbih_drc_t) || dbc_s != sizeof(dbih_dbc_t) ||
        stc_s != sizeof(dbih_stc_t) || fdc_s != sizeof(dbih_fdc_t) )
            croak("%s (dr:%d/%ld, db:%d/%ld, st:%d/%ld, fd:%d/%ld), %s.\n",
                "DBI/DBD internal structure mismatch",
                drc_s, (long)sizeof(dbih_drc_t), dbc_s, (long)sizeof(dbih_dbc_t),
                stc_s, (long)sizeof(dbih_stc_t), fdc_s, (long)sizeof(dbih_fdc_t), msg);
}

static void
dbi_bootinit(dbistate_t * parent_dbis)
{
    dTHX;
    dMY_CXT;
    dbistate_t* DBISx;

    DBISx = (struct dbistate_st*)malloc_using_sv(sizeof(struct dbistate_st));
    DBIS = DBISx;

    /* make DBIS available to DBD modules the "old" (<= 1.618) way,
     * so that unrecompiled DBD's will still work against a newer DBI */
    sv_setiv(get_sv("DBI::_dbistate", GV_ADDMULTI),
            PTR2IV(MY_CXT.dbi_state));

    /* store version and size so we can spot DBI/DBD version mismatch   */
    DBIS->check_version = check_version;
    DBIS->version = DBISTATE_VERSION;
    DBIS->size    = sizeof(*DBIS);
    DBIS->xs_version = DBIXS_VERSION;

    DBIS->logmsg      = dbih_logmsg;
    DBIS->logfp       = PerlIO_stderr();
    DBIS->debug       = (parent_dbis) ? parent_dbis->debug
                            : SvIV(get_sv("DBI::dbi_debug",0x5));
    DBIS->neatsvpvlen = (parent_dbis) ? parent_dbis->neatsvpvlen
                                      : get_sv("DBI::neat_maxlen", GV_ADDMULTI);
#ifdef DBI_USE_THREADS
    DBIS->thr_owner   = PERL_GET_THX;
#endif

    /* store some function pointers so DBD's can call our functions     */
    DBIS->getcom      = dbih_getcom;
    DBIS->clearcom    = dbih_clearcom;
    DBIS->event       = dbih_event;
    DBIS->set_attr_k  = dbih_set_attr_k;
    DBIS->get_attr_k  = dbih_get_attr_k;
    DBIS->get_fbav    = dbih_get_fbav;
    DBIS->make_fdsv   = dbih_make_fdsv;
    DBIS->neat_svpv   = neatsvpv;
    DBIS->bind_as_num = quote_type; /* XXX deprecated */
    DBIS->hash        = dbi_hash;
    DBIS->set_err_sv  = set_err_sv;
    DBIS->set_err_char= set_err_char;
    DBIS->bind_col    = dbih_sth_bind_col;
    DBIS->sql_type_cast_svpv = sql_type_cast_svpv;


    /* Remember the last handle used. BEWARE! Sneaky stuff here!        */
    /* We want a handle reference but we don't want to increment        */
    /* the handle's reference count and we don't want perl to try       */
    /* to destroy it during global destruction. Take care!              */
    DBI_UNSET_LAST_HANDLE;      /* ensure setup the correct way         */

    /* trick to avoid 'possible typo' warnings  */
    gv_fetchpv("DBI::state",  GV_ADDMULTI, SVt_PV);
    gv_fetchpv("DBI::err",    GV_ADDMULTI, SVt_PV);
    gv_fetchpv("DBI::errstr", GV_ADDMULTI, SVt_PV);
    gv_fetchpv("DBI::lasth",  GV_ADDMULTI, SVt_PV);
    gv_fetchpv("DBI::rows",   GV_ADDMULTI, SVt_PV);

    /* we only need to check the env var on the initial boot
     * which is handy because it can core dump during CLONE on windows
     */
    if (!parent_dbis && getenv("PERL_DBI_XSBYPASS"))
        use_xsbypass = atoi(getenv("PERL_DBI_XSBYPASS"));
}


/* ----------------------------------------------------------------- */
/* Utility functions                                                 */


static char *
dbih_htype_name(int htype)
{
    switch(htype) {
    case DBIt_DR: return "dr";
    case DBIt_DB: return "db";
    case DBIt_ST: return "st";
    case DBIt_FD: return "fd";
    default:      return "??";
    }
}


char *
neatsvpv(SV *sv, STRLEN maxlen) /* return a tidy ascii value, for debugging only */
{
    dTHX;
    dMY_CXT;
    STRLEN len;
    SV *nsv = Nullsv;
    SV *infosv = Nullsv;
    char *v, *quote;

    /* We take care not to alter the supplied sv in any way at all.      */
    /* (but if it is SvGMAGICAL we have to call mg_get and that can      */
    /* have side effects, especially as it may be called twice overall.) */

    if (!sv)
        return "Null!";                         /* should never happen  */

    /* try to do the right thing with magical values                    */
    if (SvMAGICAL(sv)) {
        if (DBIS_TRACE_LEVEL >= 5) {    /* add magic details to help debugging  */
            MAGIC* mg;
            infosv = sv_2mortal(newSVpvs(" (magic-"));
            if (SvSMAGICAL(sv)) sv_catpvs(infosv, "s");
            if (SvGMAGICAL(sv)) sv_catpvs(infosv, "g");
            if (SvRMAGICAL(sv)) sv_catpvs(infosv, "r");
            sv_catpvs(infosv, ":");
            for (mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic)
                sv_catpvn(infosv, &mg->mg_type, 1);
            sv_catpvs(infosv, ")");
        }
        if (SvGMAGICAL(sv) && !PL_dirty)
            mg_get(sv);         /* trigger magic to FETCH the value     */
    }

    if (!SvOK(sv)) {
        if (SvTYPE(sv) >= SVt_PVAV)
            return (char *)sv_reftype(sv,0);    /* raw AV/HV etc, not via a ref */
        if (!infosv)
            return "undef";
        sv_insert(infosv, 0,0, "undef",5);
        return SvPVX(infosv);
    }

    if (SvNIOK(sv)) {     /* is a numeric value - so no surrounding quotes      */
        if (SvPOK(sv)) {  /* already has string version of the value, so use it */
            v = SvPV(sv,len);
            if (len == 0) { v="''"; len=2; } /* catch &sv_no style special case */
            if (!infosv)
                return v;
            sv_insert(infosv, 0,0, v, len);
            return SvPVX(infosv);
        }
        /* we don't use SvPV here since we don't want to alter sv in _any_ way  */
        if (SvUOK(sv))
             nsv = newSVpvf("%"UVuf, SvUVX(sv));
        else if (SvIOK(sv))
             nsv = newSVpvf("%"IVdf, SvIVX(sv));
        else nsv = newSVpvf("%"NVgf, SvNVX(sv));
        if (infosv)
            sv_catsv(nsv, infosv);
        return SvPVX(sv_2mortal(nsv));
    }

    nsv = sv_newmortal();
    sv_upgrade(nsv, SVt_PV);

    if (SvROK(sv)) {
        if (!SvAMAGIC(sv))      /* (un-amagic'd) refs get no special treatment  */
            v = SvPV(sv,len);
        else {
            /* handle Overload magic refs */
            (void)SvAMAGIC_off(sv);   /* should really be done via local scoping */
            v = SvPV(sv,len);   /* XXX how does this relate to SvGMAGIC?   */
            SvAMAGIC_on(sv);
        }
        sv_setpvn(nsv, v, len);
        if (infosv)
            sv_catsv(nsv, infosv);
        return SvPV(nsv, len);
    }

    if (SvPOK(sv))              /* usual simple string case                */
        v = SvPV(sv,len);
    else                        /* handles all else via sv_2pv()           */
        v = SvPV(sv,len);       /* XXX how does this relate to SvGMAGIC?   */

    /* for strings we limit the length and translate codes      */
    if (maxlen == 0)
        maxlen = SvIV(DBIS->neatsvpvlen);
    if (maxlen < 6)                     /* handle daft values   */
        maxlen = 6;
    maxlen -= 2;                        /* account for quotes   */

    quote = (SvUTF8(sv)) ? "\"" : "'";
    if (len > maxlen) {
        SvGROW(nsv, (1+maxlen+1+1));
        sv_setpvn(nsv, quote, 1);
        sv_catpvn(nsv, v, maxlen-3);    /* account for three dots */
        sv_catpvs(nsv, "...");
    } else {
        SvGROW(nsv, (1+len+1+1));
        sv_setpvn(nsv, quote, 1);
        sv_catpvn(nsv, v, len);
    }
    sv_catpvn(nsv, quote, 1);
    if (infosv)
        sv_catsv(nsv, infosv);
    v = SvPV(nsv, len);
    if (!SvUTF8(sv)) {
        while(len-- > 0) { /* cleanup string (map control chars to ascii etc) */
            const char c = v[len] & 0x7F;       /* ignore top bit for multinational chars */
            if (!isPRINT(c) && !isSPACE(c))
                v[len] = '.';
        }
    }
    return v;
}


static void
copy_statement_to_parent(pTHX_ SV *h, imp_xxh_t *imp_xxh)
{
    SV *parent;
    if (PL_dirty)
        return;
    parent = DBIc_PARENT_H(imp_xxh);
    if (parent && SvROK(parent)) {
        SV *tmp_sv = *hv_fetchs((HV*)SvRV(h), "Statement", 1);
        if (SvOK(tmp_sv))
            (void)hv_stores((HV*)SvRV(parent), "Statement", SvREFCNT_inc(tmp_sv));
    }
}


static int
set_err_char(SV *h, imp_xxh_t *imp_xxh, const char *err_c, IV err_i, const char *errstr, const char *state, const char *method)
{
    dTHX;
    char err_buf[28];
    SV *err_sv, *errstr_sv, *state_sv, *method_sv;
    if (!err_c) {
        sprintf(err_buf, "%ld", (long)err_i);
        err_c = &err_buf[0];
    }
    err_sv    = (strEQ(err_c,"1")) ? &PL_sv_yes : sv_2mortal(newSVpvn(err_c, strlen(err_c)));
    errstr_sv = sv_2mortal(newSVpvn(errstr, strlen(errstr)));
    state_sv  = (state  && *state)  ? sv_2mortal(newSVpvn(state,  strlen(state)))  : &PL_sv_undef;
    method_sv = (method && *method) ? sv_2mortal(newSVpvn(method, strlen(method))) : &PL_sv_undef;
    return set_err_sv(h, imp_xxh, err_sv, errstr_sv, state_sv, method_sv);
}


static int
set_err_sv(SV *h, imp_xxh_t *imp_xxh, SV *err, SV *errstr, SV *state, SV *method)
{
    dTHX;
    SV *h_err;
    SV *h_errstr;
    SV *h_state;
    SV **hook_svp;
    int err_changed = 0;

    if (    DBIc_has(imp_xxh, DBIcf_HandleSetErr)
        && (hook_svp = hv_fetchs((HV*)SvRV(h),"HandleSetErr",0))
        &&  hook_svp
        &&  ((void)(SvGMAGICAL(*hook_svp) && mg_get(*hook_svp)), SvOK(*hook_svp))
    ) {
        dSP;
        IV items;
        SV *response_sv;
        if (SvREADONLY(err))    err    = sv_mortalcopy(err);
        if (SvREADONLY(errstr)) errstr = sv_mortalcopy(errstr);
        if (SvREADONLY(state))  state  = sv_mortalcopy(state);
        if (SvREADONLY(method)) method = sv_mortalcopy(method);
        if (DBIc_TRACE_LEVEL(imp_xxh) >= 2)
            PerlIO_printf(DBIc_LOGPIO(imp_xxh),"    -> HandleSetErr(%s, err=%s, errstr=%s, state=%s, %s)\n",
                neatsvpv(h,0), neatsvpv(err,0), neatsvpv(errstr,0), neatsvpv(state,0),
                neatsvpv(method,0)
            );
        PUSHMARK(SP);
        mXPUSHs(newRV_inc((SV*)DBIc_MY_H(imp_xxh)));
        XPUSHs(err);
        XPUSHs(errstr);
        XPUSHs(state);
        XPUSHs(method);
        PUTBACK;
        items = call_sv(*hook_svp, G_SCALAR);
        SPAGAIN;
        response_sv = (items) ? POPs : &PL_sv_undef;
        PUTBACK;
        if (DBIc_TRACE_LEVEL(imp_xxh) >= 1)
            PerlIO_printf(DBIc_LOGPIO(imp_xxh),"    <- HandleSetErr= %s (err=%s, errstr=%s, state=%s, %s)\n",
                neatsvpv(response_sv,0), neatsvpv(err,0), neatsvpv(errstr,0), neatsvpv(state,0),
                neatsvpv(method,0)
            );
        if (SvTRUE(response_sv))        /* handler says it has handled it, so... */
            return 0;
    }
    else {
        if (DBIc_TRACE_LEVEL(imp_xxh) >= 2)
            PerlIO_printf(DBIc_LOGPIO(imp_xxh),"    -- HandleSetErr err=%s, errstr=%s, state=%s, %s\n",
                neatsvpv(err,0), neatsvpv(errstr,0), neatsvpv(state,0), neatsvpv(method,0)
            );
    }

    if (!SvOK(err)) {   /* clear err / errstr / state */
        DBIh_CLEAR_ERROR(imp_xxh);
        return 1;
    }

    /* fetch these after calling HandleSetErr */
    h_err    = DBIc_ERR(imp_xxh);
    h_errstr = DBIc_ERRSTR(imp_xxh);
    h_state  = DBIc_STATE(imp_xxh);

    if (SvTRUE(h_errstr)) {
        /* append current err, if any, to errstr if it's going to change */
        if (SvTRUE(h_err) && SvTRUE(err) && strNE(SvPV_nolen(h_err), SvPV_nolen(err)))
            sv_catpvf(h_errstr, " [err was %s now %s]", SvPV_nolen(h_err), SvPV_nolen(err));
        if (SvTRUE(h_state) && SvTRUE(state) && strNE(SvPV_nolen(h_state), SvPV_nolen(state)))
            sv_catpvf(h_errstr, " [state was %s now %s]", SvPV_nolen(h_state), SvPV_nolen(state));
        if (strNE(SvPV_nolen(h_errstr), SvPV_nolen(errstr))) {
            sv_catpvs(h_errstr, "\n");
            sv_catsv(h_errstr, errstr);
        }
    }
    else
        sv_setsv(h_errstr, errstr);

    /* SvTRUE(err) > "0" > "" > undef */
    if (SvTRUE(err)             /* new error: so assign                 */
        || !SvOK(h_err) /* no existing warn/info: so assign     */
           /* new warn ("0" len 1) > info ("" len 0): so assign         */
        || (SvOK(err) && strlen(SvPV_nolen(err)) > strlen(SvPV_nolen(h_err)))
    ) {
        sv_setsv(h_err, err);
        err_changed = 1;
        if (SvTRUE(h_err))      /* new error */
            ++DBIc_ErrCount(imp_xxh);
    }

    if (err_changed) {
        if (SvTRUE(state)) {
            if (strlen(SvPV_nolen(state)) != 5) {
                warn("set_err: state (%s) is not a 5 character string, using 'S1000' instead", neatsvpv(state,0));
                sv_setpv(h_state, "S1000");
            }
            else
                sv_setsv(h_state, state);
        }
        else
            (void)SvOK_off(h_state);    /* see DBIc_STATE_adjust */

        /* ensure that the parent's Statement attribute reflects the latest error */
        /* so that ShowErrorStatement is reliable */
        copy_statement_to_parent(aTHX_ h, imp_xxh);
    }

    return 1;
}


/* err_hash returns a U32 'hash' value representing the current err 'level'
 * (err/warn/info) and errstr. It's used by the dispatcher as a way to detect
 * a new or changed warning during a 'keep err' method like STORE. Always returns >0.
 * The value is 1 for no err/warn/info and guarantees that err > warn > info.
 * (It's a bit of a hack but the original approach in 70fe6bd76 using a new
 * ErrChangeCount attribute would break binary compatibility with drivers.)
 * The chance that two realistic errstr values would hash the same, even with
 * only 30 bits, is deemed to small to even bother documenting.
 */
static U32
err_hash(pTHX_ imp_xxh_t *imp_xxh)
{
    SV *err_sv = DBIc_ERR(imp_xxh);
    SV *errstr_sv;
    I32 hash = 1;
    if (SvOK(err_sv)) {
        errstr_sv = DBIc_ERRSTR(imp_xxh);
        if (SvOK(errstr_sv))
             hash = -dbi_hash(SvPV_nolen(errstr_sv), 0); /* make positive */
        else hash = 0;
        hash >>= 1; /* free up extra bit (top bit is already free) */
        hash |= (SvTRUE(err_sv))                  ? 0x80000000 /* err */
              : (SvPOK(err_sv) && !SvCUR(err_sv)) ? 0x20000000 /* '' = info */
                                                  : 0x40000000;/* 0 or '0' = warn */
    }
    return hash;
}


static char *
mkvname(pTHX_ HV *stash, const char *item, int uplevel) /* construct a variable name    */
{
    SV *sv = sv_newmortal();
    sv_setpv(sv, HvNAME(stash));
    if(uplevel) {
        while(SvCUR(sv) && *SvEND(sv)!=':')
            --SvCUR(sv);
        if (SvCUR(sv))
            --SvCUR(sv);
    }
    sv_catpv(sv, "::");
    sv_catpv(sv, item);
    return SvPV_nolen(sv);
}

/* 32 bit magic FNV-0 and FNV-1 prime */
#define FNV_32_PRIME ((UV)0x01000193)

static I32
dbi_hash(const char *key, long type)
{
    if (type == 0) {
        STRLEN klen = strlen(key);
        U32 hash = 0;
        while (klen--)
            hash = hash * 33 + *key++;
        hash &= 0x7FFFFFFF;     /* limit to 31 bits             */
        hash |= 0x40000000;     /* set bit 31                   */
        return -(I32)hash;      /* return negative int  */
    }
    else if (type == 1) {       /* Fowler/Noll/Vo hash  */
        /* see http://www.isthe.com/chongo/tech/comp/fnv/ */
        U32 hash = 0x811c9dc5;
        const unsigned char *s = (unsigned char *)key;    /* unsigned string */
        while (*s) {
            /* multiply by the 32 bit FNV magic prime mod 2^32 */
            hash *= FNV_32_PRIME;
            /* xor the bottom with the current octet */
            hash ^= (U32)*s++;
        }
        return hash;
    }
    croak("DBI::hash(%ld): invalid type", type);
    return 0; /* NOT REACHED */
}


static int
dbih_logmsg(imp_xxh_t *imp_xxh, const char *fmt, ...)
{
    dTHX;
    va_list args;
#ifdef I_STDARG
    va_start(args, fmt);
#else
    va_start(args);
#endif
    (void) PerlIO_vprintf(DBIc_DBISTATE(imp_xxh)->logfp, fmt, args);
    va_end(args);
    (void)imp_xxh;
    return 1;
}

static void
close_trace_file(pTHX)
{
    dMY_CXT;
    if (DBILOGFP == PerlIO_stderr() || DBILOGFP == PerlIO_stdout())
        return;

    if (DBIS->logfp_ref == NULL)
        PerlIO_close(DBILOGFP);
    else {
    /* DAA dec refcount and discard */
        SvREFCNT_dec(DBIS->logfp_ref);
        DBIS->logfp_ref = NULL;
    }
}

static int
set_trace_file(SV *file)
{
    dTHX;
    dMY_CXT;
    const char *filename;
    PerlIO *fp = Nullfp;
    IO *io;

    if (!file)          /* no arg == no change */
        return 0;

    /* DAA check for a filehandle */
    if (SvROK(file)) {
        io = sv_2io(file);
        if (!io || !(fp = IoOFP(io))) {
            warn("DBI trace filehandle is not valid");
            return 0;
        }
        close_trace_file(aTHX);
        (void)SvREFCNT_inc(io);
        DBIS->logfp_ref = io;
    }
    else if (isGV_with_GP(file)) {
        io = GvIO(file);
        if (!io || !(fp = IoOFP(io))) {
            warn("DBI trace filehandle from GLOB is not valid");
            return 0;
        }
        close_trace_file(aTHX);
        (void)SvREFCNT_inc(io);
        DBIS->logfp_ref = io;
    }
    else {
        filename = (SvOK(file)) ? SvPV_nolen(file) : Nullch;
        /* undef arg == reset back to stderr */
        if (!filename || strEQ(filename,"STDERR")
                      || strEQ(filename,"*main::STDERR")) {
            close_trace_file(aTHX);
            DBILOGFP = PerlIO_stderr();
            return 1;
        }
        if (strEQ(filename,"STDOUT")) {
            close_trace_file(aTHX);
            DBILOGFP = PerlIO_stdout();
            return 1;
        }
        fp = PerlIO_open(filename, "a+");
        if (fp == Nullfp) {
            warn("Can't open trace file %s: %s", filename, Strerror(errno));
            return 0;
        }
        close_trace_file(aTHX);
    }
    DBILOGFP = fp;
    /* if this line causes your compiler or linker to choke     */
    /* then just comment it out, it's not essential.    */
    PerlIO_setlinebuf(fp);      /* force line buffered output */
    return 1;
}

static IV
parse_trace_flags(SV *h, SV *level_sv, IV old_level)
{
    dTHX;
    IV level;
    if (!level_sv || !SvOK(level_sv))
        level = old_level;              /* undef: no change     */
    else
    if (SvTRUE(level_sv)) {
        if (looks_like_number(level_sv))
            level = SvIV(level_sv);     /* number: number       */
        else {                          /* string: parse it     */
            dSP;
            PUSHMARK(sp);
            XPUSHs(h);
            XPUSHs(level_sv);
            PUTBACK;
            if (call_method("parse_trace_flags", G_SCALAR) != 1)
                croak("panic: parse_trace_flags");/* should never happen */
            SPAGAIN;
            level = POPi;
            PUTBACK;
        }
    }
    else                                /* defined but false: 0 */
        level = 0;
    return level;
}


static int
set_trace(SV *h, SV *level_sv, SV *file)
{
    dTHX;
    D_imp_xxh(h);
    int RETVAL = DBIc_DBISTATE(imp_xxh)->debug; /* Return trace level in effect now */
    IV level = parse_trace_flags(h, level_sv, RETVAL);
    set_trace_file(file);
    if (level != RETVAL) { /* set value */
        if ((level & DBIc_TRACE_LEVEL_MASK) > 0) {
            PerlIO_printf(DBIc_LOGPIO(imp_xxh),
                "    %s trace level set to 0x%lx/%ld (DBI @ 0x%lx/%ld) in DBI %s%s (pid %d)\n",
                neatsvpv(h,0),
                (long)(level & DBIc_TRACE_FLAGS_MASK),
                (long)(level & DBIc_TRACE_LEVEL_MASK),
                (long)DBIc_TRACE_FLAGS(imp_xxh), (long)DBIc_TRACE_LEVEL(imp_xxh),
                XS_VERSION, dbi_build_opt, (int)PerlProc_getpid());
            if (!PL_dowarn)
                PerlIO_printf(DBIc_LOGPIO(imp_xxh),"    Note: perl is running without the recommended perl -w option\n");
            PerlIO_flush(DBIc_LOGPIO(imp_xxh));
        }
        sv_setiv(DBIc_DEBUG(imp_xxh), level);
    }
    return RETVAL;
}


static SV *
dbih_inner(pTHX_ SV *orv, const char *what)
{   /* convert outer to inner handle else croak(what) if what is not NULL */
    /* if what is NULL then return NULL for invalid handles */
    MAGIC *mg;
    SV *ohv;            /* outer HV after derefing the RV       */
    SV *hrv;            /* dbi inner handle RV-to-HV            */

    /* enable a raw HV (not ref-to-HV) to be passed in, eg DBIc_MY_H */
    ohv = SvROK(orv) ? SvRV(orv) : orv;

    if (!ohv || SvTYPE(ohv) != SVt_PVHV) {
        if (!what)
            return NULL;
        if (1) {
            dMY_CXT;
            if (DBIS_TRACE_LEVEL)
                sv_dump(orv);
        }
        if (!SvOK(orv))
            croak("%s given an undefined handle %s",
                what, "(perhaps returned from a previous call which failed)");
        croak("%s handle %s is not a DBI handle", what, neatsvpv(orv,0));
    }
    if (!SvMAGICAL(ohv)) {
        if (!what)
            return NULL;
        if (!hv_fetchs((HV*)ohv,"_NO_DESTRUCT_WARN",0))
	    sv_dump(orv);
        croak("%s handle %s is not a DBI handle (has no magic)",
                what, neatsvpv(orv,0));
    }

    if ( (mg=mg_find(ohv,'P')) == NULL) {       /* hash tie magic       */
        /* not tied, maybe it's already an inner handle... */
        if (mg_find(ohv, DBI_MAGIC) == NULL) {
            if (!what)
                return NULL;
            sv_dump(orv);
            croak("%s handle %s is not a valid DBI handle",
                what, neatsvpv(orv,0));
        }
        hrv = orv; /* was already a DBI handle inner hash */
    }
    else {
        hrv = mg->mg_obj;  /* inner hash of tie */
    }

    return hrv;
}



/* -------------------------------------------------------------------- */
/* Functions to manage a DBI handle (magic and attributes etc).         */

static imp_xxh_t *
dbih_getcom(SV *hrv) /* used by drivers via DBIS func ptr */
{
    MAGIC *mg;
    SV *sv;

    /* short-cut common case */
    if (   SvROK(hrv)
        && (sv = SvRV(hrv))
        && SvRMAGICAL(sv)
        && (mg = SvMAGIC(sv))
        && mg->mg_type == DBI_MAGIC
        && mg->mg_ptr
    )
        return (imp_xxh_t *) mg->mg_ptr;

    {
        dTHX;
        imp_xxh_t *imp_xxh = dbih_getcom2(aTHX_ hrv, 0);
        if (!imp_xxh)       /* eg after take_imp_data */
            croak("Invalid DBI handle %s, has no dbi_imp_data", neatsvpv(hrv,0));
        return imp_xxh;
    }
}

static imp_xxh_t *
dbih_getcom2(pTHX_ SV *hrv, MAGIC **mgp) /* Get com struct for handle. Must be fast.    */
{
    MAGIC *mg;
    SV *sv;

    /* important and quick sanity check (esp non-'safe' Oraperl)        */
    if (SvROK(hrv))                     /* must at least be a ref */
        sv = SvRV(hrv);
    else {
        dMY_CXT;
        if (hrv == DBI_LAST_HANDLE)    /* special for var::FETCH */
            sv = DBI_LAST_HANDLE;
        else if (sv_derived_from(hrv, "DBI::common")) {
            /* probably a class name, if ref($h)->foo() */
            return 0;
        }
        else {
            sv_dump(hrv);
            croak("Invalid DBI handle %s", neatsvpv(hrv,0));
            sv = &PL_sv_undef; /* avoid "might be used uninitialized" warning       */
        }
    }

    /* Short cut for common case. We assume that a magic var always     */
    /* has magic and that DBI_MAGIC, if present, will be the first.     */
    if (SvRMAGICAL(sv) && (mg=SvMAGIC(sv))->mg_type == DBI_MAGIC) {
        /* nothing to do here */
    }
    else {
        /* Validate handle (convert outer to inner if required) */
        hrv = dbih_inner(aTHX_ hrv, "dbih_getcom");
        mg  = mg_find(SvRV(hrv), DBI_MAGIC);
    }
    if (mgp)    /* let caller pickup magic struct for this handle */
        *mgp = mg;

    if (!mg)    /* may happen during global destruction */
        return (imp_xxh_t *) 0;

    return (imp_xxh_t *) mg->mg_ptr;
}


static SV *
dbih_setup_attrib(pTHX_ SV *h, imp_xxh_t *imp_xxh, char *attrib, SV *parent, int read_only, int optional)
{
    STRLEN len = strlen(attrib);
    SV **asvp;

    asvp = hv_fetch((HV*)SvRV(h), attrib, len, !optional);
    /* we assume that we won't have any existing 'undef' attributes here */
    /* (or, alternately, we take undef to mean 'copy from parent')       */
    if (!(asvp && SvOK(*asvp))) { /* attribute doesn't already exists (the common case) */
        SV **psvp;
        if ((!parent || !SvROK(parent)) && !optional) {
            croak("dbih_setup_attrib(%s): %s not set and no parent supplied",
                    neatsvpv(h,0), attrib);
        }
        psvp = hv_fetch((HV*)SvRV(parent), attrib, len, 0);
        if (psvp) {
            if (!asvp)
                asvp = hv_fetch((HV*)SvRV(h), attrib, len, 1);
            sv_setsv(*asvp, *psvp); /* copy attribute from parent to handle */
        }
        else {
            if (!optional)
                croak("dbih_setup_attrib(%s): %s not set and not in parent",
                    neatsvpv(h,0), attrib);
        }
    }
    if (DBIc_TRACE_LEVEL(imp_xxh) >= 5) {
        PerlIO *logfp = DBIc_LOGPIO(imp_xxh);
        PerlIO_printf(logfp,"    dbih_setup_attrib(%s, %s, %s)",
            neatsvpv(h,0), attrib, neatsvpv(parent,0));
        if (!asvp)
             PerlIO_printf(logfp," undef (not defined)\n");
        else
        if (SvOK(*asvp))
             PerlIO_printf(logfp," %s (already defined)\n", neatsvpv(*asvp,0));
        else PerlIO_printf(logfp," %s (copied from parent)\n", neatsvpv(*asvp,0));
    }
    if (read_only && asvp)
        SvREADONLY_on(*asvp);
    return asvp ? *asvp : &PL_sv_undef;
}


static SV *
dbih_make_fdsv(SV *sth, const char *imp_class, STRLEN imp_size, const char *col_name)
{
    dTHX;
    D_imp_sth(sth);
    const STRLEN cn_len = strlen(col_name);
    imp_fdh_t *imp_fdh;
    SV *fdsv;
    if (imp_size < sizeof(imp_fdh_t) || cn_len<10 || strNE("::fd",&col_name[cn_len-4]))
        croak("panic: dbih_makefdsv %s '%s' imp_size %ld invalid",
                imp_class, col_name, (long)imp_size);
    if (DBIc_TRACE_LEVEL(imp_sth) >= 5)
        PerlIO_printf(DBIc_LOGPIO(imp_sth),"    dbih_make_fdsv(%s, %s, %ld, '%s')\n",
                neatsvpv(sth,0), imp_class, (long)imp_size, col_name);
    fdsv = dbih_make_com(sth, (imp_xxh_t*)imp_sth, imp_class, imp_size, cn_len+2, 0);
    imp_fdh = (imp_fdh_t*)(void*)SvPVX(fdsv);
    imp_fdh->com.col_name = ((char*)imp_fdh) + imp_size;
    strcpy(imp_fdh->com.col_name, col_name);
    return fdsv;
}


static SV *
dbih_make_com(SV *p_h, imp_xxh_t *p_imp_xxh, const char *imp_class, STRLEN imp_size, STRLEN extra, SV* imp_templ)
{
    dTHX;
    static const char *errmsg = "Can't make DBI com handle for %s: %s";
    HV *imp_stash;
    SV *dbih_imp_sv;
    imp_xxh_t *imp;
    int trace_level;
    PERL_UNUSED_VAR(extra);

    if ( (imp_stash = gv_stashpv(imp_class, FALSE)) == NULL)
        croak(errmsg, imp_class, "unknown package");

    if (imp_size == 0) {
        /* get size of structure to allocate for common and imp specific data   */
        const char *imp_size_name = mkvname(aTHX_ imp_stash, "imp_data_size", 0);
        imp_size = SvIV(get_sv(imp_size_name, 0x05));
        if (imp_size == 0) {
            imp_size = sizeof(imp_sth_t);
            if (sizeof(imp_dbh_t) > imp_size)
                imp_size = sizeof(imp_dbh_t);
            if (sizeof(imp_drh_t) > imp_size)
                imp_size = sizeof(imp_drh_t);
            imp_size += 4;
        }
    }

    if (p_imp_xxh) {
        trace_level = DBIc_TRACE_LEVEL(p_imp_xxh);
    }
    else {
        dMY_CXT;
        trace_level = DBIS_TRACE_LEVEL;
    }
    if (trace_level >= 5) {
        dMY_CXT;
        PerlIO_printf(DBILOGFP,"    dbih_make_com(%s, %p, %s, %ld, %p) thr#%p\n",
            neatsvpv(p_h,0), (void*)p_imp_xxh, imp_class, (long)imp_size, (void*)imp_templ, (void*)PERL_GET_THX);
    }

    if (imp_templ && SvOK(imp_templ)) {
        U32  imp_templ_flags;
        /* validate the supplied dbi_imp_data looks reasonable, */
        if (SvCUR(imp_templ) != imp_size)
            croak("Can't use dbi_imp_data of wrong size (%ld not %ld)",
                (long)SvCUR(imp_templ), (long)imp_size);

        /* copy the whole template */
        dbih_imp_sv = newSVsv(imp_templ);
        imp = (imp_xxh_t*)(void*)SvPVX(dbih_imp_sv);

        /* sanity checks on the supplied imp_data */
        if (DBIc_TYPE(imp) != ((p_imp_xxh) ? DBIc_TYPE(p_imp_xxh)+1 :1) )
            croak("Can't use dbi_imp_data from different type of handle");
        if (!DBIc_has(imp, DBIcf_IMPSET))
            croak("Can't use dbi_imp_data that not from a setup handle");

        /* copy flags, zero out our imp_xxh struct, restore some flags */
        imp_templ_flags = DBIc_FLAGS(imp);
        switch ( (p_imp_xxh) ? DBIc_TYPE(p_imp_xxh)+1 : DBIt_DR ) {
        case DBIt_DR: memzero((char*)imp, sizeof(imp_drh_t)); break;
        case DBIt_DB: memzero((char*)imp, sizeof(imp_dbh_t)); break;
        case DBIt_ST: memzero((char*)imp, sizeof(imp_sth_t)); break;
        default:      croak("dbih_make_com dbi_imp_data bad h type");
        }
        /* Only pass on DBIcf_IMPSET to indicate to driver that the imp */
        /* structure has been copied and it doesn't need to reconnect.  */
        /* Similarly DBIcf_ACTIVE is also passed along but isn't key.   */
        DBIc_FLAGS(imp) = imp_templ_flags & (DBIcf_IMPSET|DBIcf_ACTIVE);
    }
    else {
        dbih_imp_sv = newSV(imp_size); /* is grown to at least imp_size+1 */
        imp = (imp_xxh_t*)(void*)SvPVX(dbih_imp_sv);
        memzero((char*)imp, imp_size);
        /* set up SV with SvCUR set ready for take_imp_data */
        SvCUR_set(dbih_imp_sv, imp_size);
        *SvEND(dbih_imp_sv) = '\0';
    }

    if (p_imp_xxh) {
        DBIc_DBISTATE(imp)  = DBIc_DBISTATE(p_imp_xxh);
    }
    else {
        dMY_CXT;
        DBIc_DBISTATE(imp)  = DBIS;
    }
    DBIc_IMP_STASH(imp) = imp_stash;

    if (!p_h) {         /* only a driver (drh) has no parent    */
        DBIc_PARENT_H(imp)    = &PL_sv_undef;
        DBIc_PARENT_COM(imp)  = NULL;
        DBIc_TYPE(imp)        = DBIt_DR;
        DBIc_on(imp,DBIcf_WARN          /* set only here, children inherit      */
                   |DBIcf_ACTIVE        /* drivers are 'Active' by default      */
                   |DBIcf_AutoCommit    /* advisory, driver must manage this    */
        );
        DBIc_set(imp, DBIcf_PrintWarn, 1);
    }
    else {
        DBIc_PARENT_H(imp)    = (SV*)SvREFCNT_inc(p_h); /* ensure it lives      */
        DBIc_PARENT_COM(imp)  = p_imp_xxh;              /* shortcut for speed   */
        DBIc_TYPE(imp)        = DBIc_TYPE(p_imp_xxh) + 1;
        /* inherit some flags from parent and carry forward some from template  */
        DBIc_FLAGS(imp)       = (DBIc_FLAGS(p_imp_xxh) & ~DBIcf_INHERITMASK)
                              | (DBIc_FLAGS(imp) & (DBIcf_IMPSET|DBIcf_ACTIVE));
        ++DBIc_KIDS(p_imp_xxh);
    }
#ifdef DBI_USE_THREADS
    DBIc_THR_USER(imp) = PERL_GET_THX ;
#endif

    if (DBIc_TYPE(imp) == DBIt_ST) {
        imp_sth_t *imp_sth = (imp_sth_t*)imp;
        DBIc_ROW_COUNT(imp_sth) = -1;
    }

    DBIc_COMSET_on(imp);        /* common data now set up               */

    /* The implementor should DBIc_IMPSET_on(imp) when setting up       */
    /* any private data which will need clearing/freeing later.         */

    return dbih_imp_sv;
}


static void
dbih_setup_handle(pTHX_ SV *orv, char *imp_class, SV *parent, SV *imp_datasv)
{
    SV *h;
    char *errmsg = "Can't setup DBI handle of %s to %s: %s";
    SV *dbih_imp_sv;
    SV *dbih_imp_rv;
    SV *dbi_imp_data = Nullsv;
    SV **svp;
    SV *imp_mem_name;
    HV  *imp_mem_stash;
    imp_xxh_t *imp;
    imp_xxh_t *parent_imp;
    int trace_level;

    h      = dbih_inner(aTHX_ orv, "dbih_setup_handle");
    parent = dbih_inner(aTHX_ parent, NULL);    /* check parent valid (& inner) */
    if (parent) {
        parent_imp = DBIh_COM(parent);
        trace_level = DBIc_TRACE_LEVEL(parent_imp);
    }
    else {
        dMY_CXT;
        parent_imp = NULL;
        trace_level = DBIS_TRACE_LEVEL;
    }

    if (trace_level >= 5) {
        dMY_CXT;
        PerlIO_printf(DBILOGFP,"    dbih_setup_handle(%s=>%s, %s, %lx, %s)\n",
            neatsvpv(orv,0), neatsvpv(h,0), imp_class, (long)parent, neatsvpv(imp_datasv,0));
    }

    if (mg_find(SvRV(h), DBI_MAGIC) != NULL)
        croak(errmsg, neatsvpv(orv,0), imp_class, "already a DBI (or ~magic) handle");

    imp_mem_name = sv_2mortal(newSVpvf("%s_mem", imp_class));
    if ( (imp_mem_stash = gv_stashsv(imp_mem_name, FALSE)) == NULL)
        croak(errmsg, neatsvpv(orv,0), SvPVbyte_nolen(imp_mem_name), "unknown _mem package");

    if ((svp = hv_fetchs((HV*)SvRV(h), "dbi_imp_data", 0))) {
        dbi_imp_data = *svp;
        if (SvGMAGICAL(dbi_imp_data))  /* call FETCH via magic */
            mg_get(dbi_imp_data);
    }

    DBI_LOCK;

    dbih_imp_sv = dbih_make_com(parent, parent_imp, imp_class, 0, 0, dbi_imp_data);
    imp = (imp_xxh_t*)(void*)SvPVX(dbih_imp_sv);

    dbih_imp_rv = newRV_inc(dbih_imp_sv);       /* just needed for sv_bless */
    sv_bless(dbih_imp_rv, imp_mem_stash);
    sv_free(dbih_imp_rv);

    DBIc_MY_H(imp) = (HV*)SvRV(orv);    /* take _copy_ of pointer, not new ref  */
    DBIc_IMP_DATA(imp) = (imp_datasv) ? newSVsv(imp_datasv) : &PL_sv_undef;
    _imp2com(imp, std.pid) = (U32)PerlProc_getpid();

    if (DBIc_TYPE(imp) <= DBIt_ST) {
        SV **tmp_svp;
        /* Copy some attributes from parent if not defined locally and  */
        /* also take address of attributes for speed of direct access.  */
        /* parent is null for drh, in which case h must hold the values */
#define COPY_PARENT(name,ro,opt) SvREFCNT_inc(dbih_setup_attrib(aTHX_ h,imp,(name),parent,ro,opt))
#define DBIc_ATTR(imp, f) _imp2com(imp, attr.f)
        /* XXX we should validate that these are the right type (refs etc)      */
        DBIc_ATTR(imp, Err)      = COPY_PARENT("Err",1,0);      /* scalar ref   */
        DBIc_ATTR(imp, State)    = COPY_PARENT("State",1,0);    /* scalar ref   */
        DBIc_ATTR(imp, Errstr)   = COPY_PARENT("Errstr",1,0);   /* scalar ref   */
        DBIc_ATTR(imp, TraceLevel)=COPY_PARENT("TraceLevel",0,0);/* scalar (int)*/
        DBIc_ATTR(imp, FetchHashKeyName) = COPY_PARENT("FetchHashKeyName",0,0); /* scalar ref */

        if (parent) {
            dbih_setup_attrib(aTHX_ h,imp,"HandleSetErr",parent,0,1);
            dbih_setup_attrib(aTHX_ h,imp,"HandleError",parent,0,1);
            dbih_setup_attrib(aTHX_ h,imp,"ReadOnly",parent,0,1);
            dbih_setup_attrib(aTHX_ h,imp,"Profile",parent,0,1);

            /* setup Callbacks from parents' ChildCallbacks */
            if (DBIc_has(parent_imp, DBIcf_Callbacks)
            && (tmp_svp = hv_fetchs((HV*)SvRV(parent), "Callbacks", 0))
            && SvROK(*tmp_svp) && SvTYPE(SvRV(*tmp_svp)) == SVt_PVHV
            && (tmp_svp = hv_fetchs((HV*)SvRV(*tmp_svp), "ChildCallbacks", 0))
            && SvROK(*tmp_svp) && SvTYPE(SvRV(*tmp_svp)) == SVt_PVHV
            ) {
                /* XXX mirrors behaviour of dbih_set_attr_k() of Callbacks */
                (void)hv_stores((HV*)SvRV(h), "Callbacks", newRV_inc(SvRV(*tmp_svp)));
                DBIc_set(imp, DBIcf_Callbacks, 1);
            }

            DBIc_LongReadLen(imp) = DBIc_LongReadLen(parent_imp);
#ifdef sv_rvweaken
            if (1) {
                AV *av;
                /* add weakref to new (outer) handle into parents ChildHandles array */
                tmp_svp = hv_fetchs((HV*)SvRV(parent), "ChildHandles", 1);
                if (!SvROK(*tmp_svp)) {
                    SV *ChildHandles_rvav = newRV_noinc((SV*)newAV());
                    sv_setsv(*tmp_svp, ChildHandles_rvav);
                    sv_free(ChildHandles_rvav);
                }
                av = (AV*)SvRV(*tmp_svp);
                av_push(av, (SV*)sv_rvweaken(newRV_inc((SV*)SvRV(orv))));
                if (av_len(av) % 120 == 0) {
                    /* time to do some housekeeping to remove dead handles */
                    I32 i = av_len(av); /* 0 = 1 element */
                    while (i-- >= 0) {
                        SV *sv = av_shift(av);
                        if (SvOK(sv))
                            av_push(av, sv);
                        else
                           sv_free(sv);         /* keep it leak-free by Doru Petrescu pdoru.dbi@from.ro */
                    }
                }
            }
#endif
        }
        else {
            DBIc_LongReadLen(imp) = DBIc_LongReadLen_init;
        }

        switch (DBIc_TYPE(imp)) {
        case DBIt_DB:
            /* cache _inner_ handle, but also see quick_FETCH */
            (void)hv_stores((HV*)SvRV(h), "Driver", newRV_inc(SvRV(parent)));
            (void)hv_fetchs((HV*)SvRV(h), "Statement", 1); /* store writable undef */
            break;
        case DBIt_ST:
            DBIc_NUM_FIELDS((imp_sth_t*)imp) = -1;
            /* cache _inner_ handle, but also see quick_FETCH */
            (void)hv_stores((HV*)SvRV(h), "Database", newRV_inc(SvRV(parent)));
            /* copy (alias) Statement from the sth up into the dbh      */
            tmp_svp = hv_fetchs((HV*)SvRV(h), "Statement", 1);
            (void)hv_stores((HV*)SvRV(parent), "Statement", SvREFCNT_inc(*tmp_svp));
            break;
        }
    }
    else 
        die("panic: invalid DBIc_TYPE");

    /* Use DBI magic on inner handle to carry handle attributes         */
    /* Note that we store the imp_sv in mg_obj, but as a shortcut,      */
    /* also store a direct pointer to imp, aka PVX(dbih_imp_sv),        */
    /* in mg_ptr (with mg_len set to null, so it wont be freed)         */
    sv_magic(SvRV(h), dbih_imp_sv, DBI_MAGIC, (char*)imp, 0);
    SvREFCNT_dec(dbih_imp_sv);  /* since sv_magic() incremented it      */
    SvRMAGICAL_on(SvRV(h));     /* so DBI magic gets sv_clear'd ok      */

    {
    dMY_CXT; /* XXX would be nice to get rid of this */
    DBI_SET_LAST_HANDLE(h);
    }

    if (1) {
        /* This is a hack to work-around the fast but poor way old versions of
         * DBD::Oracle (and possibly other drivers) check for a valid handle
         * using (SvMAGIC(SvRV(h)))->mg_type == 'P'). That doesn't work now
         * because the weakref magic is inserted ahead of the tie magic.
         * So here we swap the tie and weakref magic so the tie comes first.
         */
        MAGIC *tie_mg = mg_find(SvRV(orv),'P');
        MAGIC *first  = SvMAGIC(SvRV(orv));
        if (tie_mg && first->mg_moremagic == tie_mg && !tie_mg->mg_moremagic) {
            MAGIC *next = tie_mg->mg_moremagic;
            SvMAGIC(SvRV(orv)) = tie_mg;
            tie_mg->mg_moremagic = first;
            first->mg_moremagic = next;
        }
    }

    DBI_UNLOCK;
}


static void
dbih_dumphandle(pTHX_ SV *h, const char *msg, int level)
{
    D_imp_xxh(h);
    if (level >= 9) {
        sv_dump(h);
    }
    dbih_dumpcom(aTHX_ imp_xxh, msg, level);
}

static int
dbih_dumpcom(pTHX_ imp_xxh_t *imp_xxh, const char *msg, int level)
{
    dMY_CXT;
    SV *flags = sv_2mortal(newSVpvs(""));
    SV *inner;
    static const char pad[] = "      ";
    if (!msg)
        msg = "dbih_dumpcom";
    PerlIO_printf(DBILOGFP,"    %s (%sh 0x%lx, com 0x%lx, imp %s):\n",
        msg, dbih_htype_name(DBIc_TYPE(imp_xxh)),
        (long)DBIc_MY_H(imp_xxh), (long)imp_xxh,
        (PL_dirty) ? "global destruction" : HvNAME(DBIc_IMP_STASH(imp_xxh)));
    if (DBIc_COMSET(imp_xxh))                   sv_catpv(flags,"COMSET ");
    if (DBIc_IMPSET(imp_xxh))                   sv_catpv(flags,"IMPSET ");
    if (DBIc_ACTIVE(imp_xxh))                   sv_catpv(flags,"Active ");
    if (DBIc_WARN(imp_xxh))                     sv_catpv(flags,"Warn ");
    if (DBIc_COMPAT(imp_xxh))                   sv_catpv(flags,"CompatMode ");
    if (DBIc_is(imp_xxh, DBIcf_ChopBlanks))     sv_catpv(flags,"ChopBlanks ");
    if (DBIc_is(imp_xxh, DBIcf_HandleSetErr))   sv_catpv(flags,"HandleSetErr ");
    if (DBIc_is(imp_xxh, DBIcf_HandleError))    sv_catpv(flags,"HandleError ");
    if (DBIc_is(imp_xxh, DBIcf_RaiseError))     sv_catpv(flags,"RaiseError ");
    if (DBIc_is(imp_xxh, DBIcf_PrintError))     sv_catpv(flags,"PrintError ");
    if (DBIc_is(imp_xxh, DBIcf_RaiseWarn))      sv_catpv(flags,"RaiseWarn ");
    if (DBIc_is(imp_xxh, DBIcf_PrintWarn))      sv_catpv(flags,"PrintWarn ");
    if (DBIc_is(imp_xxh, DBIcf_ShowErrorStatement))     sv_catpv(flags,"ShowErrorStatement ");
    if (DBIc_is(imp_xxh, DBIcf_AutoCommit))     sv_catpv(flags,"AutoCommit ");
    if (DBIc_is(imp_xxh, DBIcf_BegunWork))      sv_catpv(flags,"BegunWork ");
    if (DBIc_is(imp_xxh, DBIcf_LongTruncOk))    sv_catpv(flags,"LongTruncOk ");
    if (DBIc_is(imp_xxh, DBIcf_MultiThread))    sv_catpv(flags,"MultiThread ");
    if (DBIc_is(imp_xxh, DBIcf_TaintIn))        sv_catpv(flags,"TaintIn ");
    if (DBIc_is(imp_xxh, DBIcf_TaintOut))       sv_catpv(flags,"TaintOut ");
    if (DBIc_is(imp_xxh, DBIcf_Profile))        sv_catpv(flags,"Profile ");
    if (DBIc_is(imp_xxh, DBIcf_Callbacks))      sv_catpv(flags,"Callbacks ");
    PerlIO_printf(DBILOGFP,"%s FLAGS 0x%lx: %s\n", pad, (long)DBIc_FLAGS(imp_xxh), SvPV_nolen(flags));
    if (SvOK(DBIc_ERR(imp_xxh)))
        PerlIO_printf(DBILOGFP,"%s ERR %s\n",   pad, neatsvpv((SV*)DBIc_ERR(imp_xxh),0));
    if (SvOK(DBIc_ERR(imp_xxh)))
        PerlIO_printf(DBILOGFP,"%s ERRSTR %s\n",        pad, neatsvpv((SV*)DBIc_ERRSTR(imp_xxh),0));
    PerlIO_printf(DBILOGFP,"%s PARENT %s\n",    pad, neatsvpv((SV*)DBIc_PARENT_H(imp_xxh),0));
    PerlIO_printf(DBILOGFP,"%s KIDS %ld (%ld Active)\n", pad,
                    (long)DBIc_KIDS(imp_xxh), (long)DBIc_ACTIVE_KIDS(imp_xxh));
    if (DBIc_IMP_DATA(imp_xxh) && SvOK(DBIc_IMP_DATA(imp_xxh)))
        PerlIO_printf(DBILOGFP,"%s IMP_DATA %s\n", pad, neatsvpv(DBIc_IMP_DATA(imp_xxh),0));
    if (DBIc_LongReadLen(imp_xxh) != DBIc_LongReadLen_init)
        PerlIO_printf(DBILOGFP,"%s LongReadLen %ld\n", pad, (long)DBIc_LongReadLen(imp_xxh));

    if (DBIc_TYPE(imp_xxh) == DBIt_ST) {
        const imp_sth_t *imp_sth = (imp_sth_t*)imp_xxh;
        PerlIO_printf(DBILOGFP,"%s NUM_OF_FIELDS %d\n", pad, DBIc_NUM_FIELDS(imp_sth));
        PerlIO_printf(DBILOGFP,"%s NUM_OF_PARAMS %d\n", pad, DBIc_NUM_PARAMS(imp_sth));
    }
    inner = dbih_inner(aTHX_ (SV*)DBIc_MY_H(imp_xxh), msg);
    if (!inner || !SvROK(inner))
        return 1;
    if (DBIc_TYPE(imp_xxh) <= DBIt_DB) {
        SV **svp = hv_fetchs((HV*)SvRV(inner), "CachedKids", 0);
        if (svp && SvROK(*svp) && SvTYPE(SvRV(*svp)) == SVt_PVHV) {
            HV *hv = (HV*)SvRV(*svp);
            PerlIO_printf(DBILOGFP,"%s CachedKids %d\n", pad, (int)HvKEYS(hv));
        }
    }
    if (level > 0) {
        SV* value;
        char *key;
        I32   keylen;
        PerlIO_printf(DBILOGFP,"%s cached attributes:\n", pad);
        while ( (value = hv_iternextsv((HV*)SvRV(inner), &key, &keylen)) ) {
            PerlIO_printf(DBILOGFP,"%s   '%s' => %s\n", pad, key, neatsvpv(value,0));
        }
    }
    else if (DBIc_TYPE(imp_xxh) == DBIt_DB) {
        SV **svp = hv_fetchs((HV*)SvRV(inner), "Name", 0);
        if (svp && SvOK(*svp))
            PerlIO_printf(DBILOGFP,"%s Name %s\n", pad, neatsvpv(*svp,0));
    }
    else if (DBIc_TYPE(imp_xxh) == DBIt_ST) {
        SV **svp = hv_fetchs((HV*)SvRV(inner), "Statement", 0);
        if (svp && SvOK(*svp))
            PerlIO_printf(DBILOGFP,"%s Statement %s\n", pad, neatsvpv(*svp,0));
    }
    return 1;
}


static void
dbih_clearcom(imp_xxh_t *imp_xxh)
{
    dTHX;
    dTHR;
    int dump = FALSE;
    int debug = DBIc_TRACE_LEVEL(imp_xxh);
    int auto_dump = (debug >= 6);
    imp_xxh_t * const parent_xxh = DBIc_PARENT_COM(imp_xxh);
    /* Note that we're very much on our own here. DBIc_MY_H(imp_xxh) almost     */
    /* certainly points to memory which has been freed. Don't use it!           */

    /* --- pre-clearing sanity checks --- */

#ifdef DBI_USE_THREADS
    if (DBIc_THR_USER(imp_xxh) != my_perl) { /* don't clear handle that belongs to another thread */
        if (debug >= 3) {
            PerlIO_printf(DBIc_LOGPIO(imp_xxh),"    skipped dbih_clearcom: DBI handle (type=%d, %s) is owned by thread %p not current thread %p\n",
                  DBIc_TYPE(imp_xxh), HvNAME(DBIc_IMP_STASH(imp_xxh)), (void*)DBIc_THR_USER(imp_xxh), (void*)my_perl) ;
            PerlIO_flush(DBIc_LOGPIO(imp_xxh));
        }
        return;
    }
#endif

    if (!DBIc_COMSET(imp_xxh)) {        /* should never happen  */
        dbih_dumpcom(aTHX_ imp_xxh, "dbih_clearcom: DBI handle already cleared", 0);
        return;
    }

    if (auto_dump)
        dbih_dumpcom(aTHX_ imp_xxh,"DESTROY (dbih_clearcom)", 0);

    if (!PL_dirty) {

        if (DBIc_ACTIVE(imp_xxh)) {     /* bad news, potentially        */
            /* warn for sth, warn for dbh only if it has active sth or isn't AutoCommit */
            if (DBIc_TYPE(imp_xxh) >= DBIt_ST
            || (DBIc_ACTIVE_KIDS(imp_xxh) || !DBIc_has(imp_xxh, DBIcf_AutoCommit))
            ) {
                warn("DBI %s handle 0x%lx cleared whilst still active",
                        dbih_htype_name(DBIc_TYPE(imp_xxh)), (unsigned long)DBIc_MY_H(imp_xxh));
                dump = TRUE;
            }
        }

        /* check that the implementor has done its own housekeeping     */
        if (DBIc_IMPSET(imp_xxh)) {
            warn("DBI %s handle 0x%lx has uncleared implementors data",
                    dbih_htype_name(DBIc_TYPE(imp_xxh)), (unsigned long)DBIc_MY_H(imp_xxh));
            dump = TRUE;
        }

        if (DBIc_KIDS(imp_xxh)) {
            warn("DBI %s handle 0x%lx has %d uncleared child handles",
                    dbih_htype_name(DBIc_TYPE(imp_xxh)),
                    (unsigned long)DBIc_MY_H(imp_xxh), (int)DBIc_KIDS(imp_xxh));
            dump = TRUE;
        }
    }

    if (dump && !auto_dump) /* else was already dumped above */
        dbih_dumpcom(aTHX_ imp_xxh, "dbih_clearcom", 0);

    /* --- pre-clearing adjustments --- */

    if (!PL_dirty) {
        if (parent_xxh) {
            if (DBIc_ACTIVE(imp_xxh)) /* see also DBIc_ACTIVE_off */
                --DBIc_ACTIVE_KIDS(parent_xxh);
            --DBIc_KIDS(parent_xxh);
        }
    }

    /* --- clear fields (may invoke object destructors) ---     */

    if (DBIc_TYPE(imp_xxh) == DBIt_ST) {
        imp_sth_t *imp_sth = (imp_sth_t*)imp_xxh;
        sv_free((SV*)DBIc_FIELDS_AV(imp_sth));
    }

    sv_free(DBIc_IMP_DATA(imp_xxh));            /* do this first        */
    if (DBIc_TYPE(imp_xxh) <= DBIt_ST) {        /* DBIt_FD doesn't have attr */
        sv_free(_imp2com(imp_xxh, attr.TraceLevel));
        sv_free(_imp2com(imp_xxh, attr.State));
        sv_free(_imp2com(imp_xxh, attr.Err));
        sv_free(_imp2com(imp_xxh, attr.Errstr));
        sv_free(_imp2com(imp_xxh, attr.FetchHashKeyName));
    }


    sv_free((SV*)DBIc_PARENT_H(imp_xxh));       /* do this last         */

    DBIc_COMSET_off(imp_xxh);

    if (debug >= 4)
        PerlIO_printf(DBIc_LOGPIO(imp_xxh),"    dbih_clearcom 0x%lx (com 0x%lx, type %d) done.\n\n",
                (long)DBIc_MY_H(imp_xxh), (long)imp_xxh, DBIc_TYPE(imp_xxh));
}


/* --- Functions for handling field buffer arrays ---           */

static AV *
dbih_setup_fbav(imp_sth_t *imp_sth)
{
    /*  Usually called to setup the row buffer for new sth.
     *  Also called if the value of NUM_OF_FIELDS is altered,
     *  in which case it adjusts the row buffer to match NUM_OF_FIELDS.
     */
    dTHX;
    I32 i = DBIc_NUM_FIELDS(imp_sth);
    AV *av = DBIc_FIELDS_AV(imp_sth);

    if (i < 0)
        i = 0;

    if (av) {
        if (av_len(av)+1 == i)  /* is existing array the right size? */
            return av;
        /* we need to adjust the size of the array */
        if (DBIc_TRACE_LEVEL(imp_sth) >= 2)
            PerlIO_printf(DBIc_LOGPIO(imp_sth),"    dbih_setup_fbav realloc from %ld to %ld fields\n", (long)(av_len(av)+1), (long)i);
        SvREADONLY_off(av);
        if (i < av_len(av)+1) /* trim to size if too big */
            av_fill(av, i-1);
    }
    else {
        if (DBIc_TRACE_LEVEL(imp_sth) >= 5)
            PerlIO_printf(DBIc_LOGPIO(imp_sth),"    dbih_setup_fbav alloc for %ld fields\n", (long)i);
        av = newAV();
        DBIc_FIELDS_AV(imp_sth) = av;

        /* row_count will need to be manually reset by the driver if the        */
        /* sth is re-executed (since this code won't get rerun)         */
        DBIc_ROW_COUNT(imp_sth) = 0;
    }

    /* load array with writeable SV's. Do this backwards so     */
    /* the array only gets extended once.                       */
    while(i--)                  /* field 1 stored at index 0    */
        av_store(av, i, newSV(0));
    if (DBIc_TRACE_LEVEL(imp_sth) >= 6)
        PerlIO_printf(DBIc_LOGPIO(imp_sth),"    dbih_setup_fbav now %ld fields\n", (long)(av_len(av)+1));
    SvREADONLY_on(av);          /* protect against shift @$row etc */
    return av;
}


static AV *
dbih_get_fbav(imp_sth_t *imp_sth)
{
    AV *av;

    if ( (av = DBIc_FIELDS_AV(imp_sth)) == Nullav) {
        av = dbih_setup_fbav(imp_sth);
    }
    else {
        dTHX;
        int i = av_len(av) + 1;
        if (i != DBIc_NUM_FIELDS(imp_sth)) {
            /*SV *sth = dbih_inner(aTHX_ (SV*)DBIc_MY_H(imp_sth), "_get_fbav");*/
            /* warn via PrintWarn */
            set_err_char(SvRV(DBIc_MY_H(imp_sth)), (imp_xxh_t*)imp_sth,
                    "0", 0, "Number of row fields inconsistent with NUM_OF_FIELDS (driver bug)", "", "_get_fbav");
            /*
            DBIc_NUM_FIELDS(imp_sth) = i;
            hv_deletes((HV*)SvRV(sth), "NUM_OF_FIELDS", G_DISCARD);
            */
        }
        /* don't let SvUTF8 flag persist from one row to the next   */
        /* (only affects drivers that use sv_setpv, but most XS do) */
        /* XXX turn into option later (force on/force off/ignore) */
        while(i--)                  /* field 1 stored at index 0    */
            SvUTF8_off(AvARRAY(av)[i]);
    }

    if (DBIc_is(imp_sth, DBIcf_TaintOut)) {
        dTHX;
        dTHR;
        TAINT;  /* affects sv_setsv()'s called within same perl statement */
    }

    /* XXX fancy stuff to happen here later (re scrolling etc)  */
    ++DBIc_ROW_COUNT(imp_sth);
    return av;
}


static int
dbih_sth_bind_col(SV *sth, SV *col, SV *ref, SV *attribs)
{
    dTHX;
    D_imp_sth(sth);
    AV *av;
    int idx = SvIV(col);
    int fields = DBIc_NUM_FIELDS(imp_sth);

    if (fields <= 0) {
        PERL_UNUSED_VAR(attribs);
        croak("Statement has no result columns to bind%s",
            DBIc_ACTIVE(imp_sth)
                ? "" : " (perhaps you need to successfully call execute first, or again)");
    }

    if ( (av = DBIc_FIELDS_AV(imp_sth)) == Nullav)
        av = dbih_setup_fbav(imp_sth);

    if (DBIc_TRACE_LEVEL(imp_sth) >= 5)
        PerlIO_printf(DBIc_LOGPIO(imp_sth),"    dbih_sth_bind_col %s => %s %s\n",
                neatsvpv(col,0), neatsvpv(ref,0), neatsvpv(attribs,0));

    if (idx < 1 || idx > fields)
        croak("bind_col: column %d is not a valid column (1..%d)",
                        idx, fields);

    if (!SvOK(ref) && SvREADONLY(ref)) {   /* binding to literal undef */
        /* presumably the call is just setting the TYPE or other atribs */
        /* but this default method ignores attribs, so we just return   */
        return 1;
    }

    /* Write this as > SVt_PVMG because in 5.8.x the next type */
    /* is SVt_PVBM, whereas in 5.9.x it's SVt_PVGV.            */
    if (!SvROK(ref) || SvTYPE(SvRV(ref)) > SVt_PVMG) /* XXX LV */
        croak("Can't %s->bind_col(%s, %s,...), need a reference to a scalar",
                neatsvpv(sth,0), neatsvpv(col,0), neatsvpv(ref,0));

    /* use supplied scalar as storage for this column */
    SvREADONLY_off(av);
    av_store(av, idx-1, SvREFCNT_inc(SvRV(ref)) );
    SvREADONLY_on(av);
    return 1;
}


static int
quote_type(int sql_type, int p, int s, int *t, void *v)
{
    /* Returns true if type should be bound as a number else    */
    /* false implying that binding as a string should be okay.  */
    /* The true value is either SQL_INTEGER or SQL_DOUBLE which */
    /* can be used as a hint if desired.                        */
    (void)p;
    (void)s;
    (void)t;
    (void)v;
    /* looks like it's never been used, and doesn't make much sense anyway */
    warn("Use of DBI internal bind_as_num/quote_type function is deprecated");
    switch(sql_type) {
    case SQL_INTEGER:
    case SQL_SMALLINT:
    case SQL_TINYINT:
    case SQL_BIGINT:
        return 0;
    case SQL_FLOAT:
    case SQL_REAL:
    case SQL_DOUBLE:
        return 0;
    case SQL_NUMERIC:
    case SQL_DECIMAL:
        return 0;       /* bind as string to attempt to retain precision */
    }
    return 1;
}


/* Convert a simple string representation of a value into a more specific
 * perl type based on an sql_type value.
 * The semantics of SQL standard TYPE values are interpreted _very_ loosely
 * on the basis of "be liberal in what you accept and let's throw in some
 * extra semantics while we're here" :)
 * Returns:
 *  -2: sql_type isn't handled, value unchanged
 *  -1: sv is undef, value unchanged
 *   0: sv couldn't be cast cleanly and DBIstcf_STRICT was used
 *   1: sv couldn't be cast cleanly and DBIstcf_STRICT was not used
 *   2: sv was cast ok
 */

int
sql_type_cast_svpv(pTHX_ SV *sv, int sql_type, U32 flags, PERL_UNUSED_DECL void *v)
{
    int cast_ok = 0;
    int grok_flags;
    UV uv;

    /* do nothing for undef (NULL) or non-string values */
    if (!sv || !SvOK(sv))
        return -1;

    switch(sql_type) {

    default:
        return -2;   /* not a recognised SQL TYPE, value unchanged */

    case SQL_INTEGER:
        /* sv_2iv is liberal, may return SvIV, SvUV, or SvNV */
        sv_2iv(sv);
        /* SvNOK will be set if value is out of range for IV/UV.
         * SvIOK should be set but won't if sv is not numeric (in which
         * case perl would have warn'd already if -w or warnings are in effect)
         */
        cast_ok = (SvIOK(sv) && !SvNOK(sv));
        break;

    case SQL_DOUBLE:
        sv_2nv(sv);
        /* SvNOK should be set but won't if sv is not numeric (in which
         * case perl would have warn'd already if -w or warnings are in effect)
         */
        cast_ok = SvNOK(sv);
        break;

    /* caller would like IV else UV else NV */
    /* else no error and sv is untouched */
    case SQL_NUMERIC:
        /* based on the code in perl's toke.c */
        uv = 0;
        grok_flags = grok_number(SvPVX(sv), SvCUR(sv), &uv);
        cast_ok = 1;
        if (grok_flags == IS_NUMBER_IN_UV) { /* +ve int */
            if (uv <= IV_MAX)   /* prefer IV over UV */
                 sv_2iv(sv);
            else sv_2uv(sv);
        }
        else if (grok_flags == (IS_NUMBER_IN_UV | IS_NUMBER_NEG)
            && uv <= IV_MAX
        ) {
            sv_2iv(sv);
        }
        else if (grok_flags) { /* is numeric */
            sv_2nv(sv);
        }
        else
            cast_ok = 0;
        break;

#if 0 /* XXX future possibilities */
    case SQL_BIGINT:    /* use Math::BigInt if too large for IV/UV */
#endif
    }

    if (cast_ok) {

        if (flags & DBIstcf_DISCARD_STRING
        && SvNIOK(sv)  /* we set a numeric value */
        && SvPVX(sv)   /* we have a buffer to discard */
        ) {
            SvOOK_off(sv);
            sv_force_normal(sv);
            if (SvLEN(sv))
                Safefree(SvPVX(sv));
            SvPOK_off(sv);
            SvPV_set(sv, NULL);
            SvLEN_set(sv, 0);
            SvCUR_set(sv, 0);
        }
    }

    if (cast_ok)
        return 2;
    else if (flags & DBIstcf_STRICT)
        return 0;
    else return 1;
}



/* --- Generic Handle Attributes (for all handle types) ---     */

static int
dbih_set_attr_k(SV *h, SV *keysv, int dbikey, SV *valuesv)
{
    dTHX;
    dTHR;
    D_imp_xxh(h);
    STRLEN keylen;
    const char  *key = SvPV(keysv, keylen);
    const int    htype = DBIc_TYPE(imp_xxh);
    int    on = (SvTRUE(valuesv));
    int    internal = 1; /* DBIh_IN_PERL_DBD(imp_xxh); -- for DBD's in perl */
    int    cacheit = 0;
    int    weakenit = 0; /* eg for CachedKids ref */
    (void)dbikey;

    if (DBIc_TRACE_LEVEL(imp_xxh) >= 3)
        PerlIO_printf(DBIc_LOGPIO(imp_xxh),"    STORE %s %s => %s\n",
                neatsvpv(h,0), neatsvpv(keysv,0), neatsvpv(valuesv,0));

    if (internal && strEQ(key, "Active")) {
        if (on) {
            D_imp_sth(h);
            DBIc_ACTIVE_on(imp_xxh);
            /* for pure-perl drivers on second and subsequent   */
            /* execute()'s, else row count keeps rising.        */
            if (htype==DBIt_ST && DBIc_FIELDS_AV(imp_sth))
                DBIc_ROW_COUNT(imp_sth) = 0;
        }
        else {
            DBIc_ACTIVE_off(imp_xxh);
        }
    }
    else if (strEQ(key, "FetchHashKeyName")) {
        if (htype >= DBIt_ST)
            croak("Can't set FetchHashKeyName for a statement handle, set in parent before prepare()");
        cacheit = 1;    /* just save it */
    }
    else if (strEQ(key, "CompatMode")) {
        (on) ? DBIc_COMPAT_on(imp_xxh) : DBIc_COMPAT_off(imp_xxh);
    }
    else if (strEQ(key, "Warn")) {
        (on) ? DBIc_WARN_on(imp_xxh) : DBIc_WARN_off(imp_xxh);
    }
    else if (strEQ(key, "AutoInactiveDestroy")) {
        (on) ? DBIc_AIADESTROY_on(imp_xxh) : DBIc_AIADESTROY_off(imp_xxh);
    }
    else if (strEQ(key, "InactiveDestroy")) {
        (on) ? DBIc_IADESTROY_on(imp_xxh) : DBIc_IADESTROY_off(imp_xxh);
    }
    else if (strEQ(key, "RootClass")) {
        cacheit = 1;    /* just save it */
    }
    else if (strEQ(key, "RowCacheSize")) {
        cacheit = 0;    /* ignore it */
    }
    else if (strEQ(key, "Executed")) {
        DBIc_set(imp_xxh, DBIcf_Executed, on);
    }
    else if (strEQ(key, "ChopBlanks")) {
        DBIc_set(imp_xxh, DBIcf_ChopBlanks, on);
    }
    else if (strEQ(key, "ErrCount")) {
        DBIc_ErrCount(imp_xxh) = SvUV(valuesv);
    }
    else if (strEQ(key, "LongReadLen")) {
        if (SvNV(valuesv) < 0 || SvNV(valuesv) > MAX_LongReadLen)
            croak("Can't set LongReadLen < 0 or > %ld",MAX_LongReadLen);
        DBIc_LongReadLen(imp_xxh) = SvIV(valuesv);
        cacheit = 1;    /* save it for clone */
    }
    else if (strEQ(key, "LongTruncOk")) {
        DBIc_set(imp_xxh,DBIcf_LongTruncOk, on);
    }
    else if (strEQ(key, "RaiseError")) {
        DBIc_set(imp_xxh,DBIcf_RaiseError, on);
    }
    else if (strEQ(key, "PrintError")) {
        DBIc_set(imp_xxh,DBIcf_PrintError, on);
    }
    else if (strEQ(key, "RaiseWarn")) {
        DBIc_set(imp_xxh,DBIcf_RaiseWarn, on);
    }
    else if (strEQ(key, "PrintWarn")) {
        DBIc_set(imp_xxh,DBIcf_PrintWarn, on);
    }
    else if (strEQ(key, "HandleError")) {
        if ( on && (!SvROK(valuesv) || (SvTYPE(SvRV(valuesv)) != SVt_PVCV)) ) {
            croak("Can't set %s to '%s'", "HandleError", neatsvpv(valuesv,0));
        }
        DBIc_set(imp_xxh,DBIcf_HandleError, on);
        cacheit = 1; /* child copy setup by dbih_setup_handle() */
    }
    else if (strEQ(key, "HandleSetErr")) {
        if ( on && (!SvROK(valuesv) || (SvTYPE(SvRV(valuesv)) != SVt_PVCV)) ) {
            croak("Can't set %s to '%s'","HandleSetErr",neatsvpv(valuesv,0));
        }
        DBIc_set(imp_xxh,DBIcf_HandleSetErr, on);
        cacheit = 1; /* child copy setup by dbih_setup_handle() */
    }
    else if (strEQ(key, "ChildHandles")) {
        if ( on && (!SvROK(valuesv) || (SvTYPE(SvRV(valuesv)) != SVt_PVAV)) ) {
            croak("Can't set %s to '%s'", "ChildHandles", neatsvpv(valuesv,0));
        }
        cacheit = 1; /* just save it in the hash */
    }
    else if (strEQ(key, "Profile")) {
        static const char profile_class[] = "DBI::Profile";
        if (on && (!SvROK(valuesv) || (SvTYPE(SvRV(valuesv)) != SVt_PVHV)) ) {
            /* not a hash ref so use DBI::Profile to work out what to do */
            dTHR;
            dSP;
            I32 returns;
            TAINT_NOT; /* the require is presumed innocent till proven guilty */
            require_pv("DBI/Profile.pm");
            if (SvTRUE(ERRSV)) {
                warn("Can't load %s: %s", profile_class, SvPV_nolen(ERRSV));
                valuesv = &PL_sv_undef;
            }
            else {
                PUSHMARK(SP);
                mXPUSHs(newSVpv(profile_class, 0));
                XPUSHs(valuesv);
                PUTBACK;
                returns = call_method("_auto_new", G_SCALAR);
                if (returns != 1)
                    croak("%s _auto_new", profile_class);
                SPAGAIN;
                valuesv = POPs;
                PUTBACK;
            }
            on = SvTRUE(valuesv); /* in case it returns undef */
        }
        if (on && !sv_isobject(valuesv)) {
            /* not blessed already - so default to DBI::Profile */
            HV *stash;
            require_pv(profile_class);
            stash = gv_stashpv(profile_class, GV_ADDWARN);
            sv_bless(valuesv, stash);
        }
        DBIc_set(imp_xxh,DBIcf_Profile, on);
        cacheit = 1; /* child copy setup by dbih_setup_handle() */
    }
    else if (strEQ(key, "ShowErrorStatement")) {
        DBIc_set(imp_xxh,DBIcf_ShowErrorStatement, on);
    }
    else if (strEQ(key, "MultiThread") && internal) {
        /* here to allow pure-perl drivers to set MultiThread */
        DBIc_set(imp_xxh,DBIcf_MultiThread, on);
        if (on && DBIc_WARN(imp_xxh)) {
            warn("MultiThread support not yet implemented in DBI");
        }
    }
    else if (strEQ(key, "Taint")) {
        /* 'Taint' is a shortcut for both in and out mode */
        DBIc_set(imp_xxh,DBIcf_TaintIn|DBIcf_TaintOut, on);
    }
    else if (strEQ(key, "TaintIn")) {
        DBIc_set(imp_xxh,DBIcf_TaintIn, on);
    }
    else if (strEQ(key, "TaintOut")) {
        DBIc_set(imp_xxh,DBIcf_TaintOut, on);
    }
    else if (htype<=DBIt_DB && keylen==10 && strEQ(key, "CachedKids")
        /* only allow hash refs */
        && SvROK(valuesv) && SvTYPE(SvRV(valuesv))==SVt_PVHV
    ) {
        cacheit = 1;
        weakenit = 1;
    }
    else if (keylen==9 && strEQ(key, "Callbacks")) {
        if ( on && (!SvROK(valuesv) || (SvTYPE(SvRV(valuesv)) != SVt_PVHV)) )
            croak("Can't set Callbacks to '%s'",neatsvpv(valuesv,0));
        /* see also dbih_setup_handle for ChildCallbacks handling */
        DBIc_set(imp_xxh, DBIcf_Callbacks, on);
        cacheit = 1;
    }
    else if (htype<=DBIt_DB && keylen==10 && strEQ(key, "AutoCommit")) {
        /* driver should have intercepted this and either handled it    */
        /* or set valuesv to either the 'magic' on or off value.        */
        if (SvIV(valuesv) != -900 && SvIV(valuesv) != -901)
            croak("DBD driver has not implemented the AutoCommit attribute");
        DBIc_set(imp_xxh,DBIcf_AutoCommit, (SvIV(valuesv)==-901));
    }
    else if (htype==DBIt_DB && keylen==9 && strEQ(key, "BegunWork")) {
        DBIc_set(imp_xxh,DBIcf_BegunWork, on);
    }
    else if (keylen==10  && strEQ(key, "TraceLevel")) {
        set_trace(h, valuesv, Nullsv);
    }
    else if (keylen==9  && strEQ(key, "TraceFile")) { /* XXX undocumented and readonly */
        set_trace_file(valuesv);
    }
    else if (htype==DBIt_ST && strEQ(key, "NUM_OF_FIELDS")) {
        D_imp_sth(h);
        int new_num_fields = (SvOK(valuesv)) ? SvIV(valuesv) : -1;
        DBIc_NUM_FIELDS(imp_sth) = new_num_fields;
        if (DBIc_FIELDS_AV(imp_sth)) { /* modify existing fbav */
            dbih_setup_fbav(imp_sth);
        }
        cacheit = 1;
    }
    else if (htype==DBIt_ST && strEQ(key, "NUM_OF_PARAMS")) {
        D_imp_sth(h);
        DBIc_NUM_PARAMS(imp_sth) = SvIV(valuesv);
        cacheit = 1;
    }
    /* these are here due to clone() needing to set attribs through a public api */
    else if (htype<=DBIt_DB && (strEQ(key, "Name")
                            || strEQ(key,"ImplementorClass")
                            || strEQ(key,"ReadOnly")
                            || strEQ(key,"Statement")
                            || strEQ(key,"Username")
        /* these are here for backwards histerical raisons */
        || strEQ(key,"USER") || strEQ(key,"CURRENT_USER")
    ) ) {
        cacheit = 1;
    }
    /* deal with: NAME_(uc|lc), NAME_hash, NAME_(uc|lc)_hash */
    else if ((keylen==7 || keylen==9 || keylen==12)
        && strnEQ(key, "NAME_", 5)
        && (    (keylen==9 && strEQ(key, "NAME_hash"))
           ||   ((key[5]=='u' || key[5]=='l') && key[6] == 'c'
                && (!key[7] || strnEQ(&key[7], "_hash", 5)))
           )
        ) {
        cacheit = 1;
    }
    else {      /* XXX should really be an event ? */
        if (isUPPER(*key)) {
            char *msg = "Can't set %s->{%s}: unrecognised attribute name or invalid value%s";
            char *hint = "";
            if (strEQ(key, "NUM_FIELDS"))
                hint = ", perhaps you meant NUM_OF_FIELDS";
            warn(msg, neatsvpv(h,0), key, hint);
            return FALSE;       /* don't store it */
        }
        /* Allow private_* attributes to be stored in the cache.        */
        /* This is designed to make life easier for people subclassing  */
        /* the DBI classes and may be of use to simple perl DBD's.      */
        if (strnNE(key,"private_",8) && strnNE(key,"dbd_",4) && strnNE(key,"dbi_",4)) {
            if (DBIc_TRACE_LEVEL(imp_xxh)) { /* change to DBIc_WARN(imp_xxh) once we can validate prefix against registry */
                PerlIO_printf(DBIc_LOGPIO(imp_xxh),"$h->{%s}=%s ignored for invalid driver-specific attribute\n",
                        neatsvpv(keysv,0), neatsvpv(valuesv,0));
            }
            return FALSE;
        }
        cacheit = 1;
    }
    if (cacheit) {
        SV *sv_for_cache = newSVsv(valuesv);
        (void)hv_store((HV*)SvRV(h), key, keylen, sv_for_cache, 0);
        if (weakenit) {
#ifdef sv_rvweaken
            sv_rvweaken(sv_for_cache);
#endif
        }
    }
    return TRUE;
}


static SV *
dbih_get_attr_k(SV *h, SV *keysv, int dbikey)
{
    dTHX;
    dTHR;
    D_imp_xxh(h);
    STRLEN keylen;
    char  *key = SvPV(keysv, keylen);
    int    htype = DBIc_TYPE(imp_xxh);
    SV  *valuesv = Nullsv;
    int    cacheit = FALSE;
    char *p;
    int i;
    SV  *sv;
    SV  **svp;
    (void)dbikey;

    /* DBI quick_FETCH will service some requests (e.g., cached values) */

    if (htype == DBIt_ST) {
        switch (*key) {

          case 'D':
            if (keylen==8 && strEQ(key, "Database")) {
                D_imp_from_child(imp_dbh, imp_dbh_t, imp_xxh);
                valuesv = newRV_inc((SV*)DBIc_MY_H(imp_dbh));
                cacheit = FALSE;  /* else creates ref loop */
            }
            break;

          case 'N':
            if (keylen==8 && strEQ(key, "NULLABLE")) {
                valuesv = &PL_sv_undef;
                break;
            }

            if (keylen==4 && strEQ(key, "NAME")) {
                valuesv = &PL_sv_undef;
                break;
            }

            /* deal with: NAME_(uc|lc), NAME_hash, NAME_(uc|lc)_hash */
            if ((keylen==7 || keylen==9 || keylen==12)
                && strnEQ(key, "NAME_", 5)
                && (    (keylen==9 && strEQ(key, "NAME_hash"))
                      ||        ((key[5]=='u' || key[5]=='l') && key[6] == 'c'
                               && (!key[7] || strnEQ(&key[7], "_hash", 5)))
                    )
                ) {
                D_imp_sth(h);
                valuesv = &PL_sv_undef;

                /* fetch from tied outer handle to trigger FETCH magic */
                svp = hv_fetchs((HV*)DBIc_MY_H(imp_sth), "NAME", FALSE);
                sv = (svp) ? *svp : &PL_sv_undef;
                if (SvGMAGICAL(sv))     /* call FETCH via magic */
                    mg_get(sv);

                if (SvROK(sv)) {
                    AV *name_av = (AV*)SvRV(sv);
                    char *name;
                    int upcase = (key[5] == 'u');
                    AV *av = Nullav;
                    HV *hv = Nullhv;
                    int num_fields_mismatch = 0;

                    if (strEQ(&key[strlen(key)-5], "_hash"))
                        hv = newHV();
                    else av = newAV();
                    i = DBIc_NUM_FIELDS(imp_sth);

                    /* catch invalid NUM_FIELDS */
                    if (i != AvFILL(name_av)+1) {
                        /* flag as mismatch, except for "-1 and empty" case */
                        if ( ! (i == -1 && 0 == AvFILL(name_av)+1) )
                            num_fields_mismatch = 1;
                        i = AvFILL(name_av)+1; /* limit for safe iteration over array */
                    }

		    if (DBIc_TRACE_LEVEL(imp_sth) >= 10 || (num_fields_mismatch && DBIc_WARN(imp_xxh))) {
			PerlIO_printf(DBIc_LOGPIO(imp_sth),"       FETCH $h->{%s} from $h->{NAME} with $h->{NUM_OF_FIELDS} = %d"
			                       " and %ld entries in $h->{NAME}%s\n",
				neatsvpv(keysv,0), DBIc_NUM_FIELDS(imp_sth), AvFILL(name_av)+1,
                                (num_fields_mismatch) ? " (possible bug in driver)" : "");
                    }

                    while (--i >= 0) {
                        sv = newSVsv(AvARRAY(name_av)[i]);
                        name = SvPV_nolen(sv);
                        if (key[5] != 'h') {    /* "NAME_hash" */
                            for (p = name; p && *p; ++p) {
#ifdef toUPPER_LC
                                *p = (upcase) ? toUPPER_LC(*p) : toLOWER_LC(*p);
#else
                                *p = (upcase) ? toUPPER(*p) : toLOWER(*p);
#endif
                            }
                        }
                        if (av)
                            av_store(av, i, sv);
                        else {
                            (void)hv_store(hv, name, SvCUR(sv), newSViv(i), 0);
                            sv_free(sv);
                        }
                    }
                    valuesv = newRV_noinc( (av ? (SV*)av : (SV*)hv) );
                    cacheit = TRUE;     /* can't change */
                }
            }
            else if (keylen==13 && strEQ(key, "NUM_OF_FIELDS")) {
                D_imp_sth(h);
                IV num_fields = DBIc_NUM_FIELDS(imp_sth);
                valuesv = (num_fields < 0) ? &PL_sv_undef : newSViv(num_fields);
                if (num_fields > 0)
                    cacheit = TRUE;     /* can't change once set (XXX except for multiple result sets) */
            }
            else if (keylen==13 && strEQ(key, "NUM_OF_PARAMS")) {
                D_imp_sth(h);
                valuesv = newSViv(DBIc_NUM_PARAMS(imp_sth));
                cacheit = TRUE; /* can't change */
            }
            break;

          case 'P':
            if (strEQ(key, "PRECISION"))
                valuesv = &PL_sv_undef;
            else if (strEQ(key, "ParamValues"))
                valuesv = &PL_sv_undef;
            else if (strEQ(key, "ParamTypes"))
                valuesv = &PL_sv_undef;
            break;

          case 'R':
            if (strEQ(key, "RowsInCache"))
                valuesv = &PL_sv_undef;
            break;

          case 'S':
            if (strEQ(key, "SCALE"))
                valuesv = &PL_sv_undef;
            break;

          case 'T':
            if (strEQ(key, "TYPE"))
                valuesv = &PL_sv_undef;
            break;
        }

    }
    else
    if (htype == DBIt_DB) {
        /* this is here but is, sadly, not called because
         * not-preloading them into the handle attrib cache caused
         * wierdness in t/proxy.t that I never got to the bottom
         * of. One day maybe.  */
        if (keylen==6 && strEQ(key, "Driver")) {
            D_imp_from_child(imp_dbh, imp_dbh_t, imp_xxh);
            valuesv = newRV_inc((SV*)DBIc_MY_H(imp_dbh));
            cacheit = FALSE;  /* else creates ref loop */
        }
    }

    if (valuesv == Nullsv && htype <= DBIt_DB) {
        if (keylen==10 && strEQ(key, "AutoCommit")) {
            valuesv = boolSV(DBIc_has(imp_xxh,DBIcf_AutoCommit));
        }
    }

    if (valuesv == Nullsv) {
        switch (*key) {
          case 'A':
            if (keylen==6 && strEQ(key, "Active")) {
                valuesv = boolSV(DBIc_ACTIVE(imp_xxh));
            }
            else if (keylen==10 && strEQ(key, "ActiveKids")) {
                valuesv = newSViv(DBIc_ACTIVE_KIDS(imp_xxh));
            }
            else if (strEQ(key, "AutoInactiveDestroy")) {
                valuesv = boolSV(DBIc_AIADESTROY(imp_xxh));
            }
            break;

          case 'B':
            if (keylen==9 && strEQ(key, "BegunWork")) {
                valuesv = boolSV(DBIc_has(imp_xxh,DBIcf_BegunWork));
            }
            break;

          case 'C':
            if (strEQ(key, "ChildHandles")) {
                svp = hv_fetch((HV*)SvRV(h), key, keylen, FALSE);
                /* if something has been stored then return it.
                 * otherwise return a dummy empty array if weakrefs are
                 * available, else an undef to indicate that they're not */
                if (svp) {
                    valuesv = newSVsv(*svp);
                } else {
#ifdef sv_rvweaken
                    valuesv = newRV_noinc((SV*)newAV());
#else
                    valuesv = &PL_sv_undef;
#endif
                }
            }
            else if (strEQ(key, "ChopBlanks")) {
                valuesv = boolSV(DBIc_has(imp_xxh,DBIcf_ChopBlanks));
            }
            else if (strEQ(key, "CachedKids")) {
                valuesv = &PL_sv_undef;
            }
            else if (strEQ(key, "CompatMode")) {
                valuesv = boolSV(DBIc_COMPAT(imp_xxh));
            }
            break;

          case 'E':
            if (strEQ(key, "Executed")) {
                valuesv = boolSV(DBIc_is(imp_xxh, DBIcf_Executed));
            }
            else if (strEQ(key, "ErrCount")) {
                valuesv = newSVuv(DBIc_ErrCount(imp_xxh));
            }
            break;

          case 'I':
            if (strEQ(key, "InactiveDestroy")) {
                valuesv = boolSV(DBIc_IADESTROY(imp_xxh));
            }
            break;

          case 'K':
            if (keylen==4 && strEQ(key, "Kids")) {
                valuesv = newSViv(DBIc_KIDS(imp_xxh));
            }
            break;

          case 'L':
            if (keylen==11 && strEQ(key, "LongReadLen")) {
                valuesv = newSVnv((NV)DBIc_LongReadLen(imp_xxh));
            }
            else if (keylen==11 && strEQ(key, "LongTruncOk")) {
                valuesv = boolSV(DBIc_has(imp_xxh,DBIcf_LongTruncOk));
            }
            break;

          case 'M':
            if (keylen==10 && strEQ(key, "MultiThread")) {
                valuesv = boolSV(DBIc_has(imp_xxh,DBIcf_MultiThread));
            }
            break;

          case 'P':
            if (keylen==10 && strEQ(key, "PrintError")) {
                valuesv = boolSV(DBIc_has(imp_xxh,DBIcf_PrintError));
            }
            else if (keylen==9 && strEQ(key, "PrintWarn")) {
                valuesv = boolSV(DBIc_has(imp_xxh,DBIcf_PrintWarn));
            }
            break;

          case 'R':
            if (keylen==10 && strEQ(key, "RaiseError")) {
                valuesv = boolSV(DBIc_has(imp_xxh,DBIcf_RaiseError));
            }
            else if (keylen==9 && strEQ(key, "RaiseWarn")) {
                valuesv = boolSV(DBIc_has(imp_xxh,DBIcf_RaiseWarn));
            }
            else if (keylen==12 && strEQ(key, "RowCacheSize")) {
                valuesv = &PL_sv_undef;
            }
            break;

          case 'S':
            if (keylen==18 && strEQ(key, "ShowErrorStatement")) {
                valuesv = boolSV(DBIc_has(imp_xxh,DBIcf_ShowErrorStatement));
            }
            break;

          case 'T':
            if (keylen==4 && strEQ(key, "Type")) {
                char *type = dbih_htype_name(htype);
                valuesv = newSVpv(type,0);
                cacheit = TRUE; /* can't change */
            }
            else if (keylen==10  && strEQ(key, "TraceLevel")) {
                valuesv = newSViv( DBIc_DEBUGIV(imp_xxh) );
            }
            else if (keylen==5  && strEQ(key, "Taint")) {
                valuesv = boolSV(DBIc_has(imp_xxh,DBIcf_TaintIn) &&
                                 DBIc_has(imp_xxh,DBIcf_TaintOut));
            }
            else if (keylen==7  && strEQ(key, "TaintIn")) {
                valuesv = boolSV(DBIc_has(imp_xxh,DBIcf_TaintIn));
            }
            else if (keylen==8  && strEQ(key, "TaintOut")) {
                valuesv = boolSV(DBIc_has(imp_xxh,DBIcf_TaintOut));
            }
            break;

          case 'W':
            if (keylen==4 && strEQ(key, "Warn")) {
                valuesv = boolSV(DBIc_WARN(imp_xxh));
            }
            break;
        }
    }

    /* finally check the actual hash */
    if (valuesv == Nullsv) {
        valuesv = &PL_sv_undef;
        cacheit = 0;
        svp = hv_fetch((HV*)SvRV(h), key, keylen, FALSE);
        if (svp)
            valuesv = newSVsv(*svp);    /* take copy to mortalize */
        else /* warn unless it's known attribute name */
        if ( !(         (*key=='H' && strEQ(key, "HandleError"))
                ||      (*key=='H' && strEQ(key, "HandleSetErr"))
                ||      (*key=='S' && strEQ(key, "Statement"))
                ||      (*key=='P' && strEQ(key, "ParamArrays"))
                ||      (*key=='P' && strEQ(key, "ParamValues"))
                ||      (*key=='P' && strEQ(key, "Profile"))
                ||      (*key=='R' && strEQ(key, "ReadOnly"))
                ||      (*key=='C' && strEQ(key, "CursorName"))
                ||      (*key=='C' && strEQ(key, "Callbacks"))
                ||      (*key=='U' && strEQ(key, "Username"))
                ||      !isUPPER(*key)  /* dbd_*, private_* etc */
        ))
            warn("Can't get %s->{%s}: unrecognised attribute name",neatsvpv(h,0),key);
    }

    if (cacheit) {
        (void)hv_store((HV*)SvRV(h), key, keylen, newSVsv(valuesv), 0);
    }
    if (DBIc_TRACE_LEVEL(imp_xxh) >= 3)
        PerlIO_printf(DBIc_LOGPIO(imp_xxh),"    .. FETCH %s %s = %s%s\n", neatsvpv(h,0),
            neatsvpv(keysv,0), neatsvpv(valuesv,0), cacheit?" (cached)":"");
    if (valuesv == &PL_sv_yes || valuesv == &PL_sv_no || valuesv == &PL_sv_undef)
        return valuesv; /* no need to mortalize yes or no */
    return sv_2mortal(valuesv);
}



/* -------------------------------------------------------------------- */
/* Functions implementing Error and Event Handling.                     */


static SV *
dbih_event(SV *hrv, const char *evtype, SV *a1, SV *a2)
{
    dTHX;
    /* We arrive here via DBIh_EVENT* macros (see DBIXS.h) called from  */
    /* DBD driver C code OR $h->event() method (in DBD::_::common)      */
    /* XXX VERY OLD INTERFACE/CONCEPT MAY GO SOON */
    /* OR MAY EVOLVE INTO A WAY TO HANDLE 'SUCCESS_WITH_INFO'/'WARNINGS' from db */
    (void)hrv;
    (void)evtype;
    (void)a1;
    (void)a2;
    return &PL_sv_undef;
}


/* ----------------------------------------------------------------- */


STATIC I32
dbi_dopoptosub_at(PERL_CONTEXT *cxstk, I32 startingblock)
{
    dTHX;
    I32 i;
    register PERL_CONTEXT *cx;
    for (i = startingblock; i >= 0; i--) {
        cx = &cxstk[i];
        switch (CxTYPE(cx)) {
        default:
            continue;
        case CXt_EVAL:
        case CXt_SUB:
#ifdef CXt_FORMAT
        case CXt_FORMAT:
#endif
            DEBUG_l( Perl_deb(aTHX_ "(Found sub #%ld)\n", (long)i));
            return i;
        }
    }
    return i;
}


static COP *
dbi_caller_cop()
{
    dTHX;
    register I32 cxix;
    register PERL_CONTEXT *cx;
    register PERL_CONTEXT *ccstack = cxstack;
    PERL_SI *top_si = PL_curstackinfo;
    char *stashname;

    for ( cxix = dbi_dopoptosub_at(ccstack, cxstack_ix) ;; cxix = dbi_dopoptosub_at(ccstack, cxix - 1)) {
        /* we may be in a higher stacklevel, so dig down deeper */
        while (cxix < 0 && top_si->si_type != PERLSI_MAIN) {
            top_si = top_si->si_prev;
            ccstack = top_si->si_cxstack;
            cxix = dbi_dopoptosub_at(ccstack, top_si->si_cxix);
        }
        if (cxix < 0) {
            break;
        }
        if (PL_DBsub && cxix >= 0 && ccstack[cxix].blk_sub.cv == GvCV(PL_DBsub))
            continue;
        cx = &ccstack[cxix];
        stashname = CopSTASHPV(cx->blk_oldcop);
        if (!stashname)
            continue;
        if (!(stashname[0] == 'D' && stashname[1] == 'B'
                && strchr("DI", stashname[2])
                    && (!stashname[3] || (stashname[3] == ':' && stashname[4] == ':'))))
        {
            return cx->blk_oldcop;
        }
        cxix = dbi_dopoptosub_at(ccstack, cxix - 1);
    }
    return NULL;
}

static void
dbi_caller_string(SV *buf, COP *cop, char *prefix, int show_line, int show_path)
{
    dTHX;
    STRLEN len;
    long  line = CopLINE(cop);
    char *file = SvPV(GvSV(CopFILEGV(cop)), len);
    if (!show_path) {
        char *sep;
        if ( (sep=strrchr(file,'/')) || (sep=strrchr(file,'\\')))
            file = sep+1;
    }
    if (show_line) {
        sv_catpvf(buf, "%s%s line %ld", (prefix) ? prefix : "", file, line);
    }
    else {
        sv_catpvf(buf, "%s%s",          (prefix) ? prefix : "", file);
    }
}

static char *
log_where(SV *buf, int append, char *prefix, char *suffix, int show_line, int show_caller, int show_path)
{
    dTHX;
    dTHR;
    if (!buf)
        buf = sv_2mortal(newSVpvs(""));
    else if (!append)
        sv_setpv(buf,"");
    if (CopLINE(PL_curcop)) {
        COP *cop;
        dbi_caller_string(buf, PL_curcop, prefix, show_line, show_path);
        if (show_caller && (cop = dbi_caller_cop())) {
            SV *via = sv_2mortal(newSVpvs(""));
            dbi_caller_string(via, cop, prefix, show_line, show_path);
            sv_catpvf(buf, " via %s", SvPV_nolen(via));
        }
    }
    if (PL_dirty)
        sv_catpvf(buf, " during global destruction");
    if (suffix)
        sv_catpv(buf, suffix);
    return SvPVX(buf);
}


static void
clear_cached_kids(pTHX_ SV *h, imp_xxh_t *imp_xxh, const char *meth_name, int trace_level)
{
    if (DBIc_TYPE(imp_xxh) <= DBIt_DB) {
        SV **svp = hv_fetchs((HV*)SvRV(h), "CachedKids", 0);
        if (svp && SvROK(*svp) && SvTYPE(SvRV(*svp)) == SVt_PVHV) {
            HV *hv = (HV*)SvRV(*svp);
            if (HvKEYS(hv)) {
                if (DBIc_TRACE_LEVEL(imp_xxh) > trace_level)
                    trace_level = DBIc_TRACE_LEVEL(imp_xxh);
                if (trace_level >= 2) {
                    PerlIO_printf(DBIc_LOGPIO(imp_xxh),"    >> %s %s clearing %d CachedKids\n",
                        meth_name, neatsvpv(h,0), (int)HvKEYS(hv));
                    PerlIO_flush(DBIc_LOGPIO(imp_xxh));
                }
                /* This will probably recurse through dispatch to DESTROY the kids */
                /* For drh we should probably explicitly do dbh disconnects */
                hv_clear(hv);
            }
        }
    }
}


static NV
dbi_time() {
# ifdef HAS_GETTIMEOFDAY
#   ifdef PERL_IMPLICIT_SYS
    dTHX;
#   endif
    struct timeval when;
    gettimeofday(&when, (struct timezone *) 0);
    return when.tv_sec + (when.tv_usec / 1000000.0);
# else  /* per-second is almost useless */
# ifdef _WIN32 /* use _ftime() on Win32 (MS Visual C++ 6.0) */
#  if defined(__BORLANDC__)
#   define _timeb timeb
#   define _ftime ftime
#  endif
    struct _timeb when;
    _ftime( &when );
    return when.time + (when.millitm / 1000.0);
# else
    return time(NULL);
# endif
# endif
}


static SV *
_profile_next_node(SV *node, const char *name)
{
    /* step one level down profile Data tree and auto-vivify if required */
    dTHX;
    SV *orig_node = node;
    if (SvROK(node))
        node = SvRV(node);
    if (SvTYPE(node) != SVt_PVHV) {
        HV *hv = newHV();
        if (SvOK(node)) {
            char *key = "(demoted)";
            warn("Profile data element %s replaced with new hash ref (for %s) and original value stored with key '%s'",
                neatsvpv(orig_node,0), name, key);
            (void)hv_store(hv, key, strlen(key), SvREFCNT_inc(orig_node), 0);
        }
        sv_setsv(node, newRV_noinc((SV*)hv));
        node = (SV*)hv;
    }
    node = *hv_fetch((HV*)node, name, strlen(name), 1);
    return node;
}


static SV*
dbi_profile(SV *h, imp_xxh_t *imp_xxh, SV *statement_sv, SV *method, NV t1, NV t2)
{
#define DBIprof_MAX_PATH_ELEM   100
#define DBIprof_COUNT           0
#define DBIprof_TOTAL_TIME      1
#define DBIprof_FIRST_TIME      2
#define DBIprof_MIN_TIME        3
#define DBIprof_MAX_TIME        4
#define DBIprof_FIRST_CALLED    5
#define DBIprof_LAST_CALLED     6
#define DBIprof_max_index       6
    dTHX;
    NV ti = t2 - t1;
    int src_idx = 0;
    HV *dbh_outer_hv = NULL;
    HV *dbh_inner_hv = NULL;
    char *statement_pv;
    char *method_pv;
    SV *profile;
    SV *tmp;
    SV *dest_node;
    AV *av;
    HV *h_hv;

    const int call_depth = DBIc_CALL_DEPTH(imp_xxh);
    const int parent_call_depth = DBIc_PARENT_COM(imp_xxh) ? DBIc_CALL_DEPTH(DBIc_PARENT_COM(imp_xxh)) : 0;
    /* Only count calls originating from the application code   */
    if (call_depth > 1 || parent_call_depth > 0)
        return &PL_sv_undef;

    if (!DBIc_has(imp_xxh, DBIcf_Profile))
        return &PL_sv_undef;

    method_pv = (SvTYPE(method)==SVt_PVCV) ? GvNAME(CvGV(method))
                : isGV(method) ? GvNAME(method)
                : SvOK(method) ? SvPV_nolen(method)
                : "";

    /* we don't profile DESTROY during global destruction */
    if (PL_dirty && instr(method_pv, "DESTROY"))
        return &PL_sv_undef;

    h_hv = (HV*)SvRV(dbih_inner(aTHX_ h, "dbi_profile"));

    profile = *hv_fetchs(h_hv, "Profile", 1);
    if (profile && SvMAGICAL(profile))
        mg_get(profile); /* FETCH */
    if (!profile || !SvROK(profile)) {
        DBIc_set(imp_xxh, DBIcf_Profile, 0); /* disable */
        if (!PL_dirty) {
            if (!profile)
                warn("Profile attribute does not exist");
            else if (SvOK(profile))
                warn("Profile attribute isn't a hash ref (%s,%ld)", neatsvpv(profile,0), (long)SvTYPE(profile));
        }
        return &PL_sv_undef;
    }

    /* statement_sv: undef = use $h->{Statement}, "" (&sv_no) = use empty string */

    if (!SvOK(statement_sv)) {
        SV **psv = hv_fetchs(h_hv, "Statement", 0);
        statement_sv = (psv && SvOK(*psv)) ? *psv : &PL_sv_no;
    }
    statement_pv = SvPV_nolen(statement_sv);

    if (DBIc_TRACE_LEVEL(imp_xxh) >= 4)
        PerlIO_printf(DBIc_LOGPIO(imp_xxh), "       dbi_profile +%" NVff "s %s %s\n",
            ti, method_pv, neatsvpv(statement_sv,0));

    dest_node = _profile_next_node(profile, "Data");

    tmp = *hv_fetchs((HV*)SvRV(profile), "Path", 1);
    if (SvROK(tmp) && SvTYPE(SvRV(tmp))==SVt_PVAV) {
        int len;
        av = (AV*)SvRV(tmp);
        len = av_len(av); /* -1=empty, 0=one element */

        while ( src_idx <= len ) {
            SV *pathsv = AvARRAY(av)[src_idx++];

            if (SvROK(pathsv) && SvTYPE(SvRV(pathsv))==SVt_PVCV) {
                /* call sub, use returned list of values as path */
                /* returning a ref to undef vetos this profile data */
                dSP;
                I32 ax;
                SV *code_sv = SvRV(pathsv);
                I32 items;
                I32 item_idx;
                EXTEND(SP, 4);
                PUSHMARK(SP);
                PUSHs(h);   /* push inner handle, then others params */
                mPUSHs(newSVpv(method_pv, 0));
                PUTBACK;
                SAVE_DEFSV; /* local($_) = $statement */
                DEFSV_set(statement_sv);
                items = call_sv(code_sv, G_LIST);
                SPAGAIN;
                SP -= items ;
                ax = (SP - PL_stack_base) + 1 ;
                for (item_idx=0; item_idx < items; ++item_idx) {
                    SV *item_sv = ST(item_idx);
                    if (SvROK(item_sv)) {
                        if (!SvOK(SvRV(item_sv)))
                            items = -2; /* flag that we're rejecting this profile data */
                        else /* other refs reserved */
                            warn("Ignored ref returned by code ref in Profile Path");
                        break;
                    }
                    dest_node = _profile_next_node(dest_node, (SvOK(item_sv) ? SvPV_nolen(item_sv) : "undef"));
                }
                PUTBACK;
                if (items == -2) /* this profile data was vetoed */
                    return &PL_sv_undef;
            }
            else if (SvROK(pathsv)) {
                /* only meant for refs to scalars currently */
                const char *p = SvPV_nolen(SvRV(pathsv));
                dest_node = _profile_next_node(dest_node, p);
            }
            else if (SvOK(pathsv)) {
                STRLEN len;
                const char *p = SvPV(pathsv,len);
                if (p[0] == '!') { /* special cases */
                    if (p[1] == 'S' && strEQ(p, "!Statement")) {
                        dest_node = _profile_next_node(dest_node, statement_pv);
                    }
                    else if (p[1] == 'M' && strEQ(p, "!MethodName")) {
                        dest_node = _profile_next_node(dest_node, method_pv);
                    }
                    else if (p[1] == 'M' && strEQ(p, "!MethodClass")) {
                        if (SvTYPE(method) == SVt_PVCV) {
                            p = SvPV_nolen((SV*)CvGV(method));
                        }
                        else if (isGV(method)) {
                            /* just using SvPV_nolen(method) sometimes causes an error: */
                            /* "Can't coerce GLOB to string" so we use gv_efullname()   */
                            SV *tmpsv = sv_2mortal(newSVpvs(""));
                            gv_efullname4(tmpsv, (GV*)method, "", TRUE);
                            p = SvPV_nolen(tmpsv);
                            if (*p == '*') ++p; /* skip past leading '*' glob sigil */
                        }
                        else {
                            p = method_pv;
                        }
                        dest_node = _profile_next_node(dest_node, p);
                    }
                    else if (p[1] == 'F' && strEQ(p, "!File")) {
                        dest_node = _profile_next_node(dest_node, log_where(0, 0, "", "", 0, 0, 0));
                    }
                    else if (p[1] == 'F' && strEQ(p, "!File2")) {
                        dest_node = _profile_next_node(dest_node, log_where(0, 0, "", "", 0, 1, 0));
                    }
                    else if (p[1] == 'C' && strEQ(p, "!Caller")) {
                        dest_node = _profile_next_node(dest_node, log_where(0, 0, "", "", 1, 0, 0));
                    }
                    else if (p[1] == 'C' && strEQ(p, "!Caller2")) {
                        dest_node = _profile_next_node(dest_node, log_where(0, 0, "", "", 1, 1, 0));
                    }
                    else if (p[1] == 'T' && (strEQ(p, "!Time") || strnEQ(p, "!Time~", 6))) {
                        char timebuf[20];
                        int factor = 1;
                        if (p[5] == '~') {
                            factor = atoi(&p[6]);
                            if (factor == 0) /* sanity check to avoid div by zero error */
                                factor = 3600;
                        }
                        sprintf(timebuf, "%ld", ((long)(dbi_time()/factor))*factor);
                        dest_node = _profile_next_node(dest_node, timebuf);
                    }
                    else {
                        warn("Unknown ! element in DBI::Profile Path: %s", p);
                        dest_node = _profile_next_node(dest_node, p);
                    }
                }
                else if (p[0] == '{' && p[len-1] == '}') { /* treat as name of dbh attribute to use */
                    SV **attr_svp;
                    if (!dbh_inner_hv) {        /* cache dbh handles the first time we need them */
                        imp_dbh_t *imp_dbh = (DBIc_TYPE(imp_xxh) <= DBIt_DB) ? (imp_dbh_t*)imp_xxh : (imp_dbh_t*)DBIc_PARENT_COM(imp_xxh);
                        dbh_outer_hv = DBIc_MY_H(imp_dbh);
                        if (SvTYPE(dbh_outer_hv) != SVt_PVHV)
                            return &PL_sv_undef;        /* presumably global destruction - bail */
                        dbh_inner_hv = (HV*)SvRV(dbih_inner(aTHX_ (SV*)dbh_outer_hv, "profile"));
                        if (SvTYPE(dbh_inner_hv) != SVt_PVHV)
                            return &PL_sv_undef;        /* presumably global destruction - bail */
                    }
                    /* fetch from inner first, then outer if key doesn't exist */
                    /* (yes, this is an evil premature optimization) */
                    p += 1; len -= 2; /* ignore the braces */
                    if ((attr_svp = hv_fetch(dbh_inner_hv, p, len, 0)) == NULL) {
                        /* try outer (tied) hash - for things like AutoCommit   */
                        /* (will always return something even for unknowns)     */
                        if ((attr_svp = hv_fetch(dbh_outer_hv, p, len, 0))) {
                            if (SvGMAGICAL(*attr_svp))
                                mg_get(*attr_svp); /* FETCH */
                        }
                    }
                    if (!attr_svp)
                        p -= 1; /* unignore the braces */
                    else if (!SvOK(*attr_svp))
                        p = "";
                    else if (!SvTRUE(*attr_svp) && SvPOK(*attr_svp) && SvNIOK(*attr_svp))
                        p = "0"; /* catch &sv_no style special case */
                    else
                        p = SvPV_nolen(*attr_svp);
                    dest_node = _profile_next_node(dest_node, p);
                }
                else {
                    dest_node = _profile_next_node(dest_node, p);
                }
            }
            /* else undef, so ignore */
        }
    }
    else { /* a bad Path value is treated as a Path of just Statement */
        dest_node = _profile_next_node(dest_node, statement_pv);
    }


    if (!SvOK(dest_node)) {
        av = newAV();
        sv_setsv(dest_node, newRV_noinc((SV*)av));
        av_store(av, DBIprof_COUNT,             newSViv(1));
        av_store(av, DBIprof_TOTAL_TIME,        newSVnv(ti));
        av_store(av, DBIprof_FIRST_TIME,        newSVnv(ti));
        av_store(av, DBIprof_MIN_TIME,          newSVnv(ti));
        av_store(av, DBIprof_MAX_TIME,          newSVnv(ti));
        av_store(av, DBIprof_FIRST_CALLED,      newSVnv(t1));
        av_store(av, DBIprof_LAST_CALLED,       newSVnv(t1));
    }
    else {
        tmp = dest_node;
        if (SvROK(tmp))
            tmp = SvRV(tmp);
        if (SvTYPE(tmp) != SVt_PVAV)
            croak("Invalid Profile data leaf element: %s (type %ld)",
                    neatsvpv(tmp,0), (long)SvTYPE(tmp));
        av = (AV*)tmp;
        sv_inc( *av_fetch(av, DBIprof_COUNT, 1));
        tmp = *av_fetch(av, DBIprof_TOTAL_TIME, 1);
        sv_setnv(tmp, SvNV(tmp) + ti);
        tmp = *av_fetch(av, DBIprof_MIN_TIME, 1);
        if (ti < SvNV(tmp)) sv_setnv(tmp, ti);
        tmp = *av_fetch(av, DBIprof_MAX_TIME, 1);
        if (ti > SvNV(tmp)) sv_setnv(tmp, ti);
        sv_setnv( *av_fetch(av, DBIprof_LAST_CALLED, 1), t1);
    }
    return dest_node; /* use with caution - copy first, ie sv_mortalcopy() */
}


static void
dbi_profile_merge_nodes(SV *dest, SV *increment)
{
    dTHX;
    AV *d_av, *i_av;
    SV *tmp;
    SV *tmp2;
    NV i_nv;
    int i_is_earlier;

    if (!SvROK(dest) || SvTYPE(SvRV(dest)) != SVt_PVAV)
        croak("dbi_profile_merge_nodes(%s, ...) requires array ref", neatsvpv(dest,0));
    d_av = (AV*)SvRV(dest);

    if (av_len(d_av) < DBIprof_max_index) {
        int idx;
        av_extend(d_av, DBIprof_max_index);
        for(idx=0; idx<=DBIprof_max_index; ++idx) {
            tmp = *av_fetch(d_av, idx, 1);
            if (!SvOK(tmp) && idx != DBIprof_MIN_TIME && idx != DBIprof_FIRST_CALLED)
                sv_setnv(tmp, 0.0); /* leave 'min' values as undef */
        }
    }

    if (!SvOK(increment))
        return;

    if (SvROK(increment) && SvTYPE(SvRV(increment)) == SVt_PVHV) {
        HV *hv = (HV*)SvRV(increment);
        char *key;
        I32 keylen = 0;
        hv_iterinit(hv);
        while ( (tmp = hv_iternextsv(hv, &key, &keylen)) != NULL ) {
            dbi_profile_merge_nodes(dest, tmp);
        };
        return;
    }

    if (!SvROK(increment) || SvTYPE(SvRV(increment)) != SVt_PVAV)
        croak("dbi_profile_merge_nodes: increment %s not an array or hash ref", neatsvpv(increment,0));
    i_av = (AV*)SvRV(increment);

    tmp  = *av_fetch(d_av, DBIprof_COUNT, 1);
    tmp2 = *av_fetch(i_av, DBIprof_COUNT, 1);
    if (SvIOK(tmp) && SvIOK(tmp2))
        sv_setiv( tmp, SvIV(tmp) + SvIV(tmp2) );
    else
        sv_setnv( tmp, SvNV(tmp) + SvNV(tmp2) );

    tmp = *av_fetch(d_av, DBIprof_TOTAL_TIME, 1);
    sv_setnv( tmp, SvNV(tmp) + SvNV( *av_fetch(i_av, DBIprof_TOTAL_TIME, 1)) );

    i_nv = SvNV(*av_fetch(i_av, DBIprof_MIN_TIME, 1));
    tmp  =      *av_fetch(d_av, DBIprof_MIN_TIME, 1);
    if (!SvOK(tmp) || i_nv < SvNV(tmp)) sv_setnv(tmp, i_nv);

    i_nv = SvNV(*av_fetch(i_av, DBIprof_MAX_TIME, 1));
    tmp  =      *av_fetch(d_av, DBIprof_MAX_TIME, 1);
    if (i_nv > SvNV(tmp)) sv_setnv(tmp, i_nv);

    i_nv = SvNV(*av_fetch(i_av, DBIprof_FIRST_CALLED, 1));
    tmp  =      *av_fetch(d_av, DBIprof_FIRST_CALLED, 1);
    i_is_earlier = (!SvOK(tmp) || i_nv < SvNV(tmp));
    if (i_is_earlier)
        sv_setnv(tmp, i_nv);

    i_nv = SvNV(*av_fetch(i_av, DBIprof_FIRST_TIME, 1));
    tmp  =      *av_fetch(d_av, DBIprof_FIRST_TIME, 1);
    if (i_is_earlier || !SvOK(tmp)) {
        /* If the increment has an earlier DBIprof_FIRST_CALLED
        then we set the DBIprof_FIRST_TIME from the increment */
        sv_setnv(tmp, i_nv);
    }

    i_nv = SvNV(*av_fetch(i_av, DBIprof_LAST_CALLED, 1));
    tmp  =      *av_fetch(d_av, DBIprof_LAST_CALLED, 1);
    if (i_nv > SvNV(tmp)) sv_setnv(tmp, i_nv);
}


/* ----------------------------------------------------------------- */
/* ---   The DBI dispatcher. The heart of the perl DBI.          --- */

XS(XS_DBI_dispatch);            /* prototype to pass -Wmissing-prototypes */
XS(XS_DBI_dispatch)
{
    dXSARGS;
    dORIGMARK;
    dMY_CXT;

    SV *h   = ST(0);            /* the DBI handle we are working with   */
    SV *st1 = ST(1);            /* used in debugging */
    SV *st2 = ST(2);            /* used in debugging */
    SV *orig_h = h;
    SV *err_sv;
    SV **tmp_svp;
    SV **hook_svp = 0;
    MAGIC *mg;
    I32 gimme = GIMME_V;
    I32 trace_flags = DBIS->debug;      /* local copy may change during dispatch */
    I32 trace_level = (trace_flags & DBIc_TRACE_LEVEL_MASK);
    int is_DESTROY;
    meth_types meth_type;
    int is_unrelated_to_Statement = 0;
    U32 keep_error = FALSE;
    UV  ErrCount = UV_MAX;
    int i, outitems;
    int call_depth;
    int is_nested_call;
    NV profile_t1 = 0.0;
    int is_orig_method_name = 1;

    const char  *meth_name = GvNAME(CvGV(cv));
    dbi_ima_t *ima = (dbi_ima_t*)CvXSUBANY(cv).any_ptr;
    U32   ima_flags;
    imp_xxh_t   *imp_xxh   = NULL;
    SV          *imp_msv   = Nullsv;
    SV          *qsv       = Nullsv; /* quick result from a shortcut method   */


#ifdef BROKEN_DUP_ANY_PTR
    if (ima->my_perl != my_perl) {
        /* we couldn't dup the ima struct at clone time, so do it now */
        dbi_ima_t *nima;
        Newx(nima, 1, dbi_ima_t);
        *nima = *ima; /* structure copy */
        CvXSUBANY(cv).any_ptr = nima;
        nima->stash = NULL;
        nima->gv    = NULL;
        nima->my_perl = my_perl;
        ima = nima;
    }
#endif

    ima_flags  = ima->flags;
    meth_type = ima->meth_type;
    if (trace_level >= 9) {
        PerlIO *logfp = DBILOGFP;
        PerlIO_printf(logfp,"%c   >> %-11s DISPATCH (%s rc%ld/%ld @%ld g%x ima%lx pid#%ld)",
            (PL_dirty?'!':' '), meth_name, neatsvpv(h,0),
            (long)SvREFCNT(h), (SvROK(h) ? (long)SvREFCNT(SvRV(h)) : (long)-1),
            (long)items, (int)gimme, (long)ima_flags, (long)PerlProc_getpid());
        PerlIO_puts(logfp, log_where(0, 0, " at ","\n", 1, (trace_level >= 3), (trace_level >= 4)));
        PerlIO_flush(logfp);
    }

    if ( ( (is_DESTROY=(meth_type == methtype_DESTROY))) ) {
        /* note that croak()'s won't propagate, only append to $@ */
        keep_error = TRUE;
    }

    /* If h is a tied hash ref, switch to the inner ref 'behind' the tie.
       This means *all* DBI methods work with the inner (non-tied) ref.
       This makes it much easier for methods to access the real hash
       data (without having to go through FETCH and STORE methods) and
       for tie and non-tie methods to call each other.
    */
    if (SvROK(h)
        && SvRMAGICAL(SvRV(h))
        && (
               ((mg=SvMAGIC(SvRV(h)))->mg_type == 'P')
            || ((mg=mg_find(SvRV(h),'P')) != NULL)
           )
    ) {
        if (mg->mg_obj==NULL || !SvOK(mg->mg_obj) || SvRV(mg->mg_obj)==NULL) {  /* maybe global destruction */
            if (trace_level >= 3)
                PerlIO_printf(DBILOGFP,
                    "%c   <> %s for %s ignored (inner handle gone)\n",
                    (PL_dirty?'!':' '), meth_name, neatsvpv(h,0));
            XSRETURN(0);
        }
        /* Distinguish DESTROY of tie (outer) from DESTROY of inner ref */
        /* This may one day be used to manually destroy extra internal  */
        /* refs if the application ceases to use the handle.            */
        if (is_DESTROY) {
            imp_xxh = DBIh_COM(mg->mg_obj);
#ifdef DBI_USE_THREADS
            if (imp_xxh && DBIc_THR_USER(imp_xxh) != my_perl) {
                goto is_DESTROY_wrong_thread;
            }
#endif
            if (imp_xxh && DBIc_TYPE(imp_xxh) <= DBIt_DB)
                clear_cached_kids(aTHX_ mg->mg_obj, imp_xxh, meth_name, trace_level);
            /* XXX might be better to move this down to after call_depth has been
             * incremented and then also SvREFCNT_dec(mg->mg_obj) to force an immediate
             * DESTROY of the inner handle if there are no other refs to it.
             * That way the inner DESTROY is properly flagged as a nested call,
             * and the outer DESTROY gets profiled more accurately, and callbacks work.
             */
            if (trace_level >= 3) {
                PerlIO_printf(DBILOGFP,
                    "%c   <> DESTROY(%s) ignored for outer handle (inner %s has ref cnt %ld)\n",
                    (PL_dirty?'!':' '), neatsvpv(h,0), neatsvpv(mg->mg_obj,0),
                    (long)SvREFCNT(SvRV(mg->mg_obj))
                );
            }
            /* for now we ignore it since it'll be followed soon by     */
            /* a destroy of the inner hash and that'll do the real work */

            /* However, we must at least modify DBIc_MY_H() as that is  */
            /* pointing (without a refcnt inc) to the scalar that is    */
            /* being destroyed, so it'll contain random values later.   */
            if (imp_xxh)
                DBIc_MY_H(imp_xxh) = (HV*)SvRV(mg->mg_obj); /* inner (untied) HV */

            XSRETURN(0);
        }
        h = mg->mg_obj; /* switch h to inner ref                        */
        ST(0) = h;      /* switch handle on stack to inner ref          */
    }

    imp_xxh = dbih_getcom2(aTHX_ h, 0); /* get common Internal Handle Attributes        */
    if (!imp_xxh) {
        if (meth_type == methtype_can) {  /* ref($h)->can("foo")        */
            const char *can_meth = SvPV_nolen(st1);
            SV *rv = &PL_sv_undef;
            GV *gv = gv_fetchmethod_autoload(gv_stashsv(orig_h,FALSE), can_meth, FALSE);
            if (gv && isGV(gv))
                rv = sv_2mortal(newRV_inc((SV*)GvCV(gv)));
            if (trace_level >= 1) {
                PerlIO_printf(DBILOGFP,"    <- %s(%s) = %p\n", meth_name, can_meth, neatsvpv(rv,0));
            }
            ST(0) = rv;
            XSRETURN(1);
        }
        if (trace_level)
            PerlIO_printf(DBILOGFP, "%c   <> %s for %s ignored (no imp_data)\n",
                (PL_dirty?'!':' '), meth_name, neatsvpv(h,0));
        if (!is_DESTROY)
            warn("Can't call %s method on handle %s%s", meth_name, neatsvpv(h,0),
                SvROK(h) ? " after take_imp_data()" : " (not a reference)");
        XSRETURN(0);
    }

    if (DBIc_has(imp_xxh,DBIcf_Profile)) {
        profile_t1 = dbi_time(); /* just get start time here */
    }

#ifdef DBI_USE_THREADS
{
    PerlInterpreter * h_perl;
    is_DESTROY_wrong_thread:
    h_perl = DBIc_THR_USER(imp_xxh) ;
    if (h_perl != my_perl) {
        /* XXX could call a 'handle clone' method here?, for dbh's at least */
        if (is_DESTROY) {
            if (trace_level >= 3) {
                PerlIO_printf(DBILOGFP,"    DESTROY ignored because DBI %sh handle (%s) is owned by thread %p not current thread %p\n",
                      dbih_htype_name(DBIc_TYPE(imp_xxh)), HvNAME(DBIc_IMP_STASH(imp_xxh)),
                      (void*)DBIc_THR_USER(imp_xxh), (void*)my_perl) ;
                PerlIO_flush(DBILOGFP);
            }
            XSRETURN(0); /* don't DESTROY handle, if it is not our's !*/
        }
        croak("%s %s failed: handle %d is owned by thread %lx not current thread %lx (%s)",
            HvNAME(DBIc_IMP_STASH(imp_xxh)), meth_name, DBIc_TYPE(imp_xxh),
            (unsigned long)h_perl, (unsigned long)my_perl,
            "handles can't be shared between threads and your driver may need a CLONE method added");
    }
}
#endif

    if ((i = DBIc_DEBUGIV(imp_xxh))) { /* merge handle into global */
        I32 h_trace_level = (i & DBIc_TRACE_LEVEL_MASK);
        if ( h_trace_level > trace_level )
            trace_level = h_trace_level;
        trace_flags = (trace_flags & ~DBIc_TRACE_LEVEL_MASK)
                    | (          i & ~DBIc_TRACE_LEVEL_MASK)
                    | trace_level;
    }

    /* Check method call against Internal Method Attributes */
    if (ima_flags) {

        if (ima_flags & (IMA_STUB|IMA_FUNC_REDIRECT|IMA_KEEP_ERR|IMA_KEEP_ERR_SUB|IMA_CLEAR_STMT)) {

            if (ima_flags & IMA_STUB) {
                if (meth_type == methtype_can) {
                    const char *can_meth = SvPV_nolen(st1);
                    SV *dbi_msv = Nullsv;
                    /* find handle implementors method (GV or CV) */
                    if ( (imp_msv = (SV*)gv_fetchmethod_autoload(DBIc_IMP_STASH(imp_xxh), can_meth, FALSE)) ) {
                        /* return DBI's CV, not the implementors CV (else we'd bypass dispatch) */
                        /* and anyway, we may have hit a private method not part of the DBI     */
                        GV *gv = gv_fetchmethod_autoload(SvSTASH(SvRV(orig_h)), can_meth, FALSE);
                        if (gv && isGV(gv))
                            dbi_msv = (SV*)GvCV(gv);
                    }
                    if (trace_level >= 1) {
                        PerlIO *logfp = DBILOGFP;
                        PerlIO_printf(logfp,"    <- %s(%s) = %p (%s %p)\n", meth_name, can_meth, (void*)dbi_msv,
                                (imp_msv && isGV(imp_msv)) ? HvNAME(GvSTASH(imp_msv)) : "?", (void*)imp_msv);
                    }
                    ST(0) = (dbi_msv) ? sv_2mortal(newRV_inc(dbi_msv)) : &PL_sv_undef;
                    XSRETURN(1);
                }
                XSRETURN(0);
            }
            if (ima_flags & IMA_FUNC_REDIRECT) {
                /* XXX this doesn't redispatch, nor consider the IMA of the new method */
                SV *meth_name_sv = POPs;
                PUTBACK;
                --items;
                if (!SvPOK(meth_name_sv) || SvNIOK(meth_name_sv))
                    croak("%s->%s() invalid redirect method name %s",
                            neatsvpv(h,0), meth_name, neatsvpv(meth_name_sv,0));
                meth_name = SvPV_nolen(meth_name_sv);
                meth_type = get_meth_type(meth_name);
                is_orig_method_name = 0;
            }
            if (ima_flags & IMA_KEEP_ERR)
                keep_error = TRUE;
            if ((ima_flags & IMA_KEEP_ERR_SUB)
                && !PL_dirty
                && DBIc_PARENT_COM(imp_xxh) && DBIc_CALL_DEPTH(DBIc_PARENT_COM(imp_xxh)) > 0)
                keep_error = TRUE;
            if (ima_flags & IMA_CLEAR_STMT) {
                /* don't use SvOK_off: dbh's Statement may be ref to sth's */
                (void)hv_stores((HV*)SvRV(h), "Statement", &PL_sv_undef);
            }
            if (ima_flags & IMA_CLEAR_CACHED_KIDS)
                clear_cached_kids(aTHX_ h, imp_xxh, meth_name, trace_flags);

        }

        if (ima_flags & IMA_HAS_USAGE) {
            const char *err = NULL;
            char msg[200];

            if (ima->minargs && (items < ima->minargs
                                || (ima->maxargs>0 && items > ima->maxargs))) {
                sprintf(msg,
                    "DBI %s: invalid number of arguments: got handle + %ld, expected handle + between %d and %d\n",
                    meth_name, (long)items-1, (int)ima->minargs-1, (int)ima->maxargs-1);
                err = msg;
            }
            /* arg type checking could be added here later */
            if (err) {
                croak("%sUsage: %s->%s(%s)", err, "$h", meth_name,
                    (ima->usage_msg) ? ima->usage_msg : "...?");
            }
        }
    }

    is_unrelated_to_Statement = ( (DBIc_TYPE(imp_xxh) == DBIt_ST) ? 0
                                : (DBIc_TYPE(imp_xxh) == DBIt_DR) ? 1
                                : (ima_flags & IMA_UNRELATED_TO_STMT) );

    if (PL_tainting && items > 1              /* method call has args   */
        && DBIc_is(imp_xxh, DBIcf_TaintIn)    /* taint checks requested */
        && !(ima_flags & IMA_NO_TAINT_IN)
    ) {
        for(i=1; i < items; ++i) {
            if (SvTAINTED(ST(i))) {
                char buf[100];
                sprintf(buf,"parameter %d of %s->%s method call",
                        i, SvPV_nolen(h), meth_name);
                PL_tainted = 1; /* needed for TAINT_PROPER to work      */
                TAINT_PROPER(buf);      /* die's */
            }
        }
    }

    /* record this inner handle for use by DBI::var::FETCH      */
    if (is_DESTROY) {

        /* force destruction of any outstanding children */
        if ((tmp_svp = hv_fetchs((HV*)SvRV(h), "ChildHandles", FALSE)) && SvROK(*tmp_svp)) {
            AV *av = (AV*)SvRV(*tmp_svp);
            I32 kidslots;
            PerlIO *logfp = DBILOGFP;

            for (kidslots = AvFILL(av); kidslots >= 0; --kidslots) {
                SV **hp = av_fetch(av, kidslots, FALSE);
                if (!hp || !SvROK(*hp) || SvTYPE(SvRV(*hp))!=SVt_PVHV)
                    break;

                if (trace_level >= 1) {
                    PerlIO_printf(logfp, "on DESTROY handle %s still has child %s (refcnt %ld, obj %d, dirty=%d)\n",
                        neatsvpv(h,0), neatsvpv(*hp, 0), (long)SvREFCNT(*hp), !!sv_isobject(*hp), PL_dirty);
                    if (trace_level >= 9)
                        sv_dump(SvRV(*hp));
                }
                if (sv_isobject(*hp)) { /* call DESTROY on the handle */
                    PUSHMARK(SP);
                    XPUSHs(*hp);
                    PUTBACK;
                    call_method("DESTROY", G_VOID|G_EVAL|G_KEEPERR);
                    MSPAGAIN;
                }
                else {
                    imp_xxh_t *imp_xxh = dbih_getcom2(aTHX_ *hp, 0);
                    if (imp_xxh && DBIc_COMSET(imp_xxh)) {
                        dbih_clearcom(imp_xxh);
                        sv_setsv(*hp, &PL_sv_undef);
                    }
                }
            }
        }

        if (DBIc_TYPE(imp_xxh) <= DBIt_DB ) {   /* is dbh or drh */
            imp_xxh_t *parent_imp;

            if (SvOK(DBIc_ERR(imp_xxh)) && (parent_imp = DBIc_PARENT_COM(imp_xxh))
                && !PL_dirty /* XXX - remove? */
            ) {
                /* copy err/errstr/state values to $DBI::err etc still work */
                sv_setsv(DBIc_ERR(parent_imp),    DBIc_ERR(imp_xxh));
                sv_setsv(DBIc_ERRSTR(parent_imp), DBIc_ERRSTR(imp_xxh));
                sv_setsv(DBIc_STATE(parent_imp),  DBIc_STATE(imp_xxh));
            }
        }

        if (DBIc_AIADESTROY(imp_xxh)) { /* wants ineffective destroy after fork */
            if ((U32)PerlProc_getpid() != _imp2com(imp_xxh, std.pid))
                DBIc_set(imp_xxh, DBIcf_IADESTROY, 1);
        }
        if (DBIc_IADESTROY(imp_xxh)) {  /* wants ineffective destroy    */
            DBIc_ACTIVE_off(imp_xxh);
        }
        call_depth = 0;
        is_nested_call = 0;
    }
    else {
        DBI_SET_LAST_HANDLE(h);
        SAVEINT(DBIc_CALL_DEPTH(imp_xxh));
        call_depth = ++DBIc_CALL_DEPTH(imp_xxh);

        if (ima_flags & IMA_COPY_UP_STMT) { /* execute() */
            copy_statement_to_parent(aTHX_ h, imp_xxh);
        }
        is_nested_call =
            (call_depth > 1
                || (!PL_dirty /* not in global destruction [CPAN #75614] */
                    && DBIc_PARENT_COM(imp_xxh)
                    && DBIc_CALL_DEPTH(DBIc_PARENT_COM(imp_xxh))) >= 1);

    }


    /* --- dispatch --- */

    if (!keep_error && meth_type != methtype_set_err) {
        SV *err_sv;
        if (trace_level && SvOK(err_sv=DBIc_ERR(imp_xxh))) {
            PerlIO *logfp = DBILOGFP;
            PerlIO_printf(logfp, "    !! The %s '%s' was CLEARED by call to %s method\n",
                SvTRUE(err_sv) ? "ERROR" : strlen(SvPV_nolen(err_sv)) ? "warn" : "info",
                neatsvpv(DBIc_ERR(imp_xxh),0), meth_name);
        }
        DBIh_CLEAR_ERROR(imp_xxh);
    }
    else {      /* we check for change in ErrCount/err_hash during call */
        ErrCount = DBIc_ErrCount(imp_xxh);
        if (keep_error)
            keep_error = err_hash(aTHX_ imp_xxh);
    }

    if (DBIc_has(imp_xxh,DBIcf_Callbacks)
        && (tmp_svp = hv_fetchs((HV*)SvRV(h), "Callbacks", 0))
        && (   (hook_svp = hv_fetch((HV*)SvRV(*tmp_svp), meth_name, strlen(meth_name), 0))
              /* the "*" fallback callback only applies to non-nested calls
               * and also doesn't apply to the 'set_err' or DESTROY methods.
               * Nor during global destruction.
               * Other restrictions may be added over time.
               * It's an undocumented hack.
               */
          || (!is_nested_call && !PL_dirty && meth_type != methtype_set_err &&
               meth_type != methtype_DESTROY &&
               (hook_svp = hv_fetchs((HV*)SvRV(*tmp_svp), "*", 0))
             )
        )
        && SvROK(*hook_svp)
    ) {
        SV *orig_defsv;
        SV *temp_defsv;
        SV *code = SvRV(*hook_svp);
        I32 skip_dispatch = 0;
        if (trace_level)
            PerlIO_printf(DBILOGFP, "%c   {{ %s callback %s being invoked with %ld args\n",
                (PL_dirty?'!':' '), meth_name, neatsvpv(*hook_svp,0), (long)items);

        /* we don't use ENTER,SAVETMPS & FREETMPS,LEAVE because we may need mortal
         * results to live long enough to be returned to our caller
         */
        /* we want to localize $_ for the callback but can't just do that alone
         * because we're not using SAVETMPS & FREETMPS, so we have to get sneaky.
         * We still localize, so we're safe from the callback die-ing,
         * but after the callback we manually restore the original $_.
         */
        orig_defsv = DEFSV; /* remember the current $_ */
        SAVE_DEFSV;         /* local($_) = $method_name */
        temp_defsv = sv_2mortal(newSVpv(meth_name,0));
# ifdef SvTEMP_off
        SvTEMP_off(temp_defsv);
# endif
        DEFSV_set(temp_defsv);

        EXTEND(SP, items+1);
        PUSHMARK(SP);
        PUSHs(orig_h);                  /* push outer handle, then others params */
        for (i=1; i < items; ++i) {     /* start at 1 to skip handle */
            PUSHs( ST(i) );
        }
        PUTBACK;
        outitems = call_sv(code, G_LIST); /* call the callback code */
        MSPAGAIN;

        /* The callback code can undef $_ to indicate to skip dispatch */
        skip_dispatch = !SvOK(DEFSV);
        /* put $_ back now */
        DEFSV_set(orig_defsv);

        if (trace_level)
            PerlIO_printf(DBILOGFP, "%c   }} %s callback %s returned%s\n",
                (PL_dirty?'!':' '), meth_name, neatsvpv(*hook_svp,0),
                skip_dispatch ? ", actual method will not be called" : ""
            );
        if (skip_dispatch) {    /* XXX experimental */
            int ix = outitems;
            /* copy the new items down to the destination list */
            while (ix-- > 0) {
                if(0)warn("\tcopy down %d: %s overwriting %s\n", ix, SvPV_nolen(TOPs), SvPV_nolen(ST(ix)) );
                ST(ix) = POPs;
            }
            imp_msv = *hook_svp; /* for trace and profile */
            goto post_dispatch;
        }
        else {
            if (outitems != 0)
                die("Callback for %s returned %d values but must not return any (temporary restriction in current version)",
                        meth_name, (int)outitems);
            /* POP's and PUTBACK? to clear stack */
        }
    }

    /* set Executed after Callbacks so it's not set if callback elects to skip the method */
    if (ima_flags & IMA_EXECUTE) {
        imp_xxh_t *parent = DBIc_PARENT_COM(imp_xxh);
        DBIc_on(imp_xxh, DBIcf_Executed);
        if (parent)
            DBIc_on(parent, DBIcf_Executed);
    }

    /* The "quick_FETCH" logic...                                       */
    /* Shortcut for fetching attributes to bypass method call overheads */
    if (meth_type == methtype_FETCH && !DBIc_COMPAT(imp_xxh)) {
        STRLEN kl;
        const char *key = SvPV(st1, kl);
        SV **attr_svp;
        if (*key != '_' && (attr_svp=hv_fetch((HV*)SvRV(h), key, kl, 0))) {
            qsv = *attr_svp;
            /* disable FETCH from cache for special attributes */
            if (SvROK(qsv) && SvTYPE(SvRV(qsv))==SVt_PVHV && *key=='D' &&
                (  (kl==6 && DBIc_TYPE(imp_xxh)==DBIt_DB && strEQ(key,"Driver"))
                || (kl==8 && DBIc_TYPE(imp_xxh)==DBIt_ST && strEQ(key,"Database")) )
            ) {
                qsv = Nullsv;
            }
            /* disable profiling of FETCH of Profile data */
            if (*key == 'P' && strEQ(key, "Profile"))
                profile_t1 = 0.0;
        }
        if (qsv) { /* skip real method call if we already have a 'quick' value */
            ST(0) = sv_mortalcopy(qsv);
            outitems = 1;
            goto post_dispatch;
        }
    }

    {
        CV *meth_cv;
#ifdef DBI_save_hv_fetch_ent
        HE save_mh;
        if (meth_type == methtype_FETCH)
            save_mh = PL_hv_fetch_ent_mh; /* XXX nested tied FETCH bug17575 workaround */
#endif

        if (trace_flags) {
            SAVEI32(DBIS->debug);       /* fall back to orig value later */
            DBIS->debug = trace_flags;  /* make new value global (for now) */
            if (ima) {
                /* enabling trace via flags takes precedence over disabling due to min level */
                if ((trace_flags & DBIc_TRACE_FLAGS_MASK) & (ima->method_trace & DBIc_TRACE_FLAGS_MASK))
                    trace_level = (trace_level < 2) ? 2 : trace_level; /* min */
                else
                if (trace_level < (DBIc_TRACE_LEVEL_MASK & ima->method_trace))
                    trace_level = 0;        /* silence dispatch log for this method */
            }
        }

        if (is_orig_method_name
            && ima->stash == DBIc_IMP_STASH(imp_xxh)
            && ima->generation == PL_sub_generation +
                                        MY_cache_gen(DBIc_IMP_STASH(imp_xxh))
        )
            imp_msv = (SV*)ima->gv;
        else {
            imp_msv = (SV*)gv_fetchmethod_autoload(DBIc_IMP_STASH(imp_xxh),
                                            meth_name, FALSE);
            if (is_orig_method_name) {
                /* clear stale entry, if any */
                SvREFCNT_dec(ima->stash);
                SvREFCNT_dec(ima->gv);
                if (!imp_msv) {
                    ima->stash = NULL;
                    ima->gv    = NULL;
                }
                else {
                    ima->stash = (HV*)SvREFCNT_inc(DBIc_IMP_STASH(imp_xxh));
                    ima->gv    = (GV*)SvREFCNT_inc(imp_msv);
                    ima->generation = PL_sub_generation +
                                        MY_cache_gen(DBIc_IMP_STASH(imp_xxh));
                }
            }
        }

        /* if method was a 'func' then try falling back to real 'func' method */
        if (!imp_msv && (ima_flags & IMA_FUNC_REDIRECT)) {
            imp_msv = (SV*)gv_fetchmethod_autoload(DBIc_IMP_STASH(imp_xxh), "func", FALSE);
            if (imp_msv) {
                /* driver does have func method so undo the earlier 'func' stack changes */
                mPUSHs(newSVpv(meth_name, 0));
                PUTBACK;
                ++items;
                meth_name = "func";
                meth_type = methtype_ordinary;
            }
        }

        if (trace_level >= (is_nested_call ? 4 : 2)) {
            PerlIO *logfp = DBILOGFP;
            /* Full pkg method name (or just meth_name for ANON CODE)   */
            const char *imp_meth_name = (imp_msv && isGV(imp_msv)) ? GvNAME(imp_msv) : meth_name;
            HV *imp_stash = DBIc_IMP_STASH(imp_xxh);
            PerlIO_printf(logfp, "%c   -> %s ",
                    call_depth>1 ? '0'+call_depth-1 : (PL_dirty?'!':' '), imp_meth_name);
            if (imp_meth_name[0] == 'A' && strEQ(imp_meth_name,"AUTOLOAD"))
                    PerlIO_printf(logfp, "\"%s\" ", meth_name);
            if (imp_msv && isGV(imp_msv) && GvSTASH(imp_msv) != imp_stash)
                PerlIO_printf(logfp, "in %s ", HvNAME(GvSTASH(imp_msv)));
            PerlIO_printf(logfp, "for %s (%s", HvNAME(imp_stash),
                        SvPV_nolen(orig_h));
            if (h != orig_h)    /* show inner handle to aid tracing */
                 PerlIO_printf(logfp, "~0x%lx", (long)SvRV(h));
            else PerlIO_printf(logfp, "~INNER");
            for(i=1; i<items; ++i) {
                PerlIO_printf(logfp," %s",
                    (ima && i==ima->hidearg) ? "****" : neatsvpv(ST(i),0));
            }
#ifdef DBI_USE_THREADS
            PerlIO_printf(logfp, ") thr#%p\n", (void*)DBIc_THR_USER(imp_xxh));
#else
            PerlIO_printf(logfp, ")\n");
#endif
            PerlIO_flush(logfp);
        }

        if (!imp_msv || ! ((meth_cv = GvCV(imp_msv))) ) {
            if (PL_dirty || is_DESTROY) {
                outitems = 0;
                goto post_dispatch;
            }
            if (ima_flags & IMA_NOT_FOUND_OKAY) {
                outitems = 0;
                goto post_dispatch;
            }
            croak("Can't locate DBI object method \"%s\" via package \"%s\"",
                meth_name, HvNAME(DBIc_IMP_STASH(imp_xxh)));
        }

        PUSHMARK(mark);  /* mark arguments again so we can pass them on */

        /* Note: the handle on the stack is still an object blessed into a
         * DBI::* class and not the DBD::*::* class whose method is being
         * invoked. This is correct and should be largely transparent.
         */

        /* SHORT-CUT ALERT! */
        if (use_xsbypass && CvISXSUB(meth_cv) && CvXSUB(meth_cv)) {

            /* If we are calling an XSUB we jump directly to its C code and
             * bypass perl_call_sv(), pp_entersub() etc. This is fast.
             * This code is based on a small section of pp_entersub().
             */
            (void)(*CvXSUB(meth_cv))(aTHXo_ meth_cv); /* Call the C code directly */

            if (gimme == G_SCALAR) {    /* Enforce sanity in scalar context */
                if (ax != PL_stack_sp - PL_stack_base ) { /* outitems != 1 */
                    ST(0) =
                        (ax > PL_stack_sp - PL_stack_base)
                            ? &PL_sv_undef  /* outitems == 0 */
                            : *PL_stack_sp; /* outitems > 1 */
                    PL_stack_sp = PL_stack_base + ax;
                }
                outitems = 1;
            }
            else {
                outitems = PL_stack_sp - (PL_stack_base + ax - 1);
            }

        }
        else {
            /* sv_dump(imp_msv); */
            outitems = call_sv((SV*)meth_cv,
                (is_DESTROY ? gimme | G_EVAL | G_KEEPERR : gimme) );
        }

        XSprePUSH; /* reset SP to base of stack frame */

#ifdef DBI_save_hv_fetch_ent
        if (meth_type == methtype_FETCH)
            PL_hv_fetch_ent_mh = save_mh;       /* see start of block */
#endif
    }

    post_dispatch:

    if (is_DESTROY && DBI_IS_LAST_HANDLE(h)) { /* if destroying _this_ handle */
        SV *lhp = DBIc_PARENT_H(imp_xxh);
        if (lhp && SvROK(lhp)) {
            DBI_SET_LAST_HANDLE(lhp);
        }
        else {
            DBI_UNSET_LAST_HANDLE;
        }
    }

    if (keep_error) {
        /* if we didn't clear err before the call, check to see if a new error
         * or warning has been recorded. If so, turn off keep_error so it gets acted on
         */
        if (DBIc_ErrCount(imp_xxh) > ErrCount || err_hash(aTHX_ imp_xxh) != keep_error) {
            keep_error = 0;
        }
    }

    err_sv = DBIc_ERR(imp_xxh);

    if (trace_level >= (is_nested_call ? 3 : 1)) {
        PerlIO *logfp = DBILOGFP;
        const int is_fetch  = (meth_type == methtype_fetch_star && DBIc_TYPE(imp_xxh)==DBIt_ST);
        const IV row_count = (is_fetch) ? DBIc_ROW_COUNT((imp_sth_t*)imp_xxh) : 0;
        if (is_fetch && row_count>=2 && trace_level<=4 && SvOK(ST(0))) {
            /* skip the 'middle' rows to reduce output */
            goto skip_meth_return_trace;
        }
        if (SvOK(err_sv)) {
            PerlIO_printf(logfp, "    %s %s %s %s (err#%ld)\n", (keep_error) ? "  " : "!!",
                SvTRUE(err_sv) ? "ERROR:" : strlen(SvPV_nolen(err_sv)) ? "warn:" : "info:",
                neatsvpv(err_sv,0), neatsvpv(DBIc_ERRSTR(imp_xxh),0), (long)DBIc_ErrCount(imp_xxh));
        }
        PerlIO_printf(logfp,"%c%c  <%c %s",
                    (call_depth > 1)  ? '0'+call_depth-1 : (PL_dirty?'!':' '),
                    (DBIc_is(imp_xxh, DBIcf_TaintIn|DBIcf_TaintOut)) ? 'T' : ' ',
                    (qsv) ? '>' : '-',
                    meth_name);
        if (trace_level==1 && (items>=2||is_DESTROY)) { /* make level 1 more useful */
            /* we only have the first two parameters available here */
            if (is_DESTROY) /* show handle as first arg to DESTROY */
                /* want to show outer handle so trace makes sense       */
                /* but outer handle has been destroyed so we fake it    */
                PerlIO_printf(logfp,"(%s=HASH(0x%p)", HvNAME(SvSTASH(SvRV(orig_h))), (void*)DBIc_MY_H(imp_xxh));
            else
                PerlIO_printf(logfp,"(%s", neatsvpv(st1,0));
            if (items >= 3)
                PerlIO_printf(logfp,", %s", neatsvpv(st2,0));
            PerlIO_printf(logfp,"%s)", (items > 3) ? ", ..." : "");
        }

        if (gimme & G_LIST)
             PerlIO_printf(logfp,"= (");
        else PerlIO_printf(logfp,"=");
        for(i=0; i < outitems; ++i) {
            SV *s = ST(i);
            if ( SvROK(s) && SvTYPE(SvRV(s))==SVt_PVAV) {
                AV *av = (AV*)SvRV(s);
                int avi;
                int avi_last = SvIV(DBIS->neatsvpvlen) / 10;
                if (avi_last < 39)
                    avi_last = 39;
                PerlIO_printf(logfp, " [");
                for (avi=0; avi <= AvFILL(av); ++avi) {
                    PerlIO_printf(logfp, " %s",  neatsvpv(AvARRAY(av)[avi],0));
                    if (avi >= avi_last && AvFILL(av) - avi > 1) {
                        PerlIO_printf(logfp, " ... %ld others skipped", AvFILL(av) - avi);
                        break;
                    }
                }
                PerlIO_printf(logfp, " ]");
            }
            else {
                PerlIO_printf(logfp, " %s",  neatsvpv(s,0));
                if ( SvROK(s) && SvTYPE(SvRV(s))==SVt_PVHV && !SvOBJECT(SvRV(s)) )
                    PerlIO_printf(logfp, "%ldkeys", (long)HvKEYS(SvRV(s)));
            }
        }
        if (gimme & G_LIST) {
            PerlIO_printf(logfp," ) [%d items]", outitems);
        }
        if (is_fetch && row_count) {
            PerlIO_printf(logfp," row%"IVdf, row_count);
        }
        if (qsv) /* flag as quick and peek at the first arg (still on the stack) */
            PerlIO_printf(logfp," (%s from cache)", neatsvpv(st1,0));
        else if (!imp_msv)
            PerlIO_printf(logfp," (not implemented)");
        /* XXX add flag to show pid here? */
        /* add file and line number information */
        PerlIO_puts(logfp, log_where(0, 0, " at ", "\n", 1, (trace_level >= 3), (trace_level >= 4)));
    skip_meth_return_trace:
        PerlIO_flush(logfp);
    }

    if (ima_flags & IMA_END_WORK) { /* commit() or rollback() */
        /* XXX does not consider if the method call actually worked or not */
        DBIc_off(imp_xxh, DBIcf_Executed);

        if (DBIc_has(imp_xxh, DBIcf_BegunWork)) {
            DBIc_off(imp_xxh, DBIcf_BegunWork);
            if (!DBIc_has(imp_xxh, DBIcf_AutoCommit)) {
                /* We only get here if the driver hasn't implemented their own code     */
                /* for begin_work, or has but hasn't correctly turned AutoCommit        */
                /* back on in their commit or rollback code. So we have to do it.       */
                /* This is bad because it'll probably trigger a spurious commit()       */
                /* and may mess up the error handling below for the commit/rollback     */
                PUSHMARK(SP);
                XPUSHs(h);
                mXPUSHs(newSVpvs("AutoCommit"));
                XPUSHs(&PL_sv_yes);
                PUTBACK;
                call_method("STORE", G_VOID);
                MSPAGAIN;
            }
        }
    }

    if (PL_tainting
        && DBIc_is(imp_xxh, DBIcf_TaintOut)   /* taint checks requested */
        /* XXX this would taint *everything* being returned from *any*  */
        /* method that doesn't have IMA_NO_TAINT_OUT set.               */
        /* DISABLED: just tainting fetched data in get_fbav seems ok    */
        && 0/* XXX disabled*/ /* !(ima_flags & IMA_NO_TAINT_OUT) */
    ) {
        dTHR;
        TAINT; /* affects sv_setsv()'s within same perl statement */
        for(i=0; i < outitems; ++i) {
            I32 avi;
            char *p;
            SV *s;
            SV *agg = ST(i);
            if ( !SvROK(agg) )
                continue;
            agg = SvRV(agg);
#define DBI_OUT_TAINTABLE(s) (!SvREADONLY(s) && !SvTAINTED(s))
            switch (SvTYPE(agg)) {
            case SVt_PVAV:
                for(avi=0; avi <= AvFILL((AV*)agg); ++avi) {
                    s = AvARRAY((AV*)agg)[avi];
                    if (DBI_OUT_TAINTABLE(s))
                        SvTAINTED_on(s);
                }
                break;
            case SVt_PVHV:
                hv_iterinit((HV*)agg);
                while( (s = hv_iternextsv((HV*)agg, &p, &avi)) ) {
                    if (DBI_OUT_TAINTABLE(s))
                        SvTAINTED_on(s);
                }
                break;
            default:
                if (DBIc_WARN(imp_xxh)) {
                    PerlIO_printf(DBILOGFP,"Don't know how to taint contents of returned %s (type %d)\n",
                        neatsvpv(agg,0), (int)SvTYPE(agg));
                }
            }
        }
    }

    /* if method returned a new handle, and that handle has an error on it
     * then copy the error up into the parent handle
     */
    if (ima_flags & IMA_IS_FACTORY && SvROK(ST(0))) {
        SV *h_new = ST(0);
        D_impdata(imp_xxh_new, imp_xxh_t, h_new);
        if (SvOK(DBIc_ERR(imp_xxh_new))) {
            set_err_sv(h, imp_xxh, DBIc_ERR(imp_xxh_new), DBIc_ERRSTR(imp_xxh_new), DBIc_STATE(imp_xxh_new), &PL_sv_no);
        }
    }

    if (   !keep_error                  /* is a new err/warn/info               */
        && !is_nested_call              /* skip nested (internal) calls         */
        && (
               /* is an error and has RaiseError|PrintError|HandleError set     */
           (SvTRUE(err_sv) && DBIc_has(imp_xxh, DBIcf_RaiseError|DBIcf_PrintError|DBIcf_HandleError))
               /* is a warn (not info) and has RaiseWarn|PrintWarn set          */
        || (  SvOK(err_sv) && strlen(SvPV_nolen(err_sv)) && DBIc_has(imp_xxh, DBIcf_RaiseWarn|DBIcf_PrintWarn))
        )
    ) {
        SV *msg;
        SV **statement_svp = NULL;
        const int is_warning = (!SvTRUE(err_sv) && strlen(SvPV_nolen(err_sv))==1);
        const char *err_meth_name = meth_name;
        char intro[200];

        if (meth_type == methtype_set_err) {
            SV **sem_svp = hv_fetchs((HV*)SvRV(h), "dbi_set_err_method", GV_ADDWARN);
            if (SvOK(*sem_svp))
                err_meth_name = SvPV_nolen(*sem_svp);
        }

        /* XXX change to vsprintf into sv directly */
        sprintf(intro,"%s %s %s: ", HvNAME(DBIc_IMP_STASH(imp_xxh)), err_meth_name,
            SvTRUE(err_sv) ? "failed" : is_warning ? "warning" : "information");
        msg = sv_2mortal(newSVpv(intro,0));
        if (SvOK(DBIc_ERRSTR(imp_xxh)))
            sv_catsv(msg, DBIc_ERRSTR(imp_xxh));
        else
            sv_catpvf(msg, "(err=%s, errstr=undef, state=%s)",
                neatsvpv(DBIc_ERR(imp_xxh),0), neatsvpv(DBIc_STATE(imp_xxh),0) );

        if (    DBIc_has(imp_xxh, DBIcf_ShowErrorStatement)
            && !is_unrelated_to_Statement
            && (DBIc_TYPE(imp_xxh) == DBIt_ST || ima_flags & IMA_SHOW_ERR_STMT)
            && (statement_svp = hv_fetchs((HV*)SvRV(h), "Statement", 0))
            &&  statement_svp && SvOK(*statement_svp)
        ) {
            SV **svp = 0;
            sv_catpv(msg, " [for Statement \"");
            sv_catsv(msg, *statement_svp);

            /* fetch from tied outer handle to trigger FETCH magic  */
            /* could add DBIcf_ShowErrorParams (default to on?)         */
            if (!(ima_flags & IMA_HIDE_ERR_PARAMVALUES)) {
                svp = hv_fetchs((HV*)DBIc_MY_H(imp_xxh),"ParamValues",FALSE);
                if (svp && SvMAGICAL(*svp))
                    mg_get(*svp); /* XXX may recurse, may croak. could use eval */
            }
            if (svp && SvRV(*svp) && SvTYPE(SvRV(*svp)) == SVt_PVHV && HvKEYS(SvRV(*svp))>0 ) {
                SV *param_values_sv = sv_2mortal(_join_hash_sorted((HV*)SvRV(*svp), "=",1, ", ",2, 1, -1));
                sv_catpv(msg, "\" with ParamValues: ");
                sv_catsv(msg, param_values_sv);
                sv_catpvn(msg, "]", 1);
            }
            else {
                sv_catpv(msg, "\"]");
            }
        }

        if (0) {
            COP *cop = dbi_caller_cop();
            if (cop && (CopLINE(cop) != CopLINE(PL_curcop) || CopFILEGV(cop) != CopFILEGV(PL_curcop))) {
                dbi_caller_string(msg, cop, " called via ", 1, 0);
            }
        }

        hook_svp = NULL;
        if (   (SvTRUE(err_sv) || (is_warning && DBIc_has(imp_xxh, DBIcf_RaiseWarn)))
            &&  DBIc_has(imp_xxh, DBIcf_HandleError)
            && (hook_svp = hv_fetchs((HV*)SvRV(h),"HandleError",0))
            &&  hook_svp && SvOK(*hook_svp)
        ) {
            dSP;
            PerlIO *logfp = DBILOGFP;
            IV items;
            SV *status;
            SV *result; /* point to result SV that's pointed to by the stack */
            if (outitems) {
                result = *(sp-outitems+1);
                if (SvREADONLY(result)) {
                    *(sp-outitems+1) = result = sv_2mortal(newSVsv(result));
                }
            }
            else {
                result = sv_newmortal();
            }
            if (trace_level)
                PerlIO_printf(logfp,"    -> HandleError on %s via %s%s%s%s\n",
                    neatsvpv(h,0), neatsvpv(*hook_svp,0),
                    (!outitems ? "" : " ("),
                    (!outitems ? "" : neatsvpv(result ,0)),
                    (!outitems ? "" : ")")
                );
            PUSHMARK(SP);
            XPUSHs(msg);
            mXPUSHs(newRV_inc((SV*)DBIc_MY_H(imp_xxh)));
            XPUSHs( result );
            PUTBACK;
            items = call_sv(*hook_svp, G_SCALAR);
            MSPAGAIN;
            status = (items) ? POPs : &PL_sv_undef;
            PUTBACK;
            if (trace_level)
                PerlIO_printf(logfp,"    <- HandleError= %s%s%s%s\n",
                    neatsvpv(status,0),
                    (!outitems ? "" : " ("),
                    (!outitems ? "" : neatsvpv(result,0)),
                    (!outitems ? "" : ")")
                );
            if (!SvTRUE(status)) /* handler says it didn't handle it, so... */
                hook_svp = 0;  /* pretend we didn't have a handler...     */
        }

        if (profile_t1) { /* see also dbi_profile() call a few lines below */
            SV *statement_sv = (is_unrelated_to_Statement) ? &PL_sv_no : &PL_sv_undef;
            dbi_profile(h, imp_xxh, statement_sv, imp_msv ? imp_msv : (SV*)cv,
                profile_t1, dbi_time());
        }
        if (!hook_svp && is_warning) {
            if (DBIc_has(imp_xxh, DBIcf_PrintWarn))
                warn_sv(msg);
            if (DBIc_has(imp_xxh, DBIcf_RaiseWarn))
                croak_sv(msg);
        }
        else if (!hook_svp && SvTRUE(err_sv)) {
            if (DBIc_has(imp_xxh, DBIcf_PrintError))
                warn_sv(msg);
            if (DBIc_has(imp_xxh, DBIcf_RaiseError))
                croak_sv(msg);
        }
    }
    else if (profile_t1) { /* see also dbi_profile() call a few lines above */
        SV *statement_sv = (is_unrelated_to_Statement) ? &PL_sv_no : &PL_sv_undef;
        dbi_profile(h, imp_xxh, statement_sv, imp_msv ? imp_msv : (SV*)cv,
                profile_t1, dbi_time());
    }
    XSRETURN(outitems);
}



/* -------------------------------------------------------------------- */

/* comment and placeholder styles to accept and return */

#define DBIpp_cm_cs 0x000001   /* C style */
#define DBIpp_cm_hs 0x000002   /* #       */
#define DBIpp_cm_dd 0x000004   /* --      */
#define DBIpp_cm_br 0x000008   /* {}      */
#define DBIpp_cm_dw 0x000010   /* '-- ' dash dash whitespace */
#define DBIpp_cm_XX 0x00001F   /* any of the above */

#define DBIpp_ph_qm 0x000100   /* ?       */
#define DBIpp_ph_cn 0x000200   /* :1      */
#define DBIpp_ph_cs 0x000400   /* :name   */
#define DBIpp_ph_sp 0x000800   /* %s (as return only, not accept)    */
#define DBIpp_ph_XX 0x000F00   /* any of the above */

#define DBIpp_st_qq 0x010000   /* '' char escape */
#define DBIpp_st_bs 0x020000   /* \  char escape */
#define DBIpp_st_XX 0x030000   /* any of the above */

#define DBIpp_L_BRACE '{'
#define DBIpp_R_BRACE '}'
#define PS_accept(flag)  DBIbf_has(ps_accept,(flag))
#define PS_return(flag)  DBIbf_has(ps_return,(flag))

SV *
preparse(SV *dbh, const char *statement, IV ps_return, IV ps_accept, void *foo)
{
    dTHX;
    D_imp_xxh(dbh);
/*
        The idea here is that ps_accept defines which constructs to
        recognize (accept) as valid in the source string (other
        constructs are ignored), and ps_return defines which
        constructs are valid to return in the result string.

        If a construct that is valid in the input is also valid in the
        output then it's simply copied. If it's not valid in the output
        then it's editied into one of the valid forms (ideally the most
        'standard' and/or information preserving one).

        For example, if ps_accept includes '--' style comments but
        ps_return doesn't, but ps_return does include '#' style
        comments then any '--' style comments would be rewritten as '#'
        style comments.

        Similarly for placeholders. DBD::Oracle, for example, would say
        '?', ':1' and ':name' are all acceptable input, but only
        ':name' should be returned.

        (There's a tricky issue with the '--' comment style because it can
        clash with valid syntax, i.e., "... set foo=foo--1 ..." so it
        would be *bad* to misinterpret that as the start of a comment.
        Perhaps we need a DBIpp_cm_dw (for dash-dash-whitespace) style
        to allow for that.)

        Also, we'll only support DBIpp_cm_br as an input style. And
        even then, only with reluctance. We may (need to) drop it when
        we add support for odbc escape sequences.
*/
    int idx = 1;

    char in_quote = '\0';
    char in_comment = '\0';
    char rt_comment = '\0';
    char *dest, *start;
    const char *src;
    const char *style = "", *laststyle = NULL;
    SV *new_stmt_sv;

    (void)foo;

    if (!(ps_return | DBIpp_ph_XX)) { /* no return ph type specified */
        ps_return |= ps_accept | DBIpp_ph_XX;   /* so copy from ps_accept */
    }

    /* XXX this allocation strategy won't work when we get to more advanced stuff */
    new_stmt_sv = newSV(strlen(statement) * 3);
    sv_setpv(new_stmt_sv,"");
    src  = statement;
    dest = SvPVX(new_stmt_sv);

    while( *src )
    {
        if (*src == '%' && PS_return(DBIpp_ph_sp))
            *dest++ = '%';

        if (in_comment)
        {
             if (       (in_comment == '-' && (*src == '\n' || *(src+1) == '\0'))
                ||      (in_comment == '#' && (*src == '\n' || *(src+1) == '\0'))
                ||      (in_comment == DBIpp_L_BRACE && *src == DBIpp_R_BRACE) /* XXX nesting? */
                ||      (in_comment == '/' && *src == '*' && *(src+1) == '/')
             ) {
                switch (rt_comment) {
                case '/':       *dest++ = '*'; *dest++ = '/';   break;
                case '-':       *dest++ = '\n';                 break;
                case '#':       *dest++ = '\n';                 break;
                case DBIpp_L_BRACE: *dest++ = DBIpp_R_BRACE;    break;
                case '\0':      /* ensure deleting a comment doesn't join two tokens */
                        if (in_comment=='/' || in_comment==DBIpp_L_BRACE)
                            *dest++ = ' '; /* ('-' and '#' styles use the newline) */
                        break;
                }
                if (in_comment == '/')
                    src++;
                src += (*src != '\n' || *(dest-1)=='\n') ? 1 : 0;
                in_comment = '\0';
                rt_comment = '\0';
             }
             else
             if (rt_comment)
                *dest++ = *src++;
             else
                src++;  /* delete (don't copy) the comment */
             continue;
        }

        if (in_quote)
        {
            if (*src == in_quote) {
                in_quote = 0;
            }
            *dest++ = *src++;
            continue;
        }

        /* Look for comments */
        if (*src == '-' && *(src+1) == '-' &&
                (PS_accept(DBIpp_cm_dd) || (*(src+2) == ' ' && PS_accept(DBIpp_cm_dw)))
        )
        {
            in_comment = *src;
            src += 2;   /* skip past 2nd char of double char delimiters */
            if (PS_return(DBIpp_cm_dd) || PS_return(DBIpp_cm_dw)) {
                *dest++ = rt_comment = '-';
                *dest++ = '-';
                if (PS_return(DBIpp_cm_dw) && *src!=' ')
                    *dest++ = ' '; /* insert needed white space */
            }
            else if (PS_return(DBIpp_cm_cs)) {
                *dest++ = rt_comment = '/';
                *dest++ = '*';
            }
            else if (PS_return(DBIpp_cm_hs)) {
                *dest++ = rt_comment = '#';
            }
            else if (PS_return(DBIpp_cm_br)) {
                *dest++ = rt_comment = DBIpp_L_BRACE;
            }
            continue;
        }
        else if (*src == '/' && *(src+1) == '*' && PS_accept(DBIpp_cm_cs))
        {
            in_comment = *src;
            src += 2;   /* skip past 2nd char of double char delimiters */
            if (PS_return(DBIpp_cm_cs)) {
                *dest++ = rt_comment = '/';
                *dest++ = '*';
            }
            else if (PS_return(DBIpp_cm_dd) || PS_return(DBIpp_cm_dw)) {
                *dest++ = rt_comment = '-';
                *dest++ = '-';
                if (PS_return(DBIpp_cm_dw)) *dest++ = ' ';
            }
            else if (PS_return(DBIpp_cm_hs)) {
                *dest++ = rt_comment = '#';
            }
            else if (PS_return(DBIpp_cm_br)) {
                *dest++ = rt_comment = DBIpp_L_BRACE;
            }
            continue;
        }
        else if (*src == '#' && PS_accept(DBIpp_cm_hs))
        {
            in_comment = *src;
            src++;
            if (PS_return(DBIpp_cm_hs)) {
                *dest++ = rt_comment = '#';
            }
            else if (PS_return(DBIpp_cm_dd) || PS_return(DBIpp_cm_dw)) {
                *dest++ = rt_comment = '-';
                *dest++ = '-';
                if (PS_return(DBIpp_cm_dw)) *dest++ = ' ';
            }
            else if (PS_return(DBIpp_cm_cs)) {
                *dest++ = rt_comment = '/';
                *dest++ = '*';
            }
            else if (PS_return(DBIpp_cm_br)) {
                *dest++ = rt_comment = DBIpp_L_BRACE;
            }
            continue;
        }
        else if (*src == DBIpp_L_BRACE && PS_accept(DBIpp_cm_br))
        {
            in_comment = *src;
            src++;
            if (PS_return(DBIpp_cm_br)) {
                *dest++ = rt_comment = DBIpp_L_BRACE;
            }
            else if (PS_return(DBIpp_cm_dd) || PS_return(DBIpp_cm_dw)) {
                *dest++ = rt_comment = '-';
                *dest++ = '-';
                if (PS_return(DBIpp_cm_dw)) *dest++ = ' ';
            }
            else if (PS_return(DBIpp_cm_cs)) {
                *dest++ = rt_comment = '/';
                *dest++ = '*';
            }
            else if (PS_return(DBIpp_cm_hs)) {
                *dest++ = rt_comment = '#';
            }
            continue;
        }

       if (    !(*src==':' && (PS_accept(DBIpp_ph_cn) || PS_accept(DBIpp_ph_cs)))
           &&  !(*src=='?' &&  PS_accept(DBIpp_ph_qm))
       ){
            if (*src == '\'' || *src == '"')
                in_quote = *src;
            *dest++ = *src++;
            continue;
        }

        /* only here for : or ? outside of a comment or literal */

        start = dest;                   /* save name inc colon  */
        *dest++ = *src++;               /* copy and move past first char */

        if (*start == '?')              /* X/Open Standard */
        {
            style = "?";

            if (PS_return(DBIpp_ph_qm))
                ;
            else if (PS_return(DBIpp_ph_cn)) { /* '?' -> ':p1' (etc) */
                sprintf(start,":p%d", idx++);
                dest = start+strlen(start);
            }
            else if (PS_return(DBIpp_ph_sp)) { /* '?' -> '%s' */
                   *start  = '%';
                   *dest++ = 's';
            }
        }
        else if (isDIGIT(*src)) {   /* :1 */
            const int pln = atoi(src);
            style = ":1";

            if (PS_return(DBIpp_ph_cn)) { /* ':1'->':p1'  */
                   idx = pln;
                   *dest++ = 'p';
                   while(isDIGIT(*src))
                       *dest++ = *src++;
            }
            else if (PS_return(DBIpp_ph_qm) /* ':1' -> '?'  */
                 ||  PS_return(DBIpp_ph_sp) /* ':1' -> '%s' */
            ) {
                   PS_return(DBIpp_ph_qm) ? sprintf(start,"?") : sprintf(start,"%%s");
                   dest = start + strlen(start);
                   if (pln != idx) {
                        char buf[99];
                        sprintf(buf, "preparse found placeholder :%d out of sequence, expected :%d", pln, idx);
                        set_err_char(dbh, imp_xxh, "1", 1, buf, 0, "preparse");
                        return &PL_sv_undef;
                   }
                   while(isDIGIT(*src)) src++;
                   idx++;
            }
        }
        else if (isALNUM(*src))         /* :name */
        {
            style = ":name";

            if (PS_return(DBIpp_ph_cs)) {
                ;
            }
            else if (PS_return(DBIpp_ph_qm) /* ':name' -> '?'  */
                 ||  PS_return(DBIpp_ph_sp) /* ':name' -> '%s' */
            ) {
                PS_return(DBIpp_ph_qm) ? sprintf(start,"?") : sprintf(start,"%%s");
                dest = start + strlen(start);
                while (isALNUM(*src))   /* consume name, includes '_'   */
                    src++;
            }
        }
        /* perhaps ':=' PL/SQL construct */
        else { continue; }

        *dest = '\0';                   /* handy for debugging  */

        if (laststyle && style != laststyle) {
            char buf[99];
            sprintf(buf, "preparse found mixed placeholder styles (%s / %s)", style, laststyle);
            set_err_char(dbh, imp_xxh, "1", 1, buf, 0, "preparse");
            return &PL_sv_undef;
        }
        laststyle = style;
    }
    *dest = '\0';

    /* warn about probable parsing errors, but continue anyway (returning processed string) */
    switch (in_quote)
    {
    case '\'':
            set_err_char(dbh, imp_xxh, "1", 1, "preparse found unterminated single-quoted string", 0, "preparse");
            break;
    case '\"':
            set_err_char(dbh, imp_xxh, "1", 1, "preparse found unterminated double-quoted string", 0, "preparse");
            break;
    }
    switch (in_comment)
    {
    case DBIpp_L_BRACE:
            set_err_char(dbh, imp_xxh, "1", 1, "preparse found unterminated bracketed {...} comment", 0, "preparse");
            break;
    case '/':
            set_err_char(dbh, imp_xxh, "1", 1, "preparse found unterminated bracketed C-style comment", 0, "preparse");
            break;
    }

    SvCUR_set(new_stmt_sv, strlen(SvPVX(new_stmt_sv)));
    *SvEND(new_stmt_sv) = '\0';
    return new_stmt_sv;
}


/* -------------------------------------------------------------------- */
/* The DBI Perl interface (via XS) starts here. Currently these are     */
/* all internal support functions. Note install_method and see DBI.pm   */

MODULE = DBI   PACKAGE = DBI

REQUIRE:    1.929
PROTOTYPES: DISABLE


BOOT:
    {
        MY_CXT_INIT;
        PERL_UNUSED_VAR(MY_CXT);
    }
    PERL_UNUSED_VAR(cv);
    PERL_UNUSED_VAR(items);
    dbi_bootinit(NULL);
    /* make this sub into a fake XS so it can bee seen by DBD::* modules;
     * never actually call it as an XS sub, or it will crash and burn! */
    (void) newXS("DBI::_dbi_state_lval", (XSUBADDR_t)(void (*) (void))_dbi_state_lval, __FILE__);


I32
constant()
        PROTOTYPE:
    ALIAS:
        SQL_ALL_TYPES                    = SQL_ALL_TYPES
        SQL_ARRAY                        = SQL_ARRAY
        SQL_ARRAY_LOCATOR                = SQL_ARRAY_LOCATOR
        SQL_BIGINT                       = SQL_BIGINT
        SQL_BINARY                       = SQL_BINARY
        SQL_BIT                          = SQL_BIT
        SQL_BLOB                         = SQL_BLOB
        SQL_BLOB_LOCATOR                 = SQL_BLOB_LOCATOR
        SQL_BOOLEAN                      = SQL_BOOLEAN
        SQL_CHAR                         = SQL_CHAR
        SQL_CLOB                         = SQL_CLOB
        SQL_CLOB_LOCATOR                 = SQL_CLOB_LOCATOR
        SQL_DATE                         = SQL_DATE
        SQL_DATETIME                     = SQL_DATETIME
        SQL_DECIMAL                      = SQL_DECIMAL
        SQL_DOUBLE                       = SQL_DOUBLE
        SQL_FLOAT                        = SQL_FLOAT
        SQL_GUID                         = SQL_GUID
        SQL_INTEGER                      = SQL_INTEGER
        SQL_INTERVAL                     = SQL_INTERVAL
        SQL_INTERVAL_DAY                 = SQL_INTERVAL_DAY
        SQL_INTERVAL_DAY_TO_HOUR         = SQL_INTERVAL_DAY_TO_HOUR
        SQL_INTERVAL_DAY_TO_MINUTE       = SQL_INTERVAL_DAY_TO_MINUTE
        SQL_INTERVAL_DAY_TO_SECOND       = SQL_INTERVAL_DAY_TO_SECOND
        SQL_INTERVAL_HOUR                = SQL_INTERVAL_HOUR
        SQL_INTERVAL_HOUR_TO_MINUTE      = SQL_INTERVAL_HOUR_TO_MINUTE
        SQL_INTERVAL_HOUR_TO_SECOND      = SQL_INTERVAL_HOUR_TO_SECOND
        SQL_INTERVAL_MINUTE              = SQL_INTERVAL_MINUTE
        SQL_INTERVAL_MINUTE_TO_SECOND    = SQL_INTERVAL_MINUTE_TO_SECOND
        SQL_INTERVAL_MONTH               = SQL_INTERVAL_MONTH
        SQL_INTERVAL_SECOND              = SQL_INTERVAL_SECOND
        SQL_INTERVAL_YEAR                = SQL_INTERVAL_YEAR
        SQL_INTERVAL_YEAR_TO_MONTH       = SQL_INTERVAL_YEAR_TO_MONTH
        SQL_LONGVARBINARY                = SQL_LONGVARBINARY
        SQL_LONGVARCHAR                  = SQL_LONGVARCHAR
        SQL_MULTISET                     = SQL_MULTISET
        SQL_MULTISET_LOCATOR             = SQL_MULTISET_LOCATOR
        SQL_NUMERIC                      = SQL_NUMERIC
        SQL_REAL                         = SQL_REAL
        SQL_REF                          = SQL_REF
        SQL_ROW                          = SQL_ROW
        SQL_SMALLINT                     = SQL_SMALLINT
        SQL_TIME                         = SQL_TIME
        SQL_TIMESTAMP                    = SQL_TIMESTAMP
        SQL_TINYINT                      = SQL_TINYINT
        SQL_TYPE_DATE                    = SQL_TYPE_DATE
        SQL_TYPE_TIME                    = SQL_TYPE_TIME
        SQL_TYPE_TIMESTAMP               = SQL_TYPE_TIMESTAMP
        SQL_TYPE_TIMESTAMP_WITH_TIMEZONE = SQL_TYPE_TIMESTAMP_WITH_TIMEZONE
        SQL_TYPE_TIME_WITH_TIMEZONE      = SQL_TYPE_TIME_WITH_TIMEZONE
        SQL_UDT                          = SQL_UDT
        SQL_UDT_LOCATOR                  = SQL_UDT_LOCATOR
        SQL_UNKNOWN_TYPE                 = SQL_UNKNOWN_TYPE
        SQL_VARBINARY                    = SQL_VARBINARY
        SQL_VARCHAR                      = SQL_VARCHAR
        SQL_WCHAR                        = SQL_WCHAR
        SQL_WLONGVARCHAR                 = SQL_WLONGVARCHAR
        SQL_WVARCHAR                     = SQL_WVARCHAR
        SQL_CURSOR_FORWARD_ONLY          = SQL_CURSOR_FORWARD_ONLY
        SQL_CURSOR_KEYSET_DRIVEN         = SQL_CURSOR_KEYSET_DRIVEN
        SQL_CURSOR_DYNAMIC               = SQL_CURSOR_DYNAMIC
        SQL_CURSOR_STATIC                = SQL_CURSOR_STATIC
        SQL_CURSOR_TYPE_DEFAULT          = SQL_CURSOR_TYPE_DEFAULT
        DBIpp_cm_cs     = DBIpp_cm_cs
        DBIpp_cm_hs     = DBIpp_cm_hs
        DBIpp_cm_dd     = DBIpp_cm_dd
        DBIpp_cm_dw     = DBIpp_cm_dw
        DBIpp_cm_br     = DBIpp_cm_br
        DBIpp_cm_XX     = DBIpp_cm_XX
        DBIpp_ph_qm     = DBIpp_ph_qm
        DBIpp_ph_cn     = DBIpp_ph_cn
        DBIpp_ph_cs     = DBIpp_ph_cs
        DBIpp_ph_sp     = DBIpp_ph_sp
        DBIpp_ph_XX     = DBIpp_ph_XX
        DBIpp_st_qq     = DBIpp_st_qq
        DBIpp_st_bs     = DBIpp_st_bs
        DBIpp_st_XX     = DBIpp_st_XX
        DBIstcf_DISCARD_STRING  = DBIstcf_DISCARD_STRING
        DBIstcf_STRICT          = DBIstcf_STRICT
        DBIf_TRACE_SQL  = DBIf_TRACE_SQL
        DBIf_TRACE_CON  = DBIf_TRACE_CON
        DBIf_TRACE_ENC  = DBIf_TRACE_ENC
        DBIf_TRACE_DBD  = DBIf_TRACE_DBD
        DBIf_TRACE_TXN  = DBIf_TRACE_TXN
    CODE:
    RETVAL = ix;
    OUTPUT:
    RETVAL


void
_clone_dbis()
    CODE:
    dMY_CXT;
    dbistate_t * parent_dbis = DBIS;

    (void)cv;
    {
        MY_CXT_CLONE;
    }
    dbi_bootinit(parent_dbis);


void
_new_handle(class, parent, attr_ref, imp_datasv, imp_class)
    SV *        class
    SV *        parent
    SV *        attr_ref
    SV *        imp_datasv
    SV *        imp_class
    PPCODE:
    dMY_CXT;
    HV *outer;
    SV *outer_ref;
    HV *class_stash = gv_stashsv(class, GV_ADDWARN);

    if (DBIS_TRACE_LEVEL >= 5) {
        PerlIO_printf(DBILOGFP, "    New %s (for %s, parent=%s, id=%s)\n",
            neatsvpv(class,0), SvPV_nolen(imp_class), neatsvpv(parent,0), neatsvpv(imp_datasv,0));
        PERL_UNUSED_VAR(cv);
    }

    (void)hv_stores((HV*)SvRV(attr_ref), "ImplementorClass", SvREFCNT_inc(imp_class));

    /* make attr into inner handle by blessing it into class */
    sv_bless(attr_ref, class_stash);
    /* tie new outer hash to inner handle */
    outer = newHV(); /* create new hash to be outer handle */
    outer_ref = newRV_noinc((SV*)outer);
    /* make outer hash into a handle by blessing it into class */
    sv_bless(outer_ref, class_stash);
    /* tie outer handle to inner handle */
    sv_magic((SV*)outer, attr_ref, PERL_MAGIC_tied, Nullch, 0);

    dbih_setup_handle(aTHX_ outer_ref, SvPV_nolen(imp_class), parent, SvOK(imp_datasv) ? imp_datasv : Nullsv);

    /* return outer handle, plus inner handle if not in scalar context */
    sv_2mortal(outer_ref);
    EXTEND(SP, 2);
    PUSHs(outer_ref);
    if (GIMME_V != G_SCALAR) {
        PUSHs(attr_ref);
    }


void
_setup_handle(sv, imp_class, parent, imp_datasv)
    SV *        sv
    char *      imp_class
    SV *        parent
    SV *        imp_datasv
    CODE:
    (void)cv;
    dbih_setup_handle(aTHX_ sv, imp_class, parent, SvOK(imp_datasv) ? imp_datasv : Nullsv);
    ST(0) = &PL_sv_undef;


void
_get_imp_data(sv)
    SV *        sv
    CODE:
    D_imp_xxh(sv);
    (void)cv;
    ST(0) = sv_mortalcopy(DBIc_IMP_DATA(imp_xxh)); /* okay if NULL      */


void
_handles(sv)
    SV *        sv
    PPCODE:
    /* return the outer and inner handle for any given handle */
    D_imp_xxh(sv);
    SV *ih = sv_mortalcopy( dbih_inner(aTHX_ sv, "_handles") );
    SV *oh = sv_2mortal(newRV_inc((SV*)DBIc_MY_H(imp_xxh))); /* XXX dangerous */
    (void)cv;
    EXTEND(SP, 2);
    PUSHs(oh);  /* returns outer handle then inner */
    if (GIMME_V != G_SCALAR) {
        PUSHs(ih);
    }


void
neat(sv, maxlen=0)
    SV *        sv
    U32 maxlen
    CODE:
    ST(0) = sv_2mortal(newSVpv(neatsvpv(sv, maxlen), 0));
    (void)cv;


I32
hash(key, type=0)
    const char *key
    long type
    CODE:
    (void)cv;
    RETVAL = dbi_hash(key, type);
    OUTPUT:
    RETVAL

void
looks_like_number(...)
    PPCODE:
    int i;
    EXTEND(SP, items);
    (void)cv;
    for(i=0; i < items ; ++i) {
        SV *sv = ST(i);
        if (!SvOK(sv) || (SvPOK(sv) && SvCUR(sv)==0))
            PUSHs(&PL_sv_undef);
        else if ( looks_like_number(sv) )
            PUSHs(&PL_sv_yes);
        else
            PUSHs(&PL_sv_no);
    }


void
_install_method(dbi_class, meth_name, file, attribs=Nullsv)
    const char *        dbi_class
    char *      meth_name
    char *      file
    SV *        attribs
    CODE:
    {
    dMY_CXT;
    /* install another method name/interface for the DBI dispatcher     */
    SV *trace_msg = (DBIS_TRACE_LEVEL >= 10) ? sv_2mortal(newSVpvs("")) : Nullsv;
    CV *cv;
    SV **svp;
    dbi_ima_t *ima;
    MAGIC *mg;
    (void)dbi_class;

    if (strnNE(meth_name, "DBI::", 5))  /* XXX m/^DBI::\w+::\w+$/       */
        croak("install_method %s: invalid class", meth_name);

    if (trace_msg)
        sv_catpvf(trace_msg, "install_method %-21s", meth_name);

    Newxz(ima, 1, dbi_ima_t);

    if (attribs && SvOK(attribs)) {
        /* convert and store method attributes in a fast access form    */
        if (SvTYPE(SvRV(attribs)) != SVt_PVHV)
            croak("install_method %s: bad attribs", meth_name);

        DBD_ATTRIB_GET_IV(attribs, "O",1, svp, ima->flags);
        DBD_ATTRIB_GET_UV(attribs, "T",1, svp, ima->method_trace);
        DBD_ATTRIB_GET_IV(attribs, "H",1, svp, ima->hidearg);

        if (trace_msg) {
            if (ima->flags)       sv_catpvf(trace_msg, ", flags 0x%04x", (unsigned)ima->flags);
            if (ima->method_trace)sv_catpvf(trace_msg, ", T 0x%08lx", (unsigned long)ima->method_trace);
            if (ima->hidearg)     sv_catpvf(trace_msg, ", H %u", (unsigned)ima->hidearg);
        }
        if ( (svp=DBD_ATTRIB_GET_SVP(attribs, "U",1)) != NULL) {
            AV *av = (AV*)SvRV(*svp);
            ima->minargs = (U8)SvIV(*av_fetch(av, 0, 1));
            ima->maxargs = (U8)SvIV(*av_fetch(av, 1, 1));
            svp = av_fetch(av, 2, 0);
            ima->usage_msg = (svp) ? savepv_using_sv(SvPV_nolen(*svp)) : "";
            ima->flags |= IMA_HAS_USAGE;
            if (trace_msg && DBIS_TRACE_LEVEL >= 11)
                sv_catpvf(trace_msg, ",\n    usage: min %d, max %d, '%s'",
                        ima->minargs, ima->maxargs, ima->usage_msg);
        }
    }
    if (trace_msg)
        PerlIO_printf(DBILOGFP,"%s\n", SvPV_nolen(trace_msg));
    file = savepv(file);
    cv = newXS(meth_name, XS_DBI_dispatch, file);
    SvPVX((SV *)cv) = file;
    SvLEN((SV *)cv) = 1;
    CvXSUBANY(cv).any_ptr = ima;
    ima->meth_type = get_meth_type(GvNAME(CvGV(cv)));

    /* Attach magic to handle duping and freeing of the dbi_ima_t struct.
     * Due to the poor interface of the mg dup function, sneak a pointer
     * to the original CV in the mg_ptr field (we get called with a
     * pointer to the mg, but not the SV) */
    mg = sv_magicext((SV*)cv, NULL, DBI_MAGIC, &dbi_ima_vtbl,
                        (char *)cv, 0);
#ifdef BROKEN_DUP_ANY_PTR
    ima->my_perl = my_perl; /* who owns this struct */
#else
    mg->mg_flags |= MGf_DUP;
#endif
    ST(0) = &PL_sv_yes;
    }


int
trace(class, level_sv=&PL_sv_undef, file=Nullsv)
    SV *        class
    SV *        level_sv
    SV *        file
    ALIAS:
    _debug_dispatch = 1
    CODE:
    {
    dMY_CXT;
    IV level;
    if (!DBIS) {
        PERL_UNUSED_VAR(ix);
        croak("DBI not initialised");
    }
    /* Return old/current value. No change if new value not given.      */
    RETVAL = (DBIS) ? DBIS->debug : 0;
    level = parse_trace_flags(class, level_sv, RETVAL);
    if (level)          /* call before or after altering DBI trace level */
        set_trace_file(file);
    if (level != RETVAL) {
        if ((level & DBIc_TRACE_LEVEL_MASK) > 0) {
            PerlIO_printf(DBILOGFP,"    DBI %s%s default trace level set to 0x%lx/%ld (pid %d pi %p) at %s\n",
                XS_VERSION, dbi_build_opt,
                (long)(level & DBIc_TRACE_FLAGS_MASK),
                (long)(level & DBIc_TRACE_LEVEL_MASK),
                (int)PerlProc_getpid(),
#ifdef MULTIPLICITY
                (void *)my_perl,
#else
                (void*)NULL,
#endif
                log_where(Nullsv, 0, "", "", 1, 1, 0)
            );
            if (!PL_dowarn)
                PerlIO_printf(DBILOGFP,"    Note: perl is running without the recommended perl -w option\n");
            PerlIO_flush(DBILOGFP);
        }
        DBIS->debug = level;
        sv_setiv(get_sv("DBI::dbi_debug",0x5), level);
    }
    if (!level)         /* call before or after altering DBI trace level */
        set_trace_file(file);
    }
    OUTPUT:
    RETVAL



void
dump_handle(sv, msg="DBI::dump_handle", level=0)
    SV *        sv
    const char *msg
    int         level
    CODE:
    (void)cv;
    dbih_dumphandle(aTHX_ sv, msg, level);



void
_svdump(sv)
    SV *        sv
    CODE:
    {
    dMY_CXT;
    (void)cv;
    PerlIO_printf(DBILOGFP, "DBI::_svdump(%s)", neatsvpv(sv,0));
#ifdef DEBUGGING
    sv_dump(sv);
#endif
    }


NV
dbi_time()


void
dbi_profile(h, statement, method, t1, t2)
    SV *h
    SV *statement
    SV *method
    NV t1
    NV t2
    CODE:
    SV *leaf = &PL_sv_undef;
    PERL_UNUSED_VAR(cv);
    if (SvROK(method))
        method = SvRV(method);
    if (dbih_inner(aTHX_ h, NULL)) {    /* is a DBI handle */
        D_imp_xxh(h);
        leaf = dbi_profile(h, imp_xxh, statement, method, t1, t2);
    }
    else if (SvROK(h) && SvTYPE(SvRV(h)) == SVt_PVHV) {
        /* iterate over values %$h */
        HV *hv = (HV*)SvRV(h);
        SV *tmp;
        char *key;
        I32 keylen = 0;
        hv_iterinit(hv);
        while ( (tmp = hv_iternextsv(hv, &key, &keylen)) != NULL ) {
            if (SvOK(tmp)) {
                D_imp_xxh(tmp);
                leaf = dbi_profile(tmp, imp_xxh, statement, method, t1, t2);
            }
        };
    }
    else {
        croak("dbi_profile(%s,...) invalid handle argument", neatsvpv(h,0));
    }
    if (GIMME_V == G_VOID)
        ST(0) = &PL_sv_undef;  /* skip sv_mortalcopy if not needed */
    else
        ST(0) = sv_mortalcopy(leaf);



SV *
dbi_profile_merge_nodes(dest, ...)
    SV * dest
    ALIAS:
    dbi_profile_merge = 1
    CODE:
    {
        if (!SvROK(dest) || SvTYPE(SvRV(dest)) != SVt_PVAV)
            croak("dbi_profile_merge_nodes(%s,...) destination is not an array reference", neatsvpv(dest,0));
        if (items <= 1) {
            PERL_UNUSED_VAR(cv);
            PERL_UNUSED_VAR(ix);
            RETVAL = 0;
        }
        else {
            /* items==2 for dest + 1 arg, ST(0) is dest, ST(1) is first arg */
            while (--items >= 1) {
                SV *thingy = ST(items);
                dbi_profile_merge_nodes(dest, thingy);
            }
            RETVAL = newSVsv(*av_fetch((AV*)SvRV(dest), DBIprof_TOTAL_TIME, 1));
        }
    }
    OUTPUT:
    RETVAL


SV *
_concat_hash_sorted(hash_sv, kv_sep_sv, pair_sep_sv, use_neat_sv, num_sort_sv)
    SV *hash_sv
    SV *kv_sep_sv
    SV *pair_sep_sv
    SV *use_neat_sv
    SV *num_sort_sv
    PREINIT:
    char *kv_sep, *pair_sep;
    STRLEN kv_sep_len, pair_sep_len;
    CODE:
        if (!SvOK(hash_sv))
            XSRETURN_UNDEF;
        if (!SvROK(hash_sv) || SvTYPE(SvRV(hash_sv))!=SVt_PVHV)
            croak("hash is not a hash reference");

        kv_sep   = SvPV(kv_sep_sv,   kv_sep_len);
        pair_sep = SvPV(pair_sep_sv, pair_sep_len);

        RETVAL = _join_hash_sorted( (HV*)SvRV(hash_sv),
            kv_sep,   kv_sep_len,
            pair_sep, pair_sep_len,
            /* use_neat should be undef, 0 or 1, may allow sprintf format strings later */
            (SvOK(use_neat_sv)) ? SvIV(use_neat_sv) :  0,
            (SvOK(num_sort_sv)) ? SvIV(num_sort_sv) : -1
        );
    OUTPUT:
        RETVAL


int
sql_type_cast(sv, sql_type, flags=0)
    SV *        sv
    int         sql_type
    U32         flags
    CODE:
    RETVAL = sql_type_cast_svpv(aTHX_ sv, sql_type, flags, 0);
    OUTPUT:
        RETVAL



MODULE = DBI   PACKAGE = DBI::var

void
FETCH(sv)
    SV *        sv
    CODE:
    dMY_CXT;
    /* Note that we do not come through the dispatcher to get here.     */
    char *meth = SvPV_nolen(SvRV(sv));  /* what should this tie do ?    */
    char type = *meth++;                /* is this a $ or & style       */
    imp_xxh_t *imp_xxh = (DBI_LAST_HANDLE_OK) ? DBIh_COM(DBI_LAST_HANDLE) : NULL;
    int trace_level = (imp_xxh ? DBIc_TRACE_LEVEL(imp_xxh) : DBIS_TRACE_LEVEL);
    NV profile_t1 = 0.0;

    if (imp_xxh && DBIc_has(imp_xxh,DBIcf_Profile))
        profile_t1 = dbi_time();

    if (trace_level >= 2) {
        PerlIO_printf(DBILOGFP,"    -> $DBI::%s (%c) FETCH from lasth=%s\n", meth, type,
                (imp_xxh) ? neatsvpv(DBI_LAST_HANDLE,0): "none");
    }

    if (type == '!') {  /* special case for $DBI::lasth */
        /* Currently we can only return the INNER handle.       */
        /* This handle should only be used for true/false tests */
        ST(0) = (imp_xxh) ? sv_2mortal(newRV_inc(DBI_LAST_HANDLE)) : &PL_sv_undef;
    }
    else if ( !imp_xxh ) {
        if (trace_level)
            warn("Can't read $DBI::%s, last handle unknown or destroyed", meth);
        ST(0) = &PL_sv_undef;
    }
    else if (type == '*') {     /* special case for $DBI::err, see also err method      */
        SV *errsv = DBIc_ERR(imp_xxh);
        ST(0) = sv_mortalcopy(errsv);
    }
    else if (type == '"') {     /* special case for $DBI::state */
        SV *state = DBIc_STATE(imp_xxh);
        ST(0) = DBIc_STATE_adjust(imp_xxh, state);
    }
    else if (type == '$') { /* lookup scalar variable in implementors stash */
        const char *vname = mkvname(aTHX_ DBIc_IMP_STASH(imp_xxh), meth, 0);
        SV *vsv = get_sv(vname, 1);
        ST(0) = sv_mortalcopy(vsv);
    }
    else {
        /* default to method call via stash of implementor of DBI_LAST_HANDLE */
        GV *imp_gv;
        HV *imp_stash = DBIc_IMP_STASH(imp_xxh);
#ifdef DBI_save_hv_fetch_ent
        HE save_mh = PL_hv_fetch_ent_mh; /* XXX nested tied FETCH bug17575 workaround */
#endif
        profile_t1 = 0.0; /* profile this via dispatch only (else we'll double count) */
        if (trace_level >= 3)
            PerlIO_printf(DBILOGFP,"    >> %s::%s\n", HvNAME(imp_stash), meth);
        ST(0) = sv_2mortal(newRV_inc(DBI_LAST_HANDLE));
        if ((imp_gv = gv_fetchmethod(imp_stash,meth)) == NULL) {
            croak("Can't locate $DBI::%s object method \"%s\" via package \"%s\"",
                meth, meth, HvNAME(imp_stash));
        }
        PUSHMARK(mark);  /* reset mark (implies one arg as we were called with one arg?) */
        call_sv((SV*)GvCV(imp_gv), GIMME_V);
        SPAGAIN;
#ifdef DBI_save_hv_fetch_ent
        PL_hv_fetch_ent_mh = save_mh;
#endif
    }
    if (trace_level)
        PerlIO_printf(DBILOGFP,"    <- $DBI::%s= %s\n", meth, neatsvpv(ST(0),0));
    if (profile_t1) {
        SV *h = sv_2mortal(newRV_inc(DBI_LAST_HANDLE));
        dbi_profile(h, imp_xxh, &PL_sv_undef, (SV*)cv, profile_t1, dbi_time());
    }


MODULE = DBI   PACKAGE = DBD::_::dr

void
dbixs_revision(h)
    SV *    h
    CODE:
    PERL_UNUSED_VAR(h);
    ST(0) = sv_2mortal(newSViv(DBIXS_REVISION));


MODULE = DBI   PACKAGE = DBD::_::db

void
connected(...)
    CODE:
    /* defined here just to avoid AUTOLOAD */
    (void)cv;
    (void)items;
    ST(0) = &PL_sv_undef;


SV *
preparse(dbh, statement, ps_return, ps_accept, foo=Nullch)
    SV *        dbh
    char *      statement
    IV          ps_return
    IV          ps_accept
    void        *foo


void
take_imp_data(h)
    SV *        h
    PREINIT:
    /* take_imp_data currently in DBD::_::db not DBD::_::common, so for dbh's only */
    D_imp_xxh(h);
    MAGIC *mg;
    SV *imp_xxh_sv;
    SV **tmp_svp;
    CODE:
    PERL_UNUSED_VAR(cv);
    /*
     * Remove and return the imp_xxh_t structure that's attached to the inner
     * hash of the handle. Effectively this removes the 'brain' of the handle
     * leaving it as an empty shell - brain dead. All method calls on it fail.
     *
     * The imp_xxh_t structure that's removed and returned is a plain scalar
     * (containing binary data). It can be passed to a new DBI->connect call
     * in order to have the new $dbh use the same 'connection' as the original
     * handle. In this way a multi-threaded connection pool can be implemented.
     *
     * If the drivers imp_xxh_t structure contains SV*'s, or other interpreter
     * specific items, they should be freed by the drivers own take_imp_data()
     * method before it then calls SUPER::take_imp_data() to finalize removal
     * of the imp_xxh_t structure.
     *
     * The driver needs to view the take_imp_data method as being nearly the
     * same as disconnect+DESTROY only not actually calling the database API to
     * disconnect.  All that needs to remain valid in the imp_xxh_t structure
     * is the underlying database API connection data.  Everything else should
     * in a 'clean' state such that if the drivers own DESTROY method was
     * called it would be able to properly handle the contents of the
     * structure. This is important in case a new handle created using this
     * imp_data, possibly in a new thread, might end up being DESTROY'd before
     * the driver has had a chance to 're-setup' the data. See dbih_setup_handle()
     *
     * All the above relates to the 'typical use case' for a compiled driver.
     * For a pure-perl driver using a socket pair, for example, the drivers
     * take_imp_data method might just return a string containing the fileno()
     * values of the sockets (without calling this SUPER::take_imp_data() code).
     * The key point is that the take_imp_data() method returns an opaque buffer
     * containing whatever the driver would need to reuse the same underlying
     * 'connection to the database' in a new handle.
     *
     * In all cases, care should be taken that driver attributes (such as
     * AutoCommit) match the state of the underlying connection.
     */

    if (!DBIc_ACTIVE(imp_xxh)) {/* sanity check, may be relaxed later */
        set_err_char(h, imp_xxh, "1", 1, "Can't take_imp_data from handle that's not Active", 0, "take_imp_data");
        XSRETURN(0);
    }

    /* Ideally there should be no child statement handles existing when
     * take_imp_data is called because when those statement handles are
     * destroyed they may need to interact with the 'zombie' parent dbh.
     * So we do our best to neautralize them (finish & rebless)
     */
    if ((tmp_svp = hv_fetchs((HV*)SvRV(h), "ChildHandles", FALSE)) && SvROK(*tmp_svp)) {
        AV *av = (AV*)SvRV(*tmp_svp);
        HV *zombie_stash = gv_stashpv("DBI::zombie", GV_ADDWARN);
        I32 kidslots;
        for (kidslots = AvFILL(av); kidslots >= 0; --kidslots) {
            SV **hp = av_fetch(av, kidslots, FALSE);
            if (hp && SvROK(*hp) && SvMAGICAL(SvRV(*hp))) {
                PUSHMARK(sp);
                XPUSHs(*hp);
                PUTBACK;
                call_method("finish", G_VOID);
                SPAGAIN;
                PUTBACK;
                sv_unmagic(SvRV(*hp), 'P'); /* untie */
                sv_bless(*hp, zombie_stash); /* neutralise */
            }
        }
    }
    /* The above measures may not be sufficient if weakrefs aren't available
     * or something has a reference to the inner-handle of an sth.
     * We'll require no Active kids, but just warn about others.
     */
    if (DBIc_ACTIVE_KIDS(imp_xxh)) {
        set_err_char(h, imp_xxh, "1", 1, "Can't take_imp_data from handle while it still has Active kids", 0, "take_imp_data");
        XSRETURN(0);
    }
    if (DBIc_KIDS(imp_xxh))
        warn("take_imp_data from handle while it still has kids");

    /* it may be better here to return a copy and poison the original
     * rather than detatching and returning the original
     */

    /* --- perform the surgery */
    dbih_getcom2(aTHX_ h, &mg); /* get the MAGIC so we can change it    */
    imp_xxh_sv = mg->mg_obj;    /* take local copy of the imp_data pointer */
    mg->mg_obj = Nullsv;        /* sever the link from handle to imp_xxh */
    mg->mg_ptr = NULL;          /* and sever the shortcut too */
    if (DBIc_TRACE_LEVEL(imp_xxh) >= 9)
        sv_dump(imp_xxh_sv);
    /* --- housekeeping */
    DBIc_ACTIVE_off(imp_xxh);   /* silence warning from dbih_clearcom */
    DBIc_IMPSET_off(imp_xxh);   /* silence warning from dbih_clearcom */
    dbih_clearcom(imp_xxh);     /* free SVs like DBD::_mem::common::DESTROY */
    SvOBJECT_off(imp_xxh_sv);   /* no longer needs DESTROY via dbih_clearcom */
    /* restore flags to mark fact imp data holds active connection      */
    /* (don't use magical DBIc_ACTIVE_on here)                          */
    DBIc_FLAGS(imp_xxh) |=  DBIcf_IMPSET | DBIcf_ACTIVE;
    /* --- tidy up the raw PV for life as a more normal string */
    SvPOK_on(imp_xxh_sv);       /* SvCUR & SvEND were set at creation   */
    /* --- return the actual imp_xxh_sv on the stack */
    ST(0) = imp_xxh_sv;



MODULE = DBI   PACKAGE = DBD::_::st

void
_get_fbav(sth)
    SV *        sth
    CODE:
    D_imp_sth(sth);
    AV *av = dbih_get_fbav(imp_sth);
    (void)cv;
    ST(0) = sv_2mortal(newRV_inc((SV*)av));

void
_set_fbav(sth, src_rv)
    SV *        sth
    SV *        src_rv
    CODE:
    D_imp_sth(sth);
    int i;
    AV *src_av;
    AV *dst_av = dbih_get_fbav(imp_sth);
    int dst_fields = AvFILL(dst_av)+1;
    int src_fields;
    (void)cv;

    if (!SvROK(src_rv) || SvTYPE(SvRV(src_rv)) != SVt_PVAV)
        croak("_set_fbav(%s): not an array ref", neatsvpv(src_rv,0));
    src_av = (AV*)SvRV(src_rv);
    src_fields = AvFILL(src_av)+1;
    if (src_fields != dst_fields) {
        warn("_set_fbav(%s): array has %d elements, the statement handle row buffer has %d (and NUM_OF_FIELDS is %d)",
                neatsvpv(src_rv,0), src_fields, dst_fields, DBIc_NUM_FIELDS(imp_sth));
        SvREADONLY_off(dst_av);
        if (src_fields < dst_fields) {
            /* shrink the array - sadly this looses column bindings for the lost columns */
            av_fill(dst_av, src_fields-1);
            dst_fields = src_fields;
        }
        else {
            av_fill(dst_av, src_fields-1);
            /* av_fill pads with immutable undefs which we need to change */
            for(i=dst_fields-1; i < src_fields; ++i) {
                sv_setsv(AvARRAY(dst_av)[i], newSV(0));
            }
        }
        SvREADONLY_on(dst_av);
    }
    for(i=0; i < dst_fields; ++i) {     /* copy over the row    */
        /* If we're given the values, then taint them if required */
        if (DBIc_is(imp_sth, DBIcf_TaintOut))
            SvTAINT(AvARRAY(src_av)[i]);
        sv_setsv(AvARRAY(dst_av)[i], AvARRAY(src_av)[i]);
    }
    ST(0) = sv_2mortal(newRV_inc((SV*)dst_av));


void
bind_col(sth, col, ref, attribs=Nullsv)
    SV *        sth
    SV *        col
    SV *        ref
    SV *        attribs
    PREINIT:
    SV *ret;
    CODE:
    DBD_ATTRIBS_CHECK("bind_col", sth, attribs);
    ret = boolSV(dbih_sth_bind_col(sth, col, ref, attribs));
    ST(0) = ret;
    (void)cv;


void
fetchrow_array(sth)
    SV *        sth
    ALIAS:
    fetchrow = 1
    PPCODE:
    SV *retsv;
    if (CvDEPTH(cv) == 99) {
        PERL_UNUSED_VAR(ix);
        croak("Deep recursion, probably fetchrow-fetch-fetchrow loop");
    }
    PUSHMARK(sp);
    XPUSHs(sth);
    PUTBACK;
    if (call_method("fetch", G_SCALAR) != 1)
        croak("panic: DBI fetch");      /* should never happen */
    SPAGAIN;
    retsv = POPs;
    PUTBACK;
    if (SvROK(retsv) && SvTYPE(SvRV(retsv)) == SVt_PVAV) {
        D_imp_sth(sth);
        int num_fields, i;
        AV *bound_av;
        AV *av = (AV*)SvRV(retsv);
        num_fields = AvFILL(av)+1;
        EXTEND(sp, num_fields+1);

        /* We now check for bind_col() having been called but fetch     */
        /* not returning the fields_svav array. Probably because the    */
        /* driver is implemented in perl. XXX This logic may change later.      */
        bound_av = DBIc_FIELDS_AV(imp_sth); /* bind_col() called ?      */
        if (bound_av && av != bound_av) {
            /* let dbih_get_fbav know what's going on   */
            bound_av = dbih_get_fbav(imp_sth);
            if (DBIc_TRACE_LEVEL(imp_sth) >= 3) {
                PerlIO_printf(DBIc_LOGPIO(imp_sth),
                    "fetchrow: updating fbav 0x%lx from 0x%lx\n",
                    (long)bound_av, (long)av);
            }
            for(i=0; i < num_fields; ++i) {     /* copy over the row    */
                sv_setsv(AvARRAY(bound_av)[i], AvARRAY(av)[i]);
            }
        }
        for(i=0; i < num_fields; ++i) {
            PUSHs(AvARRAY(av)[i]);
        }
    }


SV *
fetchrow_hashref(sth, keyattrib=Nullch)
    SV *        sth
    const char *keyattrib
    PREINIT:
    SV *rowavr;
    SV *ka_rv;
    D_imp_sth(sth);
    CODE:
    (void)cv;
    PUSHMARK(sp);
    XPUSHs(sth);
    PUTBACK;
    if (!keyattrib || !*keyattrib) {
        SV *kn = DBIc_FetchHashKeyName(imp_sth);
        if (kn && SvOK(kn))
            keyattrib = SvPVX(kn);
        else
            keyattrib = "NAME";
    }
    ka_rv = *hv_fetch((HV*)DBIc_MY_H(imp_sth), keyattrib,strlen(keyattrib), TRUE);
    /* we copy to invoke FETCH magic, and we do that before fetch() so if tainting */
    /* then the taint triggered by the fetch won't then apply to the fetched name */
    ka_rv = newSVsv(ka_rv);
    if (call_method("fetch", G_SCALAR) != 1)
        croak("panic: DBI fetch");      /* should never happen */
    SPAGAIN;
    rowavr = POPs;
    PUTBACK;
    /* have we got an array ref in rowavr */
    if (SvROK(rowavr) && SvTYPE(SvRV(rowavr)) == SVt_PVAV) {
        int i;
        AV *rowav = (AV*)SvRV(rowavr);
        const int num_fields = AvFILL(rowav)+1;
        HV *hv;
        AV *ka_av;
        if (!(SvROK(ka_rv) && SvTYPE(SvRV(ka_rv))==SVt_PVAV)) {
            sv_setiv(DBIc_ERR(imp_sth), 1);
            sv_setpvf(DBIc_ERRSTR(imp_sth),
                "Can't use attribute '%s' because it doesn't contain a reference to an array (%s)",
                keyattrib, neatsvpv(ka_rv,0));
            XSRETURN_UNDEF;
        }
        ka_av = (AV*)SvRV(ka_rv);
        hv    = newHV();
        for (i=0; i < num_fields; ++i) {        /* honor the original order as sent by the database */
            SV  **field_name_svp = av_fetch(ka_av, i, 1);
            (void)hv_store_ent(hv, *field_name_svp, newSVsv((SV*)(AvARRAY(rowav)[i])), 0);
        }
        RETVAL = newRV_inc((SV*)hv);
        SvREFCNT_dec(hv);       /* since newRV incremented it   */
    }
    else {
        RETVAL = &PL_sv_undef;
    }
    SvREFCNT_dec(ka_rv);        /* since we created it          */
    OUTPUT:
    RETVAL


void
fetch(sth)
    SV *        sth
    ALIAS:
    fetchrow_arrayref = 1
    CODE:
    int num_fields;
    if (CvDEPTH(cv) == 99) {
        PERL_UNUSED_VAR(ix);
        croak("Deep recursion. Probably fetch-fetchrow-fetch loop.");
    }
    PUSHMARK(sp);
    XPUSHs(sth);
    PUTBACK;
    num_fields = call_method("fetchrow", G_LIST);      /* XXX change the name later */
    SPAGAIN;
    if (num_fields == 0) {
        ST(0) = &PL_sv_undef;
    } else {
        D_imp_sth(sth);
        AV *av = dbih_get_fbav(imp_sth);
        if (num_fields != AvFILL(av)+1)
            croak("fetchrow returned %d fields, expected %d",
                    num_fields, (int)AvFILL(av)+1);
        SPAGAIN;
        while(--num_fields >= 0)
            sv_setsv(AvARRAY(av)[num_fields], POPs);
        PUTBACK;
        ST(0) = sv_2mortal(newRV_inc((SV*)av));
    }


void
rows(sth)
    SV *        sth
    CODE:
    D_imp_sth(sth);
    const IV rows = DBIc_ROW_COUNT(imp_sth);
    ST(0) = sv_2mortal(newSViv(rows));
    (void)cv;


void
finish(sth)
    SV *        sth
    CODE:
    D_imp_sth(sth);
    DBIc_ACTIVE_off(imp_sth);
    ST(0) = &PL_sv_yes;
    (void)cv;


void
DESTROY(sth)
    SV *        sth
    PPCODE:
    /* keep in sync with DESTROY in Driver.xst */
    D_imp_sth(sth);
    ST(0) = &PL_sv_yes;
    /* we don't test IMPSET here because this code applies to pure-perl drivers */
    if (DBIc_IADESTROY(imp_sth)) { /* want's ineffective destroy    */
        DBIc_ACTIVE_off(imp_sth);
        if (DBIc_TRACE_LEVEL(imp_sth))
                PerlIO_printf(DBIc_LOGPIO(imp_sth), "         DESTROY %s skipped due to InactiveDestroy\n", SvPV_nolen(sth));
    }
    if (DBIc_ACTIVE(imp_sth)) {
        D_imp_dbh_from_sth;
        if (!PL_dirty && DBIc_ACTIVE(imp_dbh)) {
            dSP;
            PUSHMARK(sp);
            XPUSHs(sth);
            PUTBACK;
            call_method("finish", G_SCALAR);
            SPAGAIN;
            PUTBACK;
        }
        else {
            DBIc_ACTIVE_off(imp_sth);
        }
    }


MODULE = DBI   PACKAGE = DBI::st

void
TIEHASH(class, inner_ref)
    SV * class
    SV * inner_ref
    CODE:
    HV *stash = gv_stashsv(class, GV_ADDWARN); /* a new hash is supplied to us, we just need to bless and apply tie magic */
    sv_bless(inner_ref, stash);
    ST(0) = inner_ref;

MODULE = DBI   PACKAGE = DBD::_::common


void
DESTROY(h)
    SV * h
    CODE:
    /* DESTROY defined here just to avoid AUTOLOAD */
    (void)cv;
    (void)h;
    ST(0) = &PL_sv_undef;


void
STORE(h, keysv, valuesv)
    SV *        h
    SV *        keysv
    SV *        valuesv
    CODE:
    ST(0) = &PL_sv_yes;
    if (!dbih_set_attr_k(h, keysv, 0, valuesv))
            ST(0) = &PL_sv_no;
    (void)cv;


void
FETCH(h, keysv)
    SV *        h
    SV *        keysv
    PREINIT:
    SV *ret;
    CODE:
    ret = dbih_get_attr_k(h, keysv, 0);
    ST(0) = ret;
    (void)cv;

void
DELETE(h, keysv)
    SV *        h
    SV *        keysv
    PREINIT:
    SV *ret;
    CODE:
    /* only private_* keys can be deleted, for others DELETE acts like FETCH */
    /* because the DBI internals rely on certain handle attributes existing  */
    if (strnEQ(SvPV_nolen(keysv),"private_",8))
        ret = hv_delete_ent((HV*)SvRV(h), keysv, 0, 0);
    else
        ret = dbih_get_attr_k(h, keysv, 0);
    ST(0) = ret;
    (void)cv;


void
private_data(h)
    SV *        h
    CODE:
    D_imp_xxh(h);
    (void)cv;
    ST(0) = sv_mortalcopy(DBIc_IMP_DATA(imp_xxh));


void
err(h)
    SV * h
    CODE:
    D_imp_xxh(h);
    SV *errsv = DBIc_ERR(imp_xxh);
    (void)cv;
    ST(0) = sv_mortalcopy(errsv);

void
state(h)
    SV * h
    CODE:
    D_imp_xxh(h);
    SV *state = DBIc_STATE(imp_xxh);
    (void)cv;
    ST(0) = DBIc_STATE_adjust(imp_xxh, state);

void
errstr(h)
    SV *    h
    CODE:
    D_imp_xxh(h);
    SV *errstr = DBIc_ERRSTR(imp_xxh);
    SV *err;
    /* If there's no errstr but there is an err then use err */
    (void)cv;
    if (!SvTRUE(errstr) && (err=DBIc_ERR(imp_xxh)) && SvTRUE(err))
            errstr = err;
    ST(0) = sv_mortalcopy(errstr);


void
set_err(h, err, errstr=&PL_sv_no, state=&PL_sv_undef, method=&PL_sv_undef, result=Nullsv)
    SV *        h
    SV *        err
    SV *        errstr
    SV *        state
    SV *        method
    SV *        result
    PPCODE:
    {
    D_imp_xxh(h);
    SV **sem_svp;
    (void)cv;

    if (DBIc_has(imp_xxh, DBIcf_HandleSetErr) && SvREADONLY(method))
        method = sv_mortalcopy(method); /* HandleSetErr may want to change it */

    if (!set_err_sv(h, imp_xxh, err, errstr, state, method)) {
        /* set_err was canceled by HandleSetErr,                */
        /* don't set "dbi_set_err_method", return an empty list */
    }
    else {
        /* store provided method name so handler code can find it */
        sem_svp = hv_fetchs((HV*)SvRV(h), "dbi_set_err_method", 1);
        if (SvOK(method)) {
            sv_setpv(*sem_svp, SvPV_nolen(method));
        }
        else
            (void)SvOK_off(*sem_svp);
        XPUSHs( result ? result : &PL_sv_undef );
    }
    /* We don't check RaiseError and call die here because that must be */
    /* done by returning through dispatch and letting the DBI handle it */
    }


int
trace(h, level=&PL_sv_undef, file=Nullsv)
    SV *h
    SV *level
    SV *file
    ALIAS:
    debug = 1
    CODE:
    RETVAL = set_trace(h, level, file);
    (void)cv; /* Unused variables */
    (void)ix;
    OUTPUT:
    RETVAL


void
trace_msg(sv, msg, this_trace=1)
    SV *sv
    const char *msg
    int this_trace
    PREINIT:
    int current_trace;
    PerlIO *pio;
    CODE:
    {
    dMY_CXT;
    (void)cv;
    if (SvROK(sv)) {
        D_imp_xxh(sv);
        current_trace = DBIc_TRACE_LEVEL(imp_xxh);
        pio = DBIc_LOGPIO(imp_xxh);
    }
    else {      /* called as a static method */
        current_trace = DBIS_TRACE_FLAGS;
        pio = DBILOGFP;
    }
    if (DBIc_TRACE_MATCHES(this_trace, current_trace)) {
        PerlIO_puts(pio, msg);
        ST(0) = &PL_sv_yes;
    }
    else {
        ST(0) = &PL_sv_no;
    }
    }


void
rows(h)
    SV *        h
    CODE:
    /* fallback esp for $DBI::rows after $drh was last used */
    ST(0) = sv_2mortal(newSViv(-1));
    (void)h;
    (void)cv;


void
swap_inner_handle(rh1, rh2, allow_reparent=0)
    SV *        rh1
    SV *        rh2
    IV  allow_reparent
    CODE:
    {
    D_impdata(imp_xxh1, imp_xxh_t, rh1);
    D_impdata(imp_xxh2, imp_xxh_t, rh2);
    SV *h1i = dbih_inner(aTHX_ rh1, "swap_inner_handle");
    SV *h2i = dbih_inner(aTHX_ rh2, "swap_inner_handle");
    SV *h1  = (rh1 == h1i) ? (SV*)DBIc_MY_H(imp_xxh1) : SvRV(rh1);
    SV *h2  = (rh2 == h2i) ? (SV*)DBIc_MY_H(imp_xxh2) : SvRV(rh2);
    (void)cv;

    if (DBIc_TYPE(imp_xxh1) != DBIc_TYPE(imp_xxh2)) {
        char buf[99];
        sprintf(buf, "Can't swap_inner_handle between %sh and %sh",
            dbih_htype_name(DBIc_TYPE(imp_xxh1)), dbih_htype_name(DBIc_TYPE(imp_xxh2)));
        DBIh_SET_ERR_CHAR(rh1, imp_xxh1, "1", 1, buf, Nullch, Nullch);
        XSRETURN_NO;
    }
    if (!allow_reparent && DBIc_PARENT_COM(imp_xxh1) != DBIc_PARENT_COM(imp_xxh2)) {
        DBIh_SET_ERR_CHAR(rh1, imp_xxh1, "1", 1,
            "Can't swap_inner_handle with handle from different parent",
            Nullch, Nullch);
        XSRETURN_NO;
    }

    (void)SvREFCNT_inc(h1i);
    (void)SvREFCNT_inc(h2i);

    sv_unmagic(h1, 'P');                /* untie(%$h1)          */
    sv_unmagic(h2, 'P');                /* untie(%$h2)          */

    sv_magic(h1, h2i, 'P', Nullch, 0);  /* tie %$h1, $h2i       */
    DBIc_MY_H(imp_xxh2) = (HV*)h1;

    sv_magic(h2, h1i, 'P', Nullch, 0);  /* tie %$h2, $h1i       */
    DBIc_MY_H(imp_xxh1) = (HV*)h2;

    SvREFCNT_dec(h1i);
    SvREFCNT_dec(h2i);

    ST(0) = &PL_sv_yes;
    }


MODULE = DBI   PACKAGE = DBD::_mem::common

void
DESTROY(imp_xxh_rv)
    SV *        imp_xxh_rv
    CODE:
    /* ignore 'cast increases required alignment' warning       */
    imp_xxh_t *imp_xxh = (imp_xxh_t*)SvPVX(SvRV(imp_xxh_rv));
    DBIc_DBISTATE(imp_xxh)->clearcom(imp_xxh);
    (void)cv;

# end
