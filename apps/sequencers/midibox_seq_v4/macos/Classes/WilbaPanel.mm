// $Id$
//
//  WilbaPanel.mm
//  midibox_seq_v4 emulator
//
//  Skeuomorphic emulation of Wilba's MIDIbox SEQ V4 frontpanel.
//
//  - Buttons and LEDs are connected to an emulated 8x8 button/LED matrix like
//    on Wilba's PCB (see BLM8X8_* and M<row> <pin> entries in
//    hwcfg/wilba/MBSEQ_HW.V4). The matrix button state is scanned by the SRIO
//    emulation in UI.mm, LED states are taken from seq_blm8x8_led_row[].
//  - Encoders are forwarded to APP_ENC_NotifyChange (0 = datawheel, 1..16 = GP)
//    Mouse: drag up/down or use the scroll wheel/trackpad.
//  - The layout follows the photo of Wilba's frontpanel (coordinates in pixels
//    of the reference photo, scaled with S).
//

#import "WilbaPanel.h"
#include <sys/stat.h>
#import "CLcdView.h"
#include "CLcd.h"

#include <mios32.h>
#include "app.h"
#include "seq_blm8x8.h"

extern "C" {
  unsigned char emu_blm8x8_buttons[8] = { 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff };
}

/////////////////////////////////////////////////////////////////////////////
// Geometry: coordinates of the reference photo -> view coordinates
/////////////////////////////////////////////////////////////////////////////
static const CGFloat S  = 1.25;  // scale factor
static const CGFloat OX = 30.0;  // left border of the photo crop
static const CGFloat OY = 34.0;  // upper border of the photo crop
static const CGFloat PANEL_W = 1125.0;
static const CGFloat PANEL_H = 312.0;

static inline CGFloat PX(CGFloat x) { return (x - OX) * S; }
static inline CGFloat PY(CGFloat y) { return (y - OY) * S; }

static const CGFloat ENC_X_L[8] = { 290, 334, 377, 420, 464, 507, 550, 593 };
static const CGFloat ENC_X_R[8] = { 708, 752, 797, 841, 885, 929, 973, 1017 };

static const CGFloat KEY_W = 27.0;
static const CGFloat KEY_H = 14.0;

/////////////////////////////////////////////////////////////////////////////
// Colours
/////////////////////////////////////////////////////////////////////////////
static NSColor *rgb(CGFloat r, CGFloat g, CGFloat b, CGFloat a = 1.0)
{
  return [NSColor colorWithCalibratedRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a];
}

/////////////////////////////////////////////////////////////////////////////
// Matrix helpers
/////////////////////////////////////////////////////////////////////////////
static BOOL matrixLedGet(int row, int pin)
{
  if( row < 1 || row > 8 )
    return NO;
  return (seq_blm8x8_led_row[0][row-1] & (1 << pin)) ? YES : NO;
}

// GP LED mapping of Wilba's PCB (see SEQ_UI_LED_Handler: dout_gp_mapping == 1)
// pairs of GP LEDs per matrix row: bit7: odd GP green, bit6: odd GP red, bit5: even GP green, bit4: even GP red
static void gpLedGet(int gp, BOOL *green, BOOL *red)
{
  static const int map[8] = { 4, 5, 6, 7, 3, 2, 1, 0 };
  int ix = gp - 1;
  int row = map[ix / 2];
  u8 value = seq_blm8x8_led_row[0][row];
  BOOL second = (ix & 1) ? YES : NO;
  *green = (value & (second ? 0x20 : 0x80)) ? YES : NO;
  *red   = (value & (second ? 0x10 : 0x40)) ? YES : NO;
}


/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
// LED
/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
typedef enum { LED_GREEN, LED_RED, LED_DUO_GP } led_type_t;

@interface WilbaLed : NSView {
@public
  led_type_t type;
  int row, pin; // matrix position (LED_GREEN, LED_RED)
  int gp;       // GP number (LED_DUO_GP)
  int lastState;
}
- (BOOL)refresh;
@end

@implementation WilbaLed

- (int)currentState
{
  if( type == LED_DUO_GP ) {
    BOOL g, r;
    gpLedGet(gp, &g, &r);
    return (g ? 1 : 0) | (r ? 2 : 0);
  }
  return matrixLedGet(row, pin) ? 1 : 0;
}

- (BOOL)refresh
{
  int state = [self currentState];
  if( state != lastState ) {
    lastState = state;
    [self setNeedsDisplay:YES];
    return YES;
  }
  return NO;
}

