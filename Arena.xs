#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "sv-table.inc"

#if PERL_VERSION >= 8
#define DO_PM_STATS
/* PMOP stats seem to SEGV pre 5.8.0 for some unknown reason.
   (Well, dereferncing 0x8 is quite well known as a cause of SEGVs, it's just
   why I find that value in a chain of pointers...)  */
#endif

#ifndef HvRITER_get
#  define HvRITER_get HvRITER
#endif
#ifndef HvEITER_get
#  define HvEITER_get HvEITER
#endif

#ifndef HvPLACEHOLDERS_get
#  define HvPLACEHOLDERS_get HvPLACEHOLDERS
#endif

static void
store_UV(HV *hash, const char *key, UV value) {
  SV *sv = newSVuv(value);
  if (!hv_store(hash, (char *)key, strlen(key), sv, 0)) {
    /* Oops. Failed.  */
    SvREFCNT_dec(sv);
  }
}

static void
inc_UV_key(HV *hash, UV key) {
  SV **count = hv_fetch(hash, (char*)&key, sizeof(key), 1);
  if (count) {
    sv_inc(*count);
  }
}

typedef void (unpack_function)(pTHX_ SV *sv, UV u);

/* map hash keys in some interesting way.  */
static HV *
unpack_hash_keys(HV *packed, unpack_function *f) {
  HV *unpacked = newHV();
  SV *temp = newSV(0);
  char *key;
  I32 keylen;
  SV *count;
  dTHX;

  hv_iterinit(packed);
  while ((count = hv_iternextsv(packed, &key, &keylen))) {
    /* need to do the unpack.  */
    STRLEN len;
    char *p;
    UV value = 0;

    assert (keylen == sizeof(value));
    memcpy (&value, key, sizeof(value));

    /* Convert the number to a string.  */
    f(aTHX_ temp, value);
    p = SvPV(temp, len);
    
    if (!hv_store(unpacked, p, len, SvREFCNT_inc(count), 0)) {
      /* Oops. Failed.  */
      SvREFCNT_dec(count);
    }
  }
  SvREFCNT_dec(temp);
  return unpacked;
}

/* take a hash keyed by packed UVs and build a new hash keyed by (stringified)
   numbers.
   keys are (in effect) map {unpack "J", $_}
*/
static HV *
unpack_UV_hash_keys(HV *packed) {
  return unpack_hash_keys(packed, &Perl_sv_setuv);
}

static HV *
unpack_IV_hash_keys(HV *packed) {
  /* Cast needed as IV isn't UV (the last argument)  */
  return unpack_hash_keys(packed, (unpack_function*)&Perl_sv_setiv);
}

void
UV_to_type(pTHX_ SV *sv, UV value)
{
  if (value < sv_names_len) {
    sv_setpv(sv, sv_names[value]);
  } else if (value == SVTYPEMASK) {
    sv_setpv(sv, "(free)");
  } else {
    /* Convert the number to a string.  */
    sv_setuv(sv, value);
  }
}

static HV *
unpack_UV_keys_to_types(HV *packed) {
  return unpack_hash_keys(packed, &UV_to_type);
}

static int
store_hv_in_hv(HV *target, const char *key, HV *value) {
  SV *rv = newRV_noinc((SV *)value);
  if (hv_store(target, (char *)key, strlen(key), rv, 0))
    return 1;

  /* Oops. Failed.  */
  SvREFCNT_dec(rv);
  return 0;
}

