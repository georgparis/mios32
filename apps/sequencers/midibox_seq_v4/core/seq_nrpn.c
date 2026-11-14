// $Id$
/*
 * MOD: NRPN parameter layer helpers and device catalogs
 *
 * Oberheim Matrix-1000 (firmware 1.20+):
 *   CC#99 (NRPN MSB) is ignored by the Matrix, MBSEQ sends 0
 *   CC#98 (NRPN LSB) = Matrix parameter number (Matrix-6 front panel numbering)
 *   CC#6  (Data Entry) = value + 64 (VCF Freq #21: value without offset)
 *   Source: untergeek.de "Oberheim Matrix 6/6R/1000 Programming Parameters"
 *
 * ==========================================================================
 *  Licensed for personal non-commercial use only.
 * ==========================================================================
 */

/////////////////////////////////////////////////////////////////////////////
// Include files
/////////////////////////////////////////////////////////////////////////////

#include <mios32.h>
#include <string.h>
#include "seq_nrpn.h"
#include "seq_core.h"
#include "seq_cc.h"
#include "seq_par.h"
#include "seq_layer.h"


/////////////////////////////////////////////////////////////////////////////
// Matrix-1000 parameter catalog (sorted by parameter number)
// { number, min, max, offset, name, short name }
/////////////////////////////////////////////////////////////////////////////