- (void)drawRect:(NSRect)dirtyRect
{
  NSRect b = [self bounds];
  CGFloat d = MIN(b.size.width, b.size.height) - 8.0;
  NSRect r = NSMakeRect(NSMidX(b) - d/2, NSMidY(b) - d/2, d, d);

  int state = lastState;
  NSColor *on = nil;
  NSColor *off = rgb(30, 42, 30);
  if( type == LED_RED ) {
    off = rgb(48, 22, 20);
    if( state ) on = rgb(255, 60, 45);
  } else if( type == LED_DUO_GP ) {
    if( (state & 3) == 3 ) on = rgb(255, 190, 40);   // green + red = amber
    else if( state & 1 )   on = rgb(110, 255, 80);
    else if( state & 2 )   on = rgb(255, 60, 45);
  } else {
    if( state ) on = rgb(110, 255, 80);
  }

  // bezel / hole in the panel
  NSBezierPath *hole = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(r, -1.5, -1.5)];
  [rgb(10, 10, 10) set];
  [hole fill];

  NSBezierPath *body = [NSBezierPath bezierPathWithOvalInRect:r];
  if( on ) {
    // glow
    [NSGraphicsContext saveGraphicsState];
    NSShadow *glow = [[[NSShadow alloc] init] autorelease];
    [glow setShadowColor:[on colorWithAlphaComponent:0.9]];
    [glow setShadowBlurRadius:d * 1.2];
    [glow setShadowOffset:NSZeroSize];
    [glow set];
    [on set];
    [body fill];
    [NSGraphicsContext restoreGraphicsState];

    NSGradient *g = [[[NSGradient alloc] initWithColorsAndLocations:
                       [NSColor whiteColor], 0.0,
                       [on highlightWithLevel:0.3], 0.35,
                       on, 0.75,
                       [on shadowWithLevel:0.25], 1.0, nil] autorelease];
    [g drawInBezierPath:body relativeCenterPosition:NSMakePoint(-0.25, 0.35)];
  } else {
    NSGradient *g = [[[NSGradient alloc] initWithColorsAndLocations:
                       [off highlightWithLevel:0.35], 0.0,
                       off, 0.6,
                       [off shadowWithLevel:0.5], 1.0, nil] autorelease];
    [g drawInBezierPath:body relativeCenterPosition:NSMakePoint(-0.25, 0.35)];
  }

  // specular highlight
  NSRect hl = NSMakeRect(r.origin.x + d*0.22, r.origin.y + d*0.52, d*0.35, d*0.25);
  [[NSColor colorWithCalibratedWhite:1.0 alpha:on ? 0.55 : 0.18] set];
  [[NSBezierPath bezierPathWithOvalInRect:hl] fill];
}

@end


/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
// Button (keycap)
/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
@interface WilbaKey : NSView {
@public
  int row, pin; // matrix position
  BOOL pressed;
}
@end

@implementation WilbaKey

- (void)setPressed:(BOOL)p
{
  if( row < 1 || row > 8 )
    return;
  pressed = p;
  if( p )
    emu_blm8x8_buttons[row-1] &= ~(1 << pin);
  else
    emu_blm8x8_buttons[row-1] |= (1 << pin);
  [self setNeedsDisplay:YES];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)mouseDown:(NSEvent *)event { [self setPressed:YES]; }
- (void)mouseUp:(NSEvent *)event   { [self setPressed:NO]; }

- (void)drawRect:(NSRect)dirtyRect
{
  NSRect b = NSInsetRect([self bounds], 3, 3);
  CGFloat press = pressed ? 1.5 : 0.0;

  // cutout in the panel
  NSBezierPath *cut = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(b, -1.5, -1.5) xRadius:3.5 yRadius:3.5];
  [rgb(8, 8, 9) set];
  [cut fill];

  // keycap body with drop shadow
  NSRect cap = NSOffsetRect(NSInsetRect(b, 0.5, 0.5), 0, -press);
  [NSGraphicsContext saveGraphicsState];
  NSShadow *sh = [[[NSShadow alloc] init] autorelease];
  [sh setShadowColor:[NSColor colorWithCalibratedWhite:0 alpha:0.8]];
  [sh setShadowBlurRadius:pressed ? 1.0 : 2.5];
  [sh setShadowOffset:NSMakeSize(0, pressed ? -0.5 : -2.0)];
  [sh set];
  NSBezierPath *body = [NSBezierPath bezierPathWithRoundedRect:cap xRadius:2.5 yRadius:2.5];
  [rgb(20, 20, 22) set];
  [body fill];
  [NSGraphicsContext restoreGraphicsState];

  NSGradient *side = [[[NSGradient alloc] initWithStartingColor:rgb(58, 58, 62) endingColor:rgb(14, 14, 16)] autorelease];
  [side drawInBezierPath:body angle:90];

  // concave top surface
  NSRect top = NSInsetRect(cap, 3.0, 2.2);
  top.origin.y += 0.8;
  NSBezierPath *topPath = [NSBezierPath bezierPathWithRoundedRect:top xRadius:1.8 yRadius:1.8];
  NSGradient *tg = [[[NSGradient alloc] initWithColorsAndLocations:
                      pressed ? rgb(24, 24, 27) : rgb(34, 34, 38), 0.0,
                      pressed ? rgb(30, 30, 33) : rgb(44, 44, 49), 0.5,
                      pressed ? rgb(22, 22, 25) : rgb(30, 30, 34), 1.0, nil] autorelease];
  [tg drawInBezierPath:topPath angle:90];

  // highlight edge
  [[NSColor colorWithCalibratedWhite:1.0 alpha:pressed ? 0.05 : 0.14] set];
  NSBezierPath *edge = [NSBezierPath bezierPath];
  [edge moveToPoint:NSMakePoint(NSMinX(cap)+2, NSMaxY(cap)-0.7)];
  [edge lineToPoint:NSMakePoint(NSMaxX(cap)-2, NSMaxY(cap)-0.7)];
  [edge setLineWidth:1.0];
  [edge stroke];
}

@end


/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
// Encoder knob (GP encoders and datawheel)
/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
@interface WilbaKnob : NSView {
@public
  int encoder;     // 0 = datawheel, 1..16 = GP encoders
  BOOL datawheel;
  CGFloat angle;   // indicator angle (radians, 0 = 12 o'clock, clockwise)
  CGFloat dragAccu;
  CGFloat scrollAccu;
  NSPoint lastPoint;
}
@end

@implementation WilbaKnob

- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }

