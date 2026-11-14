// $Id$
/*
 * MOD: NRPN parameter layer helpers and device catalogs
 *
 * A NRPN parameter layer stores
 *   Const B: NRPN MSB (CC#99), 0x80 = off, SEQ_NRPN_MSB_MX1K = Matrix-1000 catalog
 *   Const C: NRPN LSB (CC#98) resp. Matrix-1000 parameter number
 *
 * ==========================================================================
 *  Licensed for personal non-commercial use only.
 * ==========================================================================
 */

#ifndef _SEQ_NRPN_H
#define _SEQ_NRPN_H

/////////////////////////////////////////////////////////////////////////////
// Global definitions
/////////////////////////////////////////////////////////////////////////////

#define SEQ_NRPN_MSB_OFF   0x80
#define SEQ_NRPN_MSB_MX1K  0x81 // Oberheim Matrix-1000 (firmware 1.20+) catalog
#define SEQ_NRPN_MSB_MAX   SEQ_NRPN_MSB_MX1K


/////////////////////////////////////////////////////////////////////////////
// Global Types
/////////////////////////////////////////////////////////////////////////////

typedef struct {
  u8   num;            // Matrix parameter number (sent as NRPN LSB)
  s8   min;            // value range as shown by the Matrix
  s8   max;
  u8   offset;         // sent value = value + offset (64, VCF Freq: 0)
  char name[10];       // 9 characters + terminator
  char short_name[6];  // 5 characters + terminator
} seq_nrpn_mx1k_par_t;


/////////////////////////////////////////////////////////////////////////////
// Prototypes
/////////////////////////////////////////////////////////////////////////////

extern const seq_nrpn_mx1k_par_t *SEQ_NRPN_Mx1kParGet(u8 num);
extern u8 SEQ_NRPN_Mx1kParInc(u8 num, s32 incrementer);

extern s32 SEQ_NRPN_AddressGet(u8 track, u8 par_layer, u8 *msb, u8 *lsb);
extern const seq_nrpn_mx1k_par_t *SEQ_NRPN_LayerMx1kParGet(u8 track, u8 par_layer);
extern s32 SEQ_NRPN_ValueRangeGet(u8 track, u8 par_layer, u8 *min, u8 *max);
extern s32 SEQ_NRPN_DisplayValueGet(u8 track, u8 par_layer, u8 value);

#endif /* _SEQ_NRPN_H */
