#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

static void
store_UV(HV *hash, const char *key, UV value) {
  SV *sv = newSVuv(value);
  if (!hv_store(hash, (char *)key, strlen(key), sv, 0)) {
    /* Oops. Failed.  */
    SvREFCNT_dec(sv);
  }
}

MODULE = Devel::Arena		PACKAGE = Devel::Arena		

HV *
sv_stats()
CODE:
{
  HV *hv = newHV();
  HV *sizes = newHV();
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
    svp = (SV *) SvANY(svp);
  }

  svp = PL_sv_root;
  while (svp) {
    free++;
    svp = (SV *) SvANY(svp);
  }

  /* copy our hash of size counts (keyed by packed sizes) into a hash keyed
     by (stringified) numbers.
     keys are (in effect) map {unpack "J", $_}
  */
  {
    SV *temp = newSV(0);
    char *key;
    I32 keylen;
    SV *count;

    hv_iterinit(hv);
    while ((count = hv_iternextsv(hv, &key, &keylen))) {
      /* need to do the unpack.  */
      STRLEN len;
      char *p;
      UV value = 0;

      assert (keylen == sizeof(value));
      memcpy (&value, key, sizeof(value));

      /* Convert the number to a string.  */
      sv_setuv(temp, value);
      p = SvPV(temp, len);

      if (!hv_store(sizes, p, len, SvREFCNT_inc(count), 0)) {
	/* Oops. Failed.  */
	SvREFCNT_dec(count);
      }
    }
    SvREFCNT_dec(temp);
  }

  /* Now re-use it for our output  */
  hv_clear(hv);

  store_UV(hv, "arenas", arenas);
  store_UV(hv, "fakes", fakes);
  store_UV(hv, "total_slots", slots);
  store_UV(hv, "free", free);

  rv = newRV_noinc((SV *)sizes);
  if (!hv_store(hv, "sizes", strlen("sizes"), rv, 0)) {
    /* Oops. Failed.  */
    SvREFCNT_dec(rv);
  }

  RETVAL = hv;
}
OUTPUT:
	RETVAL
