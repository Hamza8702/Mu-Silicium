/**
  Copyright (c) 2011-2017, ARM Limited. All rights reserved.
  Modified for EL2/KVM Support by Hamza
  Target Device: Xiaomi Miatoll (Snapdragon 720G)
  SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include <Library/ArmLib.h>
#include <Library/BaseLib.h>

/**
  ArchInitialize: Pre-Pi stage architecture initialization.
  This function configures the processor state for EL2/KVM transition.
**/
VOID
ArchInitialize ()
{
  // 1. Enable Floating Point Unit (FPU)
  // Essential to prevent exceptions during early C environment execution.
  ArmEnableVFP ();

  // 2. Read current Execution Level (EL)
  UINTN CurrentEL = ArmReadCurrentEL ();

  // Only proceed with hypervisor configurations if the processor is in EL2.
  // This prevents 'System Destroyed' errors if the EL2 transition in 
  // ModuleEntryPoint.S was unsuccessful.
  if (CurrentEL == AARCH64_EL2) {
    
    // 3. Reset Virtual Timer Offset (CNTVOFF_EL2)
    // Prevents the guest kernel from stalling during timer initialization.
    asm volatile("msr cntvoff_el2, xzr" ::: "memory");

    // 4. Configure GICv3 System Register Access (ICC_SRE_EL2)
    // S3_4_C12_C9_5 is the architectural encoding for ICC_SRE_EL2.
    UINT64 SreVal;
    
    // Read the current SRE configuration
    asm volatile("mrs %0, s3_4_c12_c9_5" : "=r" (SreVal));
    
    // Set SRE (Bit 0), DFB (Bit 1), and ASRE (Bit 2).
    // Note: If 'System Destroyed' persists, the TrustZone (EL3) might be 
    // blocking writes to this register on some Xiaomi firmware versions.
    SreVal |= 0x7; 
    
    asm volatile("isb" ::: "memory");
    asm volatile("msr s3_4_c12_c9_5, %0" : : "r" (SreVal) : "memory");

    // 5. Configure Hypervisor Configuration Register (HCR_EL2)
    // RW (Bit 31): Sets EL1 to AArch64 mode.
    // TGE (Bit 27): Must be cleared to allow EL1/Host kernel to receive exceptions.
    UINT64 HcrVal;
    asm volatile("mrs %0, hcr_el2" : "=r" (HcrVal));
    
    HcrVal |= (1ULL << 31);   // Set EL1 to AArch64
    HcrVal &= ~(1ULL << 27);  // Clear Trap General Exceptions
    
    // Ensure synchronization before and after writing to HCR_EL2
    asm volatile("isb" ::: "memory");
    asm volatile("msr hcr_el2, %0" : : "r" (HcrVal) : "memory");
    asm volatile("isb" ::: "memory");

    // 6. Final Pipeline Synchronization
    ArmInstructionSynchronizationBarrier();
  }
}




