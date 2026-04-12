/**
  Copyright (c) 2011-2017, ARM Limited. All rights reserved.
  Modified for EL2/VHE Support by Hamza
  SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include <Library/ArmLib.h>

/* Register Definitions for VHE - Implemented by Hamza */
#define HCR_EL2_E2H (1ULL << 34)

VOID
ArchInitialize ()
{
  // Enable Floating Point
  ArmEnableVFP ();

  UINTN CurrentEL = ArmReadCurrentEL ();

  if (CurrentEL == AARCH64_EL2) {
    /* HAMZA'S VHE CONFIGURATION:
       We ensure that TGE is disabled so the Host Kernel can handle 
       its own interrupts, and E2H is enabled for VHE performance.
    */
    UINTN Hcr = ArmReadHcr ();

    // Clean TGE bit to allow OS interrupt handling
    Hcr &= ~ARM_HCR_TGE;

    // Enable Virtualization Host Extensions
    Hcr |= HCR_EL2_E2H;

    ArmWriteHcr (Hcr);

    // Give Timer access to lower levels for KVM guests
    ArmWriteCntHctl (CNTHCTL_EL2_EL1PCTEN | CNTHCTL_EL2_EL1PCEN);

    // Disable FPU traps for EL2
    ArmWriteCptrEl2 (0x33FF);
  }
}
