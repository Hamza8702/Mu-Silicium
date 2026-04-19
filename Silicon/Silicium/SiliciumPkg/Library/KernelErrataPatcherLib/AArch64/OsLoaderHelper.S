
/**
  Copyright (c) 2022-2023 DuoWoA authors
  SPDX-License-Identifier: MIT
**/

#include "KernelErrataPatcherLib.h"

GCC_ASM_IMPORT (KernelErrataPatcherExitBootServices)
GCC_ASM_EXPORT (ExitBootServicesWrapper)

/**
  ExitBootServicesWrapper
  
  This function serves as a low-level bridge to escalate the exception level
  from EL1 to EL2 (Hypervisor Mode) immediately before the UEFI hands over 
  control to the Linux Kernel.
**/
ExitBootServicesWrapper:
  // Store the Kernel Entry Point (from x30) into x2
  mov x2, x30

  /* --- START OF EL2 ESCALATION --- */
  
  // Check current Exception Level
  mrs x3, CurrentEL
  lsr x3, x3, #2
  cmp x3, #1
  b.ne .Lskip_transition // If already in EL2/EL3, skip to original flow

  /**
   * Configure HCR_EL2 (Hypervisor Configuration Register)
   * Bit 31 (RW): 1 = Execution state is AArch64
   * Bit 34 (E2H): 1 = Virtualization Host Extensions (VHE) enabled
   * Value 0x30 sets both for modern Linux Kernels.
   */
  mov x4, #0x30        
  msr hcr_el2, x4
  isb                   // Ensure HCR_EL2 write is complete

  /**
   * Prepare SPSR_EL1 (Saved Program Status Register)
   * Value 0x3c9: Return to EL2h with all interrupts (DAIF) masked.
   */
  mov x4, #0x3c9
  msr spsr_el1, x4     
  
  /**
   * Set the Exception Return Address (ELR_EL1)
   * This is where the processor will jump after 'eret'.
   */
  msr elr_el1, x2
  
  // Final synchronization before context switch
  isb
  
  /**
   * Perform Exception Return
   * This triggers the jump from EL1 to EL2 using the spoofed SPSR/ELR.
   */
  eret                 
  
  /* --- END OF EL2 ESCALATION --- */

.Lskip_transition:
  // Resume original boot flow if transition was not required
  b KernelErrataPatcherExitBootServices