static HV *
sv_stats() {
  HV *hv = newHV();
  UV hv_has_name = 0;
  UV av_has_arylen = 0;
  HV *sizes;
  HV *types_raw = newHV();
#ifdef DO_PM_STATS
  HV *pm_stats_raw = newHV();
#endif
  HV *riter_stats_raw = newHV();
  UV hv_has_eiter = 0;
  HV *mg_stats_raw = newHV();
  HV *stash_stats_raw = newHV();
  HV *types;
  UV fakes = 0;
  UV arenas = 0;
  UV slots = 0;
  UV free = 0;
  SV* svp = PL_sv_arenaroot;

  while (svp) {
    SV **count;
    UV size = SvREFCNT(svp); 
    
    arenas++;
    slots += size;
    if (SvFAKE(svp))
      fakes++;

    inc_UV_key(hv, size);

    /* Remember that the zeroth slot is used as the pointer onwards, so don't
       include it. */

    while (--size > 0) {
      UV type = SvTYPE(svp + size);
	SV *target = (SV*)svp + size;

      if(type >= SVt_PVMG && type <= sv_names_len) {
	/* This is naughty. I'm storing hashes directly in hashes.  */
	HV **stats;
	MAGIC *mg = SvMAGIC(target);
	UV mg_count = 0;

	while (mg) {
	  mg_count++;
	  mg = mg->mg_moremagic;
	}

	stats = (HV**) hv_fetch(mg_stats_raw, (char*)&type, sizeof(type), 1);
	if (stats) {
	  if (SvTYPE(*stats) != SVt_PVHV) {
	    /* We got back a new SV that has just been created. Substitute a
	       hash for it.  */
	    SvREFCNT_dec(*stats);
	    *stats = newHV();
	  }
	  inc_UV_key(*stats, mg_count);
	}

	if (SvSTASH(target)) {
	  inc_UV_key(stash_stats_raw, type);
	}
      }
      if(type == SVt_PVHV) {
#ifdef DO_PM_STATS
	UV pm_count = 0;
	PMOP *pm = HvPMROOT((HV*)target);

	while (pm) {
	  pm_count++;
	  pm = pm->op_pmnext;
	}

	inc_UV_key(pm_stats_raw, pm_count);
#endif

	if (HvEITER_get(target))
	  hv_has_eiter++;
	inc_UV_key(riter_stats_raw, (UV)HvRITER_get(target));
	if (HvNAME(target))
	  hv_has_name++;
      } else if (type == SVt_PVAV) {
	if (AvARYLEN(target))
	  av_has_arylen++;
      }

      inc_UV_key(types_raw, type);
    }

    svp = (SV *) SvANY(svp);
  }

  {
    /* Now splice all our mg stats hashes into the main count hash  */
    HV *mg_stats_raw_for_type;
    char *key;
    I32 keylen;

    hv_iterinit(mg_stats_raw);
    while ((mg_stats_raw_for_type
	    = (HV *) hv_iternextsv(mg_stats_raw, &key, &keylen))) {
      HV *type_stats = newHV();
      UV type;
      /* This is the position in the main counts stash.  */
      SV **count = hv_fetch(types_raw, key, keylen, 1);

      assert (keylen == sizeof(UV));
      assert (SvTYPE(mg_stats_raw_for_type) == SVt_PVHV);

      memcpy (&type, key, sizeof(type));

      if (count) {
	if(hv_store(type_stats, "total", 5, *count, 0)) {
	  /* We've now re-stored the total.
	   At this point hv_stats and types_raw *both* think that they own a
	   reference, but the reference count is 1.
	   Which is OK, because types_raw is about to be holding a reference
	   to something else:
	  */
	  *count = newRV_noinc((SV *)type_stats);

	  store_hv_in_hv(type_stats, "mg",
			 unpack_UV_hash_keys(mg_stats_raw_for_type));

	  if(type == SVt_PVHV) {
	    /* Specific extra things to store for Hashes  */
#ifdef DO_PM_STATS
	    store_hv_in_hv(type_stats, "PMOPs",
			   unpack_UV_hash_keys(pm_stats_raw));
	    SvREFCNT_dec(pm_stats_raw);
#endif
	    store_hv_in_hv(type_stats, "riter",
			   unpack_IV_hash_keys(riter_stats_raw));
	    SvREFCNT_dec(riter_stats_raw);
	    store_UV(type_stats, "has_name", hv_has_name);
	    store_UV(type_stats, "has_eiter", hv_has_eiter);
	  } else if(type == SVt_PVAV) {
	    store_UV(type_stats, "has_arylen", av_has_arylen);
	  }
	}
      }
    }
  }
  /* At which point the raw hashes still have 1 reference each, owned by the
     top level hash, which we don't need any more.  */
  SvREFCNT_dec(mg_stats_raw);

  /* Now splice our stash stats into the main count hash.
     I can't see a good way to reduce code duplication here.  */
  {
    SV *stash_stat;
    char *key;
    I32 keylen;

    hv_iterinit(stash_stats_raw);
    while ((stash_stat = hv_iternextsv(stash_stats_raw, &key, &keylen))) {
      /* This is the position in the main counts stash.  */
      SV **count = hv_fetch(types_raw, key, keylen, 1);

      if (count) {
	HV *results;
	if (SvROK(*count)) {
	  results = (HV*)SvRV(*count);
	} else {
	  results = newHV();

	  /* We're donating the reference of *count from types_raw to results
	   */
	  if(!hv_store(results, "total", 5, *count, 0)) {
	    /* We're in a mess here.  */
	    croak("store failed");
	  }
	  *count = newRV_noinc((SV *)results);
	}

	if(hv_store(results, "has_stash", 9, stash_stat, 0)) {
	  /* Currently has 1 reference, owned by stash_stats_raw. Fix this:  */
	  SvREFCNT_inc(stash_stat);
	}
      }
    }
  }
  SvREFCNT_dec(stash_stats_raw);

  svp = PL_sv_root;
  while (svp) {
    free++;
    svp = (SV *) SvANY(svp);
  }

  types = unpack_UV_keys_to_types(types_raw);
  SvREFCNT_dec(types_raw);
  sizes = unpack_UV_hash_keys(hv);

  /* Now re-use it for our output  */
  hv_clear(hv);

  store_UV(hv, "arenas", arenas);
  store_UV(hv, "fakes", fakes);
  store_UV(hv, "total_slots", slots);
  store_UV(hv, "free", free);

  store_UV(hv, "nice_chunk_size", PL_nice_chunk_size);
  store_UV(hv, "sizeof(SV)", sizeof(SV));

  store_hv_in_hv(hv, "sizes", sizes);
  store_hv_in_hv(hv, "types", types);

  return hv;
}


MODULE = Devel::Arena		PACKAGE = Devel::Arena		

HV *
sv_stats()
