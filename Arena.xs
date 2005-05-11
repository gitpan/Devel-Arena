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
  HV *output = newHV();
  UV fakes = 0;
  UV arenas = 0;
  UV slots = 0;
  UV free = 0;
  SV* svp = PL_sv_arenaroot;

  while (svp) {
    arenas++;
    slots += SvREFCNT(svp);
    if (SvFAKE(svp))
      fakes++;
    svp = (SV *) SvANY(svp);
  }

  svp = PL_sv_root;
  while (svp) {
    free++;
    svp = (SV *) SvANY(svp);
  }

  store_UV(output, "arenas", arenas);
  store_UV(output, "fakes", fakes);
  store_UV(output, "total_slots", slots);
  store_UV(output, "free", free);

  RETVAL = output;
}
OUTPUT:
	RETVAL