static const seq_nrpn_mx1k_par_t seq_nrpn_mx1k_pars[] = {
  {  0,    0,   63, 64, "DCO1 Freq", "D1Frq" },
  {  1,  -63,   63, 64, "DCO1 FLF1", "D1FL1" },
  {  2,    0,    3, 64, "DCO Sync",  "Sync " },
  {  3,    0,   63, 64, "DCO1 PW",   "D1PW " },
  {  4,  -63,   63, 64, "DCO1 PWL2", "D1PL2" },
  {  5,    0,   63, 64, "DCO1 Shp",  "D1Shp" },
  {  6,    0,    3, 64, "DCO1 Wave", "D1Wav" },
  {  7,    0,    3, 64, "DCO1 Levr", "D1Lev" },
  {  8,    0,    3, 64, "DCO1 KbPt", "D1KbP" },
  {  9,    0,    1, 64, "DCO1 Clck", "D1Clk" },
  { 10,    0,   63, 64, "DCO2 Freq", "D2Frq" },
  { 11,  -63,   63, 64, "DCO2 FLF1", "D2FL1" },
  { 12,  -31,   31, 64, "DCO2 Detn", "D2Det" },
  { 13,    0,   63, 64, "DCO2 PW",   "D2PW " },
  { 14,  -63,   63, 64, "DCO2 PWL2", "D2PL2" },
  { 15,    0,   63, 64, "DCO2 Shp",  "D2Shp" },
  { 16,    0,    7, 64, "DCO2 Wave", "D2Wav" },
  { 17,    0,    3, 64, "DCO2 Levr", "D2Lev" },
  { 18,    0,    3, 64, "DCO2 KbPt", "D2KbP" },
  { 19,    0,    1, 64, "DCO2 Clck", "D2Clk" },
  { 20,    0,   63, 64, "DCO Mix",   "Mix  " },
  { 21,    0,  127,  0, "VCF Freq",  "VCF  " },
  { 22,  -63,   63, 64, "VCF Env1",  "VCFE1" },
  { 23,  -63,   63, 64, "VCF Press", "VCFPr" },
  { 24,    0,   63, 64, "VCF Reso",  "Reso " },
  { 25,    0,    3, 64, "VCF Levr",  "VCFLv" },
  { 26,    0,    3, 64, "VCF KbPt",  "VCFKb" },
  { 27,    0,   63, 64, "VCA1 Lvl",  "VCA1 " },
  { 28,  -63,   63, 64, "VCA1 Velo", "VCA1V" },
  { 29,  -63,   63, 64, "VCA2 Env2", "VCA2E" },
  { 30,    0,   63, 64, "FM Amount", "FM   " },
  { 31,  -63,   63, 64, "FM Env3",   "FM E3" },
  { 32,  -63,   63, 64, "FM Press",  "FM Pr" },
  { 33,    0,   20, 64, "Trk Input", "TrkIn" },
  { 34,    0,   63, 64, "Trk Pnt1",  "TrkP1" },
  { 35,    0,   63, 64, "Trk Pnt2",  "TrkP2" },
  { 36,    0,   63, 64, "Trk Pnt3",  "TrkP3" },
  { 37,    0,   63, 64, "Trk Pnt4",  "TrkP4" },
  { 38,    0,   63, 64, "Trk Pnt5",  "TrkP5" },
  { 40,    0,   63, 64, "Rmp1 Rate", "R1Rat" },
  { 41,    0,    2, 64, "Rmp1 Trig", "R1Trg" },
  { 42,    0,   63, 64, "Rmp2 Rate", "R2Rat" },
  { 43,    0,    2, 64, "Rmp2 Trig", "R2Trg" },
  { 44,    0,   63, 64, "Port Rate", "PoRat" },
  { 45,  -63,   63, 64, "Port Velo", "PoVel" },
  { 46,    0,    3, 64, "Port Mode", "PoMod" },
  { 47,    0,    1, 64, "Legato",    "Legat" },
  { 48,    0,    3, 64, "Kbd Mode",  "KbMod" },
  { 50,    0,   63, 64, "Env1 Dly",  "E1Dly" },
  { 51,    0,   63, 64, "Env1 Att",  "E1Att" },
  { 52,    0,   63, 64, "Env1 Dec",  "E1Dec" },
  { 53,    0,   63, 64, "Env1 Sus",  "E1Sus" },
  { 54,    0,   63, 64, "Env1 Rel",  "E1Rel" },
  { 55,    0,   63, 64, "Env1 Amp",  "E1Amp" },
  { 56,  -63,   63, 64, "Env1 AVel", "E1AVl" },
  { 57,    0,    3, 64, "Env1 Trig", "E1Trg" },
  { 58,    0,    3, 64, "Env1 Mode", "E1Mod" },
  { 59,    0,    3, 64, "Env1 LTrg", "E1LTr" },
  { 60,    0,   63, 64, "Env2 Dly",  "E2Dly" },
  { 61,    0,   63, 64, "Env2 Att",  "E2Att" },
  { 62,    0,   63, 64, "Env2 Dec",  "E2Dec" },
  { 63,    0,   63, 64, "Env2 Sus",  "E2Sus" },
  { 64,    0,   63, 64, "Env2 Rel",  "E2Rel" },
  { 65,    0,   63, 64, "Env2 Amp",  "E2Amp" },
  { 66,  -63,   63, 64, "Env2 AVel", "E2AVl" },
  { 67,    0,    3, 64, "Env2 Trig", "E2Trg" },
  { 68,    0,    3, 64, "Env2 Mode", "E2Mod" },
  { 69,    0,    3, 64, "Env2 LTrg", "E2LTr" },
  { 70,    0,   63, 64, "Env3 Dly",  "E3Dly" },
  { 71,    0,   63, 64, "Env3 Att",  "E3Att" },
  { 72,    0,   63, 64, "Env3 Dec",  "E3Dec" },
  { 73,    0,   63, 64, "Env3 Sus",  "E3Sus" },
  { 74,    0,   63, 64, "Env3 Rel",  "E3Rel" },
  { 75,    0,   63, 64, "Env3 Amp",  "E3Amp" },
  { 76,  -63,   63, 64, "Env3 AVel", "E3AVl" },
  { 77,    0,    3, 64, "Env3 Trig", "E3Trg" },
  { 78,    0,    3, 64, "Env3 Mode", "E3Mod" },
  { 79,    0,    3, 64, "Env3 LTrg", "E3LTr" },
  { 80,    0,   63, 64, "LFO1 Spd",  "L1Spd" },
  { 81,  -63,   63, 64, "LFO1 SPrs", "L1SPr" },
  { 82,    0,    6, 64, "LFO1 Wave", "L1Wav" },
  { 83,    0,   31, 64, "LFO1 Rtrg", "L1Rtg" },
  { 84,    0,   63, 64, "LFO1 Amp",  "L1Amp" },
  { 85,  -63,   63, 64, "LFO1 ARp1", "L1ARp" },
  { 86,    0,    2, 64, "LFO1 Trig", "L1Trg" },
  { 87,    0,    1, 64, "LFO1 Lag",  "L1Lag" },
  { 88,    0,   20, 64, "LFO1 S&H",  "L1S&H" },
  { 90,    0,   63, 64, "LFO2 Spd",  "L2Spd" },
  { 91,  -63,   63, 64, "LFO2 SKbd", "L2SKb" },
  { 92,    0,    6, 64, "LFO2 Wave", "L2Wav" },
  { 93,    0,   31, 64, "LFO2 Rtrg", "L2Rtg" },
  { 94,    0,   63, 64, "LFO2 Amp",  "L2Amp" },
  { 95,  -63,   63, 64, "LFO2 ARp2", "L2ARp" },
  { 96,    0,    2, 64, "LFO2 Trig", "L2Trg" },
  { 97,    0,    1, 64, "LFO2 Lag",  "L2Lag" },
  { 98,    0,   20, 64, "LFO2 S&H",  "L2S&H" },
};

#define SEQ_NRPN_MX1K_NUM_PARS (sizeof(seq_nrpn_mx1k_pars)/sizeof(seq_nrpn_mx1k_par_t))