- (void)turn:(int)incrementer
{
  if( !incrementer )
    return;
  APP_ENC_NotifyChange(encoder, incrementer);
  angle += incrementer * (datawheel ? (2*M_PI/40.0) : (2*M_PI/24.0));
  [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)event
{
  lastPoint = [event locationInWindow];
  dragAccu = 0;
}

- (void)mouseDragged:(NSEvent *)event
{
  NSPoint p = [event locationInWindow];
  // up/right = clockwise
  dragAccu += (p.y - lastPoint.y) + (p.x - lastPoint.x);
  lastPoint = p;

  const CGFloat stepPx = datawheel ? 4.0 : 6.0;
  int inc = (int)(dragAccu / stepPx);
  if( inc ) {
    dragAccu -= inc * stepPx;
    while( inc > 3 )  { [self turn:3];  inc -= 3; }
    while( inc < -3 ) { [self turn:-3]; inc += 3; }
    [self turn:inc];
  }
}

- (void)scrollWheel:(NSEvent *)event
{
  CGFloat d = [event hasPreciseScrollingDeltas] ? [event scrollingDeltaY] / 8.0 : [event deltaY];
  if( [event isDirectionInvertedFromDevice] )
    d = -d;
  scrollAccu += d;
  int inc = (int)scrollAccu;
  if( inc ) {
    scrollAccu -= inc;
    if( inc > 3 ) inc = 3;
    if( inc < -3 ) inc = -3;
    [self turn:inc];
  }
}

- (void)drawRect:(NSRect)dirtyRect
{
  NSRect b = [self bounds];
  CGFloat d = MIN(b.size.width, b.size.height) - 8.0;
  NSPoint c = NSMakePoint(NSMidX(b), NSMidY(b));
  NSRect r = NSMakeRect(c.x - d/2, c.y - d/2, d, d);
  CGFloat rad = d / 2;

  // drop shadow on the panel
  [NSGraphicsContext saveGraphicsState];
  NSShadow *sh = [[[NSShadow alloc] init] autorelease];
  [sh setShadowColor:[NSColor colorWithCalibratedWhite:0 alpha:0.85]];
  [sh setShadowBlurRadius:datawheel ? 9.0 : 4.0];
  [sh setShadowOffset:NSMakeSize(datawheel ? 2.0 : 1.0, datawheel ? -5.0 : -3.0)];
  [sh set];
  [rgb(10, 10, 11) set];
  [[NSBezierPath bezierPathWithOvalInRect:r] fill];
  [NSGraphicsContext restoreGraphicsState];

  // skirt / outer body
  NSBezierPath *outer = [NSBezierPath bezierPathWithOvalInRect:r];
  NSGradient *og = [[[NSGradient alloc] initWithColorsAndLocations:
                      rgb(70, 70, 74), 0.0, rgb(24, 24, 26), 0.55, rgb(8, 8, 9), 1.0, nil] autorelease];
  [og drawInBezierPath:outer angle:-60];

  if( !datawheel ) {
    // knurled grip: fine radial ridges on the rim
    CGFloat inner = rad * 0.80;
    int ridges = 36;
    for(int i=0; i<ridges; ++i) {
      CGFloat a = angle + i * 2*M_PI/ridges;
      CGFloat light = 0.5 + 0.5 * cos(a + M_PI/4); // light from upper left
      [[NSColor colorWithCalibratedWhite:0.08 + 0.32*light alpha:0.9] set];
      NSBezierPath *ln = [NSBezierPath bezierPath];
      [ln moveToPoint:NSMakePoint(c.x + sin(a)*inner, c.y + cos(a)*inner)];
      [ln lineToPoint:NSMakePoint(c.x + sin(a)*(rad-0.8), c.y + cos(a)*(rad-0.8))];
      [ln setLineWidth:1.1];
      [ln stroke];
    }

    // cap (top surface)
    CGFloat capR = rad * 0.78;
    NSRect capRect = NSMakeRect(c.x - capR, c.y - capR, 2*capR, 2*capR);
    NSBezierPath *cap = [NSBezierPath bezierPathWithOvalInRect:capRect];
    NSGradient *cg = [[[NSGradient alloc] initWithColorsAndLocations:
                        rgb(64, 64, 68), 0.0, rgb(30, 30, 33), 0.5, rgb(14, 14, 15), 1.0, nil] autorelease];
    [cg drawInBezierPath:cap relativeCenterPosition:NSMakePoint(-0.35, 0.45)];
    [[NSColor colorWithCalibratedWhite:0 alpha:0.6] set];
    [cap setLineWidth:0.8];
    [cap stroke];

    // indicator line
    NSBezierPath *ind = [NSBezierPath bezierPath];
    [ind moveToPoint:NSMakePoint(c.x + sin(angle)*capR*0.35, c.y + cos(angle)*capR*0.35)];
    [ind lineToPoint:NSMakePoint(c.x + sin(angle)*capR*0.92, c.y + cos(angle)*capR*0.92)];
    [ind setLineWidth:2.0];
    [ind setLineCapStyle:NSRoundLineCapStyle];
    [rgb(225, 225, 225) set];
    [ind stroke];
  } else {
    // datawheel: large smooth wheel with a satin face and a finger dimple
    CGFloat faceR = rad * 0.93;
    NSRect faceRect = NSMakeRect(c.x - faceR, c.y - faceR, 2*faceR, 2*faceR);
    NSBezierPath *face = [NSBezierPath bezierPathWithOvalInRect:faceRect];
    NSGradient *fg = [[[NSGradient alloc] initWithColorsAndLocations:
                        rgb(46, 46, 50), 0.0, rgb(24, 24, 27), 0.55, rgb(12, 12, 13), 1.0, nil] autorelease];
    [fg drawInBezierPath:face relativeCenterPosition:NSMakePoint(-0.3, 0.4)];

    // satin rings
    for(int i=1; i<6; ++i) {
      CGFloat rr = faceR * (0.2 + 0.15*i);
      [[NSColor colorWithCalibratedWhite:1.0 alpha:0.025] set];
      NSBezierPath *ring = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(c.x-rr, c.y-rr, 2*rr, 2*rr)];
      [ring setLineWidth:0.8];
      [ring stroke];
    }

    // edge highlight
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.10] set];
    [face setLineWidth:1.2];
    [face stroke];

    // finger dimple
    CGFloat dimR = rad * 0.17;
    CGFloat dimDist = rad * 0.62;
    NSPoint dc = NSMakePoint(c.x + sin(angle)*dimDist, c.y + cos(angle)*dimDist);
    NSRect dimRect = NSMakeRect(dc.x - dimR, dc.y - dimR, 2*dimR, 2*dimR);
    NSBezierPath *dim = [NSBezierPath bezierPathWithOvalInRect:dimRect];
    NSGradient *dg = [[[NSGradient alloc] initWithColorsAndLocations:
                        rgb(8, 8, 9), 0.0, rgb(28, 28, 31), 0.7, rgb(60, 60, 64), 1.0, nil] autorelease];
    [dg drawInBezierPath:dim relativeCenterPosition:NSMakePoint(0.3, -0.4)];
  }
}

