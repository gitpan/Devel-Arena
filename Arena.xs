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

static void
store_UV(HV *hash, const char *key, UV value) {
  SV *sv = newSVuv(value);
  if (!hv_store(hash, (char *)key, strlen(key), sv, 0)) {
    /* Oops. Failed.  */
    SvREFCNT_dec(sv);
  }
}

/* take a hash keyed by packed UVs and build a new hash keyed by (stringified)
   numbers.
   keys are (in effect) map {unpack "J", $_}
*/
static HV *
unpack_UV_hash_keys(HV *packed) {
  HV *unpacked = newHV();
  SV *temp = newSV(0);
  char *key;
  I32 keylen;
  SV *count;

  hv_iterinit(packed);
  while ((count = hv_iternextsv(packed, &key, &keylen))) {
    /* need to do the unpack.  */
    STRLEN len;
    char *p;
    UV value = 0;

    assert (keylen == sizeof(value));
    memcpy (&value, key, sizeof(value));

    /* Convert the number to a string.  */
    sv_setuv(temp, value);
    p = SvPV(temp, len);
    
    if (!hv_store(unpacked, p, len, SvREFCNT_inc(count), 0)) {
      /* Oops. Failed.  */
      SvREFCNT_dec(count);
    }
  }
  SvREFCNT_dec(temp);
  return unpacked;
}

static HV *
unpack_UV_keys_to_types(HV *packed) {
  HV *unpacked = newHV();
  SV *temp = newSV(0);
  char *key;
  I32 keylen;
  SV *count;

  hv_iterinit(packed);
  while ((count = hv_iternextsv(packed, &key, &keylen))) {
    /* need to do the unpack.  */
    STRLEN len;
    const char *p;
    UV value = 0;

    assert (keylen == sizeof(value));
    memcpy (&value, key, sizeof(value));

    if (value < sv_names_len) {
      p = sv_names[value];
      len = strlen(p);
    } else if (value == SVTYPEMASK) {
      p = "(free)";
      len = 6;
    } else {
      /* Convert the number to a string.  */
      sv_setuv(temp, value);
      p = SvPV(temp, len);
    }
    
    if (!hv_store(unpacked, (char *)p, len, SvREFCNT_inc(count), 0)) {
      /* Oops. Failed.  */
      SvREFCNT_dec(count);
    }
  }
  SvREFCNT_dec(temp);
  return unpacked;
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
  HV *sizes;
  HV *types_raw = newHV();
#ifdef DO_PM_STATS
  HV *pm_stats_raw = newHV();
#endif
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

    count = hv_fetch(hv, (char*)&size, sizeof(size), 1);
    if (count) {
      sv_inc(*count);
    }

    /* Remember that the zeroth slot is used as the pointer onwards, so don't
       include it. */

    while (--size > 0) {
      UV type = SvTYPE(svp + size);

      if(type == SVt_PVHV) {
	HV *target = (HV*)svp + size;
#ifdef DO_PM_STATS
	UV pm_count = 0;
	PMOP *pm = HvPMROOT(target);

	while (pm) {
	  pm_count++;
	  pm = pm->op_pmnext;
	}

	count = hv_fetch(pm_stats_raw, (char*)&pm_count, sizeof(pm_count), 1);
	if (count) {
	  sv_inc(*count);
	}
#endif

	if (HvNAME(target))
	  hv_has_name++;
      }

      count = hv_fetch(types_raw, (char*)&type, sizeof(type), 1);
      if (count) {
	sv_inc(*count);
      }
    }

    svp = (SV *) SvANY(svp);
  }

  {
    const UV type = SVt_PVHV;
    SV **count = hv_fetch(types_raw, (char*)&type, sizeof(type), 1);
    if (count) {
      HV *hv_stats = newHV();
#ifdef DO_PM_STATS
      HV *pm_stats = unpack_UV_hash_keys(pm_stats_raw);

      SvREFCNT_dec(pm_stats_raw);

      store_hv_in_hv(hv_stats, "PMOPs", pm_stats);

#endif
      store_UV(hv_stats, "has_name", hv_has_name);

      if(hv_store(hv_stats, "total", 5, *count, 0)) {
	/* We've now re-stored the total.
	   At this point hv_stats and types_raw *both* think that they own a
	   reference, but the reference count is 1.
	   Which is OK, because types_raw is about to be holding a reference
	   to something else:
	*/
	*count = newRV_noinc((SV *)hv_stats);
      }
    }
  }
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
