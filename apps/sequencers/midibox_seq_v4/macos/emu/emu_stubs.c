// $Id$
/*
 * EMU: functions which are required by the current firmware, but which are
 * not provided by the (older) MacOS emulation wrappers
 */

#include <mios32.h>
#include "tasks.h"

// located in ../mios32/tasks.c for the real hardware
void TASKS_MUTEX_MIDIOUT_Take(void) { MUTEX_MIDIOUT_TAKE; }
void TASKS_MUTEX_MIDIOUT_Give(void) { MUTEX_MIDIOUT_GIVE; }
void TASKS_MUTEX_MIDIIN_Take(void)  { MUTEX_MIDIIN_TAKE; }
void TASKS_MUTEX_MIDIIN_Give(void)  { MUTEX_MIDIIN_GIVE; }

// all emulated UARTs are used as MIDI ports
s32 MIOS32_UART_IsAssignedToMIDI(u8 uart)
{
  return (uart < MIOS32_UART_NUM) ? 1 : 0;
}