@end


/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
// LCD (2x40 character display, scaled to the frame)
/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
@interface WilbaLcd : CLcdView
- (NSString *)lineText:(int)line;
@end

@implementation WilbaLcd

- (NSString *)lineText:(int)line
{
  if( !cLcd || line >= cLcd->getLcdLines() )
    return @"";
  char buffer[LCD_MAX_COLUMNS+1];
  int n = cLcd->getLcdColumns();
  for(int i=0; i<n; ++i) {
    unsigned char c = cLcd->lcdScreen[line][i];
    buffer[i] = (c >= 32 && c < 127) ? c : '#'; // special characters (e.g. bars) as '#'
  }
  buffer[n] = 0;
  return [NSString stringWithUTF8String:buffer];
}

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame:frameRect];
  if( self ) {
    // same defaults as CLcdView awakeFromNib
    lcdCharWidth = 6;
    lcdCharHeight = 8;
    lcdOffsetColumns = 0;
    lcdOffsetLines = 4;
    lcdPixelX = 2;
    lcdPixelY = 2;
    lcdBorderX = 4;
    lcdBorderY = 8;
  }
  return self;
}

- (void)drawRect:(NSRect)rect
{
  if( !cLcd )
    return;
  // scale the native LCD size into the frame
  CGFloat sx = [self bounds].size.width / (CGFloat)[self getLcdSizeX];
  CGFloat sy = [self bounds].size.height / (CGFloat)[self getLcdSizeY];
  CGContextRef ctx = (CGContextRef)[[NSGraphicsContext currentContext] CGContext];
  CGContextSaveGState(ctx);
  CGContextScaleCTM(ctx, sx, sy);
  [super drawRect:rect];
  CGContextRestoreGState(ctx);
}

@end


/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
// Panel (background, screws, labels, LCD bezels)
/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
typedef struct {
  const char *text;
  CGFloat x, y;     // centre position (photo coordinates)
  int vertical;     // 1: rotated by 90 degree
  CGFloat size;     // font size (photo pixels)
} panel_label_t;

@interface WilbaPanelView : NSView {
@public
  NSMutableArray *labels; // NSArray of NSValue wrapping index into static table
}
@end

static panel_label_t panel_labels[256];
static int num_panel_labels = 0;

static void addLabel(const char *text, CGFloat x, CGFloat y, int vertical = 0, CGFloat size = 6.6)
{
  if( num_panel_labels >= 256 )
    return;
  panel_label_t *l = &panel_labels[num_panel_labels++];
  l->text = text; l->x = x; l->y = y; l->vertical = vertical; l->size = size;
}

@implementation WilbaPanelView

- (BOOL)isFlipped { return YES; }

static void drawScrew(NSPoint c, CGFloat r, CGFloat slotAngle)
{
  // countersink
  NSRect hole = NSMakeRect(c.x - r - 2, c.y - r - 2, 2*r + 4, 2*r + 4);
  NSGradient *hg = [[[NSGradient alloc] initWithStartingColor:rgb(10, 10, 11) endingColor:rgb(60, 62, 66)] autorelease];
  [hg drawInBezierPath:[NSBezierPath bezierPathWithOvalInRect:hole] angle:-90];

  NSRect head = NSMakeRect(c.x - r, c.y - r, 2*r, 2*r);
  NSBezierPath *hp = [NSBezierPath bezierPathWithOvalInRect:head];
  NSGradient *g = [[[NSGradient alloc] initWithColorsAndLocations:
                     rgb(150, 152, 156), 0.0, rgb(92, 94, 98), 0.5, rgb(48, 50, 54), 1.0, nil] autorelease];
  [g drawInBezierPath:hp relativeCenterPosition:NSMakePoint(-0.3, -0.4)];

  // hex socket
  NSBezierPath *hex = [NSBezierPath bezierPath];
  for(int i=0; i<6; ++i) {
    CGFloat a = slotAngle + i * M_PI/3;
    NSPoint p = NSMakePoint(c.x + cos(a)*r*0.45, c.y + sin(a)*r*0.45);
    if( i == 0 ) [hex moveToPoint:p]; else [hex lineToPoint:p];
  }
  [hex closePath];
  [rgb(22, 22, 24) set];
  [hex fill];
}

