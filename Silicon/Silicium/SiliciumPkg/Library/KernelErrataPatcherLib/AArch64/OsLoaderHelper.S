/**
  Copyright (c) 2022-2023 DuoWoA authors
  SPDX-License-Identifier: MIT
**/

#include "KernelErrataPatcherLib.h"

GCC_ASM_IMPORT (KernelErrataPatcherExitBootServices)
GCC_ASM_EXPORT (ExitBootServicesWrapper)

/**
  ExitBootServicesWrapper
  This function acts as a bridge to jump into EL2 right before 
  handing over control to the Linux Kernel.
**/
ExitBootServicesWrapper:
  // Save Return Address to x2
  mov x2, x30

  /* --- START OF EL2 JUMP BRIDGE --- */
  // Read current Exception Level
  mrs x3, CurrentEL
  lsr x3, x3, #2
  cmp x3, #1
  b.ne .Lskip_el2 // If not in EL1, skip the transition logic

  // Prepare HCR_EL2 (Hypervisor Configuration Register)
  // Enable RW (AArch64) and E2H (Virtualization Host Extensions)
  mov x4, #0x30        
  msr hcr_el2, x4
  
  // Prepare SPSR (Saved Program Status Register) for EL2h (0x3c9)
  mov x4, #0x3c9
  msr spsr_el1, x4     
  
  // Set Exception Return Address to our Kernel entry point
  msr elr_el1, x2
  
  // Perform Exception Return to jump into EL2
  eret                 
  /* --- END OF EL2 JUMP BRIDGE --- */

.Lskip_el2:
  // Continue with original boot flow if already in EL2 or transition skipped
  b KernelErrataPatcherExitBootServices