/////////////////////////////////////////////////////////////////////////////
// Returns the catalog entry of a Matrix-1000 parameter number
// (NULL if the parameter doesn't exist)
/////////////////////////////////////////////////////////////////////////////
const seq_nrpn_mx1k_par_t *SEQ_NRPN_Mx1kParGet(u8 num)
{
  int i;
  for(i=0; i<SEQ_NRPN_MX1K_NUM_PARS; ++i) {
    if( seq_nrpn_mx1k_pars[i].num == num )
      return &seq_nrpn_mx1k_pars[i];
  }
  return NULL;
}


/////////////////////////////////////////////////////////////////////////////
// Steps through the catalog, returns the new parameter number
// (unused numbers are skipped, invalid numbers start at the first entry)
/////////////////////////////////////////////////////////////////////////////
u8 SEQ_NRPN_Mx1kParInc(u8 num, s32 incrementer)
{
  int ix;
  for(ix=0; ix<SEQ_NRPN_MX1K_NUM_PARS; ++ix) {
    if( seq_nrpn_mx1k_pars[ix].num >= num )
      break;
  }

  if( ix >= SEQ_NRPN_MX1K_NUM_PARS )
    ix = SEQ_NRPN_MX1K_NUM_PARS-1;
  else if( seq_nrpn_mx1k_pars[ix].num == num )
    ix += incrementer;
  else if( incrementer < 0 )
    ix += incrementer; // number was between two entries (ix points to the next higher one)
  else
    ix += incrementer - 1;

  if( ix < 0 )
    ix = 0;
  else if( ix >= SEQ_NRPN_MX1K_NUM_PARS )
    ix = SEQ_NRPN_MX1K_NUM_PARS-1;

  return seq_nrpn_mx1k_pars[ix].num;
}


/////////////////////////////////////////////////////////////////////////////
// Returns the Matrix-1000 catalog entry of a parameter layer
// (NULL if the layer isn't a NRPN layer in Matrix-1000 mode)
/////////////////////////////////////////////////////////////////////////////
const seq_nrpn_mx1k_par_t *SEQ_NRPN_LayerMx1kParGet(u8 track, u8 par_layer)
{
  if( par_layer >= 16 )
    return NULL;

  seq_cc_trk_t *tcc = &seq_cc_trk[track];
  if( tcc->event_mode == SEQ_EVENT_MODE_Drum ||
      tcc->lay_const[0*16 + par_layer] != SEQ_PAR_Type_NRPN ||
      tcc->lay_const[1*16 + par_layer] != SEQ_NRPN_MSB_MX1K )
    return NULL;

  return SEQ_NRPN_Mx1kParGet(tcc->lay_const[2*16 + par_layer] & 0x7f);
}


/////////////////////////////////////////////////////////////////////////////
// Returns the NRPN number which has to be sent for a NRPN layer
// return value: 1 if valid, 0 if NRPN disabled
/////////////////////////////////////////////////////////////////////////////
s32 SEQ_NRPN_AddressGet(u8 track, u8 par_layer, u8 *msb, u8 *lsb)
{
  if( par_layer >= 16 )
    return 0;

  seq_cc_trk_t *tcc = &seq_cc_trk[track];
  u8 b = tcc->lay_const[1*16 + par_layer];
  u8 c = tcc->lay_const[2*16 + par_layer] & 0x7f;

  if( b == SEQ_NRPN_MSB_MX1K ) {
    if( !SEQ_NRPN_Mx1kParGet(c) )
      return 0; // unknown parameter
    *msb = 0; // ignored by the Matrix
    *lsb = c;
    return 1;
  }

  if( b >= 0x80 )
    return 0; // off

  *msb = b;
  *lsb = c;
  return 1;
}


/////////////////////////////////////////////////////////////////////////////
// Returns the allowed range of the (sent) layer value
// return value: 1 if a catalog range applies, 0 if the full range 0..127 is allowed
/////////////////////////////////////////////////////////////////////////////
s32 SEQ_NRPN_ValueRangeGet(u8 track, u8 par_layer, u8 *min, u8 *max)
{
  const seq_nrpn_mx1k_par_t *par = SEQ_NRPN_LayerMx1kParGet(track, par_layer);
  if( !par )
    return 0;

  *min = (u8)(par->min + par->offset);
  *max = (u8)(par->max + par->offset);
  return 1;
}


/////////////////////////////////////////////////////////////////////////////
// Converts a (sent) layer value into the value shown by the device
/////////////////////////////////////////////////////////////////////////////
s32 SEQ_NRPN_DisplayValueGet(u8 track, u8 par_layer, u8 value)
{
  const seq_nrpn_mx1k_par_t *par = SEQ_NRPN_LayerMx1kParGet(track, par_layer);
  if( !par )
    return value;

  return (s32)value - par->offset;
}
