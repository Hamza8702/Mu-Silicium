/**
  Copyright (c) 2011-2017, ARM Limited. All rights reserved.
  Modified for EL2/KVM Support by Hamza
  SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include <Library/ArmLib.h>
#include <Library/BaseLib.h>

/**
  Initializes architecture-specific settings after EL transition.
**/
VOID
ArchInitialize ()
{
  // 1. Enable Floating Point Unit (VFP)
  ArmEnableVFP ();

  // 2. Perform EL2 configurations only if we are at the correct level
  if (ArmReadCurrentEL () == AARCH64_EL2) {

    // 3. Reset Virtual Timer Offset (CNTVOFF_EL2)
    // Mandatory for KVM to prevent virtual time drifts.
    asm volatile("msr cntvoff_el2, xzr" ::: "memory");

    // 4. Configure GICv3 System Register Access (ICC_SRE_EL2)
    // We only set the SRE bit (Bit 0). Setting bits 1 and 2 (DFB/ASRE) 
    // often causes resets on locked Qualcomm firmware.
    UINT64 SreVal;
    asm volatile("mrs %0, s3_4_c12_c9_5" : "=r" (SreVal));
    
    if (!(SreVal & 0x1)) {
        SreVal |= 0x1; // Only set Enable bit if not already set
        asm volatile("msr s3_4_c12_c9_5, %0" : : "r" (SreVal) : "memory");
        asm volatile("isb" ::: "memory");
    }

    // 5. Configure Hypervisor Configuration (HCR_EL2)
    UINT64 HcrVal;
    asm volatile("mrs %0, hcr_el2" : "=r" (HcrVal));

    HcrVal |= (1ULL << 31);   // RW=1: EL1 must be AArch64
    HcrVal &= ~(1ULL << 27);  // TGE=0: Standard EL1/EL0 execution

    asm volatile("msr hcr_el2, %0" : : "r" (HcrVal) : "memory");
    asm volatile("isb" ::: "memory");

    // 6. Synchronize all system register changes
    ArmInstructionSynchronizationBarrier();
  }
}
