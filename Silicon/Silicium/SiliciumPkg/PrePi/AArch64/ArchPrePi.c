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
    // Using a safe bitmask to avoid TrustZone write-protection faults.
    UINT64 SreVal;
    asm volatile("mrs %0, s3_4_c12_c9_5" : "=r" (SreVal));
    
    // Set SRE (Bit 0) and DFB/ASRE if possible. 
    // If "System Destroyed" persists, try changing 0x7 to 0x1.
    SreVal |= 0x7; 
    
    asm volatile("isb" ::: "memory");
    asm volatile("msr s3_4_c12_c9_5, %0" : : "r" (SreVal) : "memory");

    // 5. Configure Hypervisor Configuration (HCR_EL2)
    UINT64 HcrVal;
    asm volatile("mrs %0, hcr_el2" : "=r" (HcrVal));
    
    HcrVal |= (1ULL << 31);   // EL1 must be AArch64
    HcrVal &= ~(1ULL << 27);  // Clear TGE to allow EL1 host interrupts
    
    asm volatile("isb" ::: "memory");
    asm volatile("msr hcr_el2, %0" : : "r" (HcrVal) : "memory");
    asm volatile("isb" ::: "memory");

    // 6. Synchronize all system register changes
    ArmInstructionSynchronizationBarrier();
  }
}




