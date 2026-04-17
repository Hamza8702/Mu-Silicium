/**
  Copyright (c) 2011-2017, ARM Limited. All rights reserved.
  Modified for EL2/KVM Support by Hamza - Stable English Version
  SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include <Library/ArmLib.h>
#include <Library/BaseLib.h>

VOID
ArchInitialize ()
{
  // 1. Enable Floating Point Unit
  ArmEnableVFP ();

  // 2. Identify current execution level
  UINTN CurrentEL = ArmReadCurrentEL ();

  // Process EL2 specific configurations for KVM
  if (CurrentEL == AARCH64_EL2) {
    
    // 3. Reset Virtual Timer Offset
    // Essential for preventing KVM/Kernel stall during boot
    asm volatile("msr cntvoff_el2, xzr");

    // 4. GICv3 System Register Access (ICC_SRE_EL2)
    // Using UINT64 to match AArch64 register width and avoid compiler errors
    UINT64 SreVal;
    
    // S3_4_C12_C9_5 is the system register encoding for ICC_SRE_EL2
    asm volatile("mrs %0, s3_4_c12_c9_5" : "=r" (SreVal));
    SreVal |= 0x7; // Enable SRE, DFB, and ASRE bits
    asm volatile("msr s3_4_c12_c9_5, %0" : : "r" (SreVal));

    // 5. Finalize HCR_EL2
    // Ensure TGE (Trap General Exceptions) is clear for EL1 guest/host kernel
    UINT64 HcrVal;
    asm volatile("mrs %0, hcr_el2" : "=r" (HcrVal));
    HcrVal &= ~(1ULL << 27); // Clear ARM_HCR_TGE
    asm volatile("msr hcr_el2, %0" : : "r" (HcrVal));

    // Ensure all system register writes are completed
    ArmInstructionSynchronizationBarrier();
  }
}



