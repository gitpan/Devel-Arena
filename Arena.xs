#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "sv-table.inc"

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
    
    if (!hv_store(unpacked, p, len, SvREFCNT_inc(count), 0)) {
      /* Oops. Failed.  */
      SvREFCNT_dec(count);
    }
  }
  SvREFCNT_dec(temp);
  return unpacked;
}

MODULE = Devel::Arena		PACKAGE = Devel::Arena		

HV *
sv_stats()
CODE:
{
  HV *hv = newHV();
  HV *sizes;
  HV *types_raw = newHV();
  HV *types;
  UV fakes = 0;
  UV arenas = 0;
  UV slots = 0;
  UV free = 0;
  SV* svp = PL_sv_arenaroot;
  SV *rv;

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

      count = hv_fetch(types_raw, (char*)&type, sizeof(type), 1);
      if (count) {
	sv_inc(*count);
      }
    }

    svp = (SV *) SvANY(svp);
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

  rv = newRV_noinc((SV *)sizes);
  if (!hv_store(hv, "sizes", strlen("sizes"), rv, 0)) {
    /* Oops. Failed.  */
    SvREFCNT_dec(rv);
  }
  rv = newRV_noinc((SV *)types);
  if (!hv_store(hv, "types", strlen("types"), rv, 0)) {
    /* Oops. Failed.  */
    SvREFCNT_dec(rv);
  }

  RETVAL = hv;
}
OUTPUT:
	RETVAL