- (void)drawRect:(NSRect)dirtyRect
{
  NSRect b = [self bounds];

  // anodised aluminium panel
  NSGradient *bg = [[[NSGradient alloc] initWithColorsAndLocations:
                      rgb(64, 66, 70), 0.0, rgb(50, 52, 56), 0.45, rgb(40, 41, 44), 1.0, nil] autorelease];
  [bg drawInRect:b angle:90];

  // brushed metal: fine horizontal hairlines
  srandom(4711);
  for(CGFloat y=0; y<b.size.height; y+=1.0) {
    CGFloat a = 0.012 + (random() % 100) / 100.0 * 0.03;
    [[NSColor colorWithCalibratedWhite:((random() & 1) ? 1.0 : 0.0) alpha:a] set];
    NSRectFillUsingOperation(NSMakeRect(0, y, b.size.width, 1.0), NSCompositingOperationSourceOver);
  }

  // bevelled edge
  [[NSColor colorWithCalibratedWhite:1.0 alpha:0.12] set];
  NSFrameRectWithWidth(NSInsetRect(b, 0.5, 0.5), 1.0);
  [[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
  NSFrameRectWithWidth(NSMakeRect(0, b.size.height - 2, b.size.width, 2), 2.0);

  // rack screws
  drawScrew(NSMakePoint(PX(60),   PY(125)), 7.5*S, 0.3);
  drawScrew(NSMakePoint(PX(60),   PY(253)), 7.5*S, 1.1);
  drawScrew(NSMakePoint(PX(1124), PY(125)), 7.5*S, 0.7);
  drawScrew(NSMakePoint(PX(1124), PY(253)), 7.5*S, 0.1);
  drawScrew(NSMakePoint(PX(100),  PY(125)), 3.2*S, 0.5);
  drawScrew(NSMakePoint(PX(100),  PY(253)), 3.2*S, 0.9);
  drawScrew(NSMakePoint(PX(1085), PY(125)), 3.2*S, 0.2);
  drawScrew(NSMakePoint(PX(1085), PY(253)), 3.2*S, 0.6);

  // LCD bezels (black window with a slight inner shadow)
  NSRect lcdBezels[2] = {
    NSMakeRect(PX(266), PY(68), 362*S, 40*S),
    NSMakeRect(PX(683), PY(68), 362*S, 40*S),
  };
  for(int i=0; i<2; ++i) {
    NSBezierPath *bz = [NSBezierPath bezierPathWithRoundedRect:lcdBezels[i] xRadius:3 yRadius:3];
    [rgb(6, 6, 7) set];
    [bz fill];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.10] set];
    [bz setLineWidth:1.0];
    [bz stroke];
  }

  // labels
  NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle alloc] init] autorelease];
  [ps setAlignment:NSTextAlignmentCenter];
  for(int i=0; i<num_panel_labels; ++i) {
    panel_label_t *l = &panel_labels[i];
    NSFont *font = [NSFont fontWithName:@"HelveticaNeue-Medium" size:l->size * S];
    if( !font ) font = [NSFont boldSystemFontOfSize:l->size * S];
    NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:
                            font, NSFontAttributeName,
                            rgb(222, 222, 222), NSForegroundColorAttributeName,
                            [NSNumber numberWithFloat:0.6], NSKernAttributeName,
                            ps, NSParagraphStyleAttributeName, nil];
    NSString *s = [NSString stringWithUTF8String:l->text];
    NSSize sz = [s sizeWithAttributes:attr];
    NSPoint c = NSMakePoint(PX(l->x), PY(l->y));
    if( l->vertical ) {
      [NSGraphicsContext saveGraphicsState];
      NSAffineTransform *t = [NSAffineTransform transform];
      [t translateXBy:c.x yBy:c.y];
      [t rotateByDegrees:-90];
      [t concat];
      [s drawAtPoint:NSMakePoint(-sz.width/2, -sz.height/2) withAttributes:attr];
      [NSGraphicsContext restoreGraphicsState];
    } else {
      [s drawAtPoint:NSMakePoint(c.x - sz.width/2, c.y - sz.height/2) withAttributes:attr];
    }
  }
}

@end


/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
// Panel construction
/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
static NSMutableArray *allLeds = nil;
static NSMutableDictionary *namedKeys = nil;  // name -> WilbaKey (for test scripts)
static NSMutableDictionary *namedKnobs = nil; // encoder number -> WilbaKnob
static WilbaPanelView *panelView = nil;
static NSWindow *panelWindow = nil;
static WilbaLcd *lcdViews[2] = { nil, nil };

static void addKey(CGFloat x, CGFloat y, int row, int pin, const char *name)
{
  CGFloat w = (KEY_W + 6) * S, h = (KEY_H + 6) * S;
  WilbaKey *k = [[WilbaKey alloc] initWithFrame:NSMakeRect(PX(x) - w/2, PY(y) - h/2, w, h)];
  k->row = row;
  k->pin = pin;
  [panelView addSubview:k];
  if( name )
    [namedKeys setObject:k forKey:[[NSString stringWithUTF8String:name] uppercaseString]];
}

static void addLed(CGFloat x, CGFloat y, led_type_t type, int row, int pin, int gp = 0)
{
  CGFloat d = 9.0 * S + 8.0;
  WilbaLed *l = [[WilbaLed alloc] initWithFrame:NSMakeRect(PX(x) - d/2, PY(y) - d/2, d, d)];
  l->type = type;
  l->row = row;
  l->pin = pin;
  l->gp = gp;
  l->lastState = -1;
  [panelView addSubview:l];
  [allLeds addObject:l];
}

