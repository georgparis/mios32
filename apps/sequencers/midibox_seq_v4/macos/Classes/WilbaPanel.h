// $Id$
//
//  WilbaPanel.h
//  midibox_seq_v4 emulator
//
//  Skeuomorphic emulation of Wilba's MIDIbox SEQ V4 frontpanel.
//  Buttons and LEDs are connected to an emulated 8x8 button/LED matrix
//  (BLM8X8) like on the real PCB, encoders are forwarded to APP_ENC_NotifyChange.
//  The pin assignments are taken from hwcfg/wilba/MBSEQ_HW.V4
//

#import <Cocoa/Cocoa.h>

@class CLcdView;

@interface WilbaPanel : NSObject

// creates and shows the frontpanel window, returns the two LCD views
+ (void)createWindowWithLcdLeft:(CLcdView **)lcdLeft lcdRight:(CLcdView **)lcdRight;

// should be called periodically from the main thread to update the LEDs
+ (void)periodicUpdate;

// executes a test script in a background thread (see WilbaPanel.mm)
+ (void)runScript:(NSString *)path;

@end

#ifdef __cplusplus
extern "C" {
#endif

// state of the emulated 8x8 button matrix (one byte per row M1..M8, 0 = pressed)
// read by the SRIO emulation in UI.mm
extern unsigned char emu_blm8x8_buttons[8];

#ifdef __cplusplus
}
#endif
