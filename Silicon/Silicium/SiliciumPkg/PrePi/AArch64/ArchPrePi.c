/**
  Copyright (c) 2011-2017, ARM Limited. All rights reserved.
  Modified for EL2 Support by Hamza - Stable Version
  SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include <Library/ArmLib.h>
#include <Library/BaseLib.h>

VOID
ArchInitialize ()
{
  // 1. Enable Floating Point Unit (VFP)
  ArmEnableVFP ();

  // 2. Check current Exception Level
  UINTN CurrentEL = ArmReadCurrentEL ();

  // Apply EL2 configurations only if we are in EL2
  if (CurrentEL == AARCH64_EL2) {
    UINT64 HcrVal;

    // Read Hypervisor Configuration Register (EL2)
    asm volatile("mrs %0, hcr_el2" : "=r" (HcrVal));

    /* Configuration:
       - Clear TGE: Ensure the host kernel can receive interrupts.
       - Note: E2H (VHE) is omitted here to prevent early memory map conflicts
         during the UEFI boot phase. Let the Linux kernel handle VHE transition.
    */
    HcrVal &= ~ARM_HCR_TGE; 

    // Write back to HCR_EL2
    asm volatile("msr hcr_el2, %0" : : "r" (HcrVal));

    // 3. System Timer Access Configuration
    // Allow EL1 and Guest OS to access physical counter and timer
    ArmWriteCntHctl (0x3);

    /* 4. CPTR_EL2: Disable Floating Point and SIMD Traps.
       Using 'xzr' (zero register) is the safest method to clear all traps 
       without hitting reserved bits that trigger "System Destroyed" errors.
    */
    asm volatile("msr cptr_el2, xzr");

    // 5. Instruction Synchronization Barrier to apply changes immediately
    ArmInstructionSynchronizationBarrier();
  }
}