static void addKnob(CGFloat x, CGFloat y, CGFloat diameter, int encoder, BOOL datawheel)
{
  CGFloat d = diameter * S + 8.0;
  WilbaKnob *k = [[WilbaKnob alloc] initWithFrame:NSMakeRect(PX(x) - d/2, PY(y) - d/2, d, d)];
  k->encoder = encoder;
  k->datawheel = datawheel;
  k->angle = datawheel ? -0.6 : 0.0;
  [panelView addSubview:k];
  [namedKnobs setObject:k forKey:[NSNumber numberWithInt:encoder]];
}

@implementation WilbaPanel

+ (void)createWindowWithLcdLeft:(CLcdView **)lcdLeft lcdRight:(CLcdView **)lcdRight
{
  allLeds = [[NSMutableArray alloc] init];
  namedKeys = [[NSMutableDictionary alloc] init];
  namedKnobs = [[NSMutableDictionary alloc] init];
  num_panel_labels = 0;

  NSRect frame = NSMakeRect(0, 0, PANEL_W * S, PANEL_H * S);
  panelView = [[WilbaPanelView alloc] initWithFrame:frame];

  ///////////////////////////////////////////////////////////////////////////
  // left cluster: track groups / tracks / trigger layers / parameter layers
  ///////////////////////////////////////////////////////////////////////////
  addLabel("TRACK GROUP", 136, 104, 1, 6.0);
  addLabel("TRACK",       191,  92, 1, 6.0);
  addLabel("TRIGGER LAYER",   136, 262, 1, 6.0);
  addLabel("PARAMETER LAYER", 191, 262, 1, 6.0);

  {
    // groups: buttons M8:6, M8:7, M6:6, M6:7; LEDs M8:3, M8:2, M8:1, M8:0
    const int btn[4][2] = { {8,6}, {8,7}, {6,6}, {6,7} };
    const int led[4][2] = { {8,3}, {8,2}, {8,1}, {8,0} };
    // tracks: buttons M7:6, M7:7, M5:6, M5:7; LEDs M7:2, M7:1, M5:2, M5:1
    const int tbtn[4][2] = { {7,6}, {7,7}, {5,6}, {5,7} };
    const int tled[4][2] = { {7,2}, {7,1}, {5,2}, {5,1} };
    static const char *num[4] = { "1", "2", "3", "4" };
    for(int i=0; i<4; ++i) {
      CGFloat yl = 73 + i*32;
      CGFloat yb = 88 + i*32;
      addLed(150, yl, LED_GREEN, led[i][0], led[i][1]);
      addLabel(num[i], 162, yl);
      char gname[16]; sprintf(gname, "GROUP%d", i+1);
      addKey(153, yb, btn[i][0], btn[i][1], gname);
      addLed(205, yl, LED_GREEN, tled[i][0], tled[i][1]);
      addLabel(num[i], 217, yl);
      char tname[16]; sprintf(tname, "TRACK%d", i+1);
      addKey(208, yb, tbtn[i][0], tbtn[i][1], tname);
    }
  }

  {
    // trigger layers: buttons M2:6, M2:7, M1:6; LEDs M2:2, M2:1, M2:0
    const int btn[3][2] = { {2,6}, {2,7}, {1,6} };
    const int led[3][2] = { {2,2}, {2,1}, {2,0} };
    // parameter layers: buttons M4:6, M4:7, M3:6; LEDs M4:2, M4:1, M4:0
    const int pbtn[3][2] = { {4,6}, {4,7}, {3,6} };
    const int pled[3][2] = { {4,2}, {4,1}, {4,0} };
    static const char *abc[3] = { "A", "B", "C" };
    for(int i=0; i<3; ++i) {
      CGFloat yl = 224 + i*31;
      CGFloat yb = 240 + i*31;
      addLed(150, yl, LED_GREEN, led[i][0], led[i][1]);
      addLabel(abc[i], 162, yl);
      char lname[16]; sprintf(lname, "TRG_%s", abc[i]);
      addKey(153, yb, btn[i][0], btn[i][1], lname);
      addLed(205, yl, LED_GREEN, pled[i][0], pled[i][1]);
      addLabel(abc[i], 217, yl);
      sprintf(lname, "PAR_%s", abc[i]);
      addKey(208, yb, pbtn[i][0], pbtn[i][1], lname);
    }
  }

  ///////////////////////////////////////////////////////////////////////////
  // GP section: encoders, GP LEDs (duo colour), GP buttons
  ///////////////////////////////////////////////////////////////////////////
  {
    static const char *gpNum[16] = { "1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16" };
    static const char *gpLabel[16] = { "MIXER", "EVENT", "MODE", "DIRECTION", "DIVIDER", "LENGTH", "TRANSPOSE", "GROOVE",
                                       "TRIGGER", "FX", "MANUAL", "MORPH", "BPM", "SAVE", "MIDI", "SYS EX" };
    // GP buttons: M5:0 M5:1 M6:0 M6:1 M7:0 M7:1 M8:0 M8:1 M4:0 M4:1 M3:0 M3:1 M2:0 M2:1 M1:0 M1:1
    static const int gpBtn[16][2] = { {5,0},{5,1},{6,0},{6,1},{7,0},{7,1},{8,0},{8,1},
                                      {4,0},{4,1},{3,0},{3,1},{2,0},{2,1},{1,0},{1,1} };
    for(int gp=1; gp<=16; ++gp) {
      CGFloat x = (gp <= 8) ? ENC_X_L[gp-1] : ENC_X_R[gp-9];
      addKnob(x, 151, 31, gp, NO);
      addLabel(gpNum[gp-1], x, 172);
      addLed(x, 184, LED_DUO_GP, 0, 0, gp);
      char gpname[16]; sprintf(gpname, "GP%d", gp);
      addKey(x, 199, gpBtn[gp-1][0], gpBtn[gp-1][1], gpname);
      addLabel(gpLabel[gp-1], x, 214);
    }
  }

  // Beat LED (red)
  addLed(651, 198, LED_RED, 1, 1);
  addLabel("BEAT", 651, 214);

  ///////////////////////////////////////////////////////////////////////////
  // lower left: two rows of function buttons
  ///////////////////////////////////////////////////////////////////////////
  {
    static const char *row2[7] = { "EDIT", "MUTE", "PATTERN", "SONG", "COPY", "PASTE", "CLEAR" };
    static const int row2Btn[7][2] = { {5,3}, {6,2}, {6,3}, {7,2}, {7,3}, {8,2}, {8,3} };
    static const int row2Led[7][2] = { {5,3}, {6,3}, {6,2}, {7,3}, {0,0}, {0,0}, {0,0} };
    static const char *row3[7] = { "STEP VIEW", "SOLO", "FAST", "ALL", "MENU", "SELECT", "EXIT" };
    static const int row3Btn[7][2] = { {5,5}, {6,4}, {6,5}, {7,4}, {7,5}, {8,4}, {8,5} };
    static const int row3Led[7][2] = { {3,1}, {6,1}, {6,0}, {7,0}, {0,0}, {0,0}, {0,0} };
    for(int i=0; i<7; ++i) {
      CGFloat x = ENC_X_L[i];
      if( row2Led[i][0] ) addLed(x, 236, LED_GREEN, row2Led[i][0], row2Led[i][1]);
      addKey(x, 251, row2Btn[i][0], row2Btn[i][1], row2[i]);
      addLabel(row2[i], x, 266);
      if( row3Led[i][0] ) addLed(x, 288, LED_GREEN, row3Led[i][0], row3Led[i][1]);
      addKey(x, 303, row3Btn[i][0], row3Btn[i][1], (i == 0) ? "STEP_VIEW" : row3[i]);
      addLabel(row3[i], x, 319);
    }
  }

  ///////////////////////////////////////////////////////////////////////////
  // lower right: navigation, F keys and transport
  ///////////////////////////////////////////////////////////////////////////
  {
    static const char *row2[7] = { "▽", "△", "UTILITY", "F1", "F2", "F3", "F4" };
    // DOWN M4:2, UP M4:3, UTILITY M3:2, F1 (TRACK_SEL) M3:3, F2 (LIVE) M2:2, F3 (RECORD) M2:3, F4 (SAVE_ALL) M1:2
    static const int row2Btn[7][2] = { {4,2}, {4,3}, {3,2}, {3,3}, {2,2}, {2,3}, {1,2} };
    static const char *row3[7] = { "SCRUB", "METRONOME", "◁◁", "□", "❙❙", "▷", "▷▷" };
    // SCRUB M4:4, METRONOME M4:5, REW M3:4, STOP M3:5, PAUSE M2:4, PLAY M2:5, FWD M1:4
    static const int row3Btn[7][2] = { {4,4}, {4,5}, {3,4}, {3,5}, {2,4}, {2,5}, {1,4} };
    static const char *row2Name[7] = { "DOWN", "UP", "UTILITY", "F1", "F2", "F3", "F4" };
    static const char *row3Name[7] = { "SCRUB", "METRONOME", "REW", "STOP", "PAUSE", "PLAY", "FWD" };
    // LEDs: REW M3:2, STOP M3:3, PAUSE M2:3, PLAY M1:3, FWD M1:2
    static const int row3Led[7][2] = { {0,0}, {0,0}, {3,2}, {3,3}, {2,3}, {1,3}, {1,2} };
    for(int i=0; i<7; ++i) {
      CGFloat x = ENC_X_R[i+1];
      addKey(x, 251, row2Btn[i][0], row2Btn[i][1], row2Name[i]);
      addLabel(row2[i], x, 266, 0, (i < 2) ? 8.0 : 6.6);
      if( row3Led[i][0] ) addLed(x, 288, LED_GREEN, row3Led[i][0], row3Led[i][1]);
      addKey(x, 303, row3Btn[i][0], row3Btn[i][1], row3Name[i]);
      addLabel(row3[i], x, 319, 0, (i >= 2) ? 7.5 : 6.6);
    }
  }

  // datawheel
  addKnob(652, 272, 88, 0, YES);

  ///////////////////////////////////////////////////////////////////////////
  // LCDs
  ///////////////////////////////////////////////////////////////////////////
  WilbaLcd *left  = [[WilbaLcd alloc] initWithFrame:NSMakeRect(PX(271), PY(71), 352*S, 34*S)];
  WilbaLcd *right = [[WilbaLcd alloc] initWithFrame:NSMakeRect(PX(688), PY(71), 352*S, 34*S)];
  [panelView addSubview:left];
  [panelView addSubview:right];
  *lcdLeft = left;
  *lcdRight = right;
  lcdViews[0] = left;
  lcdViews[1] = right;

  ///////////////////////////////////////////////////////////////////////////
  // Window
  ///////////////////////////////////////////////////////////////////////////
  panelWindow = [[NSWindow alloc] initWithContentRect:frame
                                            styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
                                              backing:NSBackingStoreBuffered
                                                defer:NO];
#ifdef MBSEQV4P
  [panelWindow setTitle:@"MIDIbox SEQ V4 Emulator \u2013 Wilba Frontpanel \u2013 Firmware V4+ (STM32F4 Core)"];
#else
  [panelWindow setTitle:@"MIDIbox SEQ V4 Emulator \u2013 Wilba Frontpanel \u2013 Firmware V4 (STM32F1/LPC17 Core)"];
#endif
  [panelWindow setContentView:panelView];
  [panelWindow setBackgroundColor:rgb(40, 41, 44)];
  [panelWindow center];
  [panelWindow makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
}

/////////////////////////////////////////////////////////////////////////////
// Test scripts (environment variable MBSEQ_EMU_SCRIPT=<file>)
// Lines:  press <NAME> [ms]   e.g. press MENU, press GP3, press TRACK2, press PLAY
//         hold <NAME> / release <NAME>
//         enc <0..16> <incrementer>   (0 = datawheel)
//         wait <ms>
//         lcd                         prints the content of both LCDs to stderr
//         # comment
// The script file can also be a named pipe (mkfifo) for interactive control:
//   echo "press MENU" > /path/to/fifo
// Each action is executed on the main thread with the same objects which are
// used by the mouse, so the complete path panel -> matrix -> firmware is tested.
/////////////////////////////////////////////////////////////////////////////
+ (void)scriptKey:(NSArray *)args
{
  WilbaKey *k = [namedKeys objectForKey:[[args objectAtIndex:0] uppercaseString]];
  if( !k ) { fprintf(stderr, "[EMU-SCRIPT] unknown key '%s'\n", [[args objectAtIndex:0] UTF8String]); return; }
  [k setPressed:[[args objectAtIndex:1] boolValue]];
}

+ (void)scriptEnc:(NSArray *)args
{
  WilbaKnob *k = [namedKnobs objectForKey:[NSNumber numberWithInt:[[args objectAtIndex:0] intValue]]];
  if( !k ) { fprintf(stderr, "[EMU-SCRIPT] unknown encoder '%s'\n", [[args objectAtIndex:0] UTF8String]); return; }
  [k turn:[[args objectAtIndex:1] intValue]];
}

+ (void)scriptLcd:(id)unused
{
  for(int line=0; line<2; ++line)
    fprintf(stderr, "[EMU-LCD] |%s|%s|\n", [[lcdViews[0] lineText:line] UTF8String], [[lcdViews[1] lineText:line] UTF8String]);
}

+ (void)runScriptThread:(NSString *)path
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  // the script can also be a named pipe (mkfifo): then commands are read
  // interactively, the pipe is re-opened whenever a writer has closed it
  struct stat st;
  BOOL isFifo = (stat([path fileSystemRepresentation], &st) == 0) && S_ISFIFO(st.st_mode);

  do {
    FILE *f = fopen([path fileSystemRepresentation], "r");
    if( !f ) {
      fprintf(stderr, "[EMU-SCRIPT] can't read %s\n", [path UTF8String]);
      break;
    }
    char lineBuffer[512];
    while( fgets(lineBuffer, sizeof(lineBuffer), f) ) {
      NSAutoreleasePool *linePool = [[NSAutoreleasePool alloc] init];
      NSString *line = [[NSString stringWithUTF8String:lineBuffer] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
      if( [line length] == 0 || [line hasPrefix:@"#"] ) {
        [linePool release];
        continue;
      }
      NSArray *w = [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
      NSString *cmd = [[w objectAtIndex:0] lowercaseString];
      fprintf(stderr, "[EMU-SCRIPT] %s\n", [line UTF8String]);
      if( [cmd isEqualToString:@"wait"] && [w count] >= 2 ) {
        [NSThread sleepForTimeInterval:[[w objectAtIndex:1] intValue] / 1000.0];
      } else if( ([cmd isEqualToString:@"press"] || [cmd isEqualToString:@"hold"] || [cmd isEqualToString:@"release"]) && [w count] >= 2 ) {
        NSString *name = [w objectAtIndex:1];
        if( ![cmd isEqualToString:@"release"] ) {
          [self performSelectorOnMainThread:@selector(scriptKey:) withObject:[NSArray arrayWithObjects:name, @"1", nil] waitUntilDone:YES];
        }
        if( [cmd isEqualToString:@"press"] ) {
          int ms = ([w count] >= 3) ? [[w objectAtIndex:2] intValue] : 120;
          [NSThread sleepForTimeInterval:ms / 1000.0];
        }
        if( ![cmd isEqualToString:@"hold"] ) {
          [self performSelectorOnMainThread:@selector(scriptKey:) withObject:[NSArray arrayWithObjects:name, @"0", nil] waitUntilDone:YES];
          [NSThread sleepForTimeInterval:0.08];
        }
      } else if( [cmd isEqualToString:@"lcd"] ) {
        [NSThread sleepForTimeInterval:0.15]; // let the UI task update the LCD
        [self performSelectorOnMainThread:@selector(scriptLcd:) withObject:nil waitUntilDone:YES];
      } else if( [cmd isEqualToString:@"enc"] && [w count] >= 3 ) {
        [self performSelectorOnMainThread:@selector(scriptEnc:) withObject:[NSArray arrayWithObjects:[w objectAtIndex:1], [w objectAtIndex:2], nil] waitUntilDone:YES];
        [NSThread sleepForTimeInterval:0.05];
      } else {
        fprintf(stderr, "[EMU-SCRIPT] unknown command: %s\n", [line UTF8String]);
      }
      fflush(stderr);
      [linePool release];
    }
    fclose(f);
    fprintf(stderr, "[EMU-SCRIPT] done\n");
    fflush(stderr);
  } while( isFifo );

  [pool release];
}

+ (void)runScript:(NSString *)path
{
  [NSThread detachNewThreadSelector:@selector(runScriptThread:) toTarget:self withObject:path];
}

+ (void)periodicUpdate
{
  for(WilbaLed *l in allLeds)
    [l refresh];
}

@end
