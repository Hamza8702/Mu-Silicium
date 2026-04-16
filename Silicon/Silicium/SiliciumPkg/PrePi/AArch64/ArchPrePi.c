/**
  Copyright (c) 2011-2017, ARM Limited. All rights reserved.
  Modified for EL2/VHE/KVM Support by Hamza
  SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include <Library/ArmLib.h>
#include <Library/BaseLib.h>

/* Register Definitions for AArch64 */
#define HCR_EL2_E2H (1ULL << 34) // Virtualization Host Extensions Enable
#define ARM_HCR_TGE (1ULL << 27) // Trap General Exceptions

VOID
ArchInitialize ()
{
  // 1. Enable Floating Point Unit (VFP)
  ArmEnableVFP ();

  // 2. Read current Exception Level
  UINTN CurrentEL = ArmReadCurrentEL ();

  // Apply configuration only if we are running in EL2
  if (CurrentEL == AARCH64_EL2) {
    UINT64 HcrVal;

    // Read Hypervisor Configuration Register (EL2)
    asm volatile("mrs %0, hcr_el2" : "=r" (HcrVal));

    /* VHE (Virtualization Host Extension) Setup:
       - Set E2H: Run the EL2 as a host (mandatory for KVM).
       - Clear TGE: Allow the host kernel to receive its own interrupts.
    */
    HcrVal |= HCR_EL2_E2H;    // Enable VHE
    HcrVal &= ~ARM_HCR_TGE;   // Disable TGE

    // Write back to HCR_EL2
    asm volatile("msr hcr_el2, %0" : : "r" (HcrVal));

    // 3. System Timer Access Configuration
    // Allow EL1 and Guest OS to access the physical counter and timer
    // CNTHCTL_EL2_EL1PCTEN (Bit 0) | CNTHCTL_EL2_EL1PCEN (Bit 1)
    ArmWriteCntHctl (0x3);

    // 4. CPTR_EL2: Disable Floating Point and SIMD Traps
    // Using inline assembly to bypass missing library functions
    // 0x33FF: Disables all traps for FP, SIMD, and SVE
    asm volatile("msr cptr_el2, %0" : : "r" ((UINT64)0x33FF));

    // 5. Instruction Synchronization Barrier
    // Ensure all register changes take effect immediately
    ArmInstructionSynchronizationBarrier();
  }
}

