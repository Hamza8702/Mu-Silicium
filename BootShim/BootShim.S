/*
 * BootShim for Miatoll (SM7125)
 * Optimized for EL2 Handoff and KVM Support
 * Part of Mu-Silicium Project
 */

_Head:
  adr   x1, _Payload    /* Load address of the EDK2 payload */
  b     _Start          /* Jump to initialization code */

#if REQUIRES_KERNEL_HEADER == 1
_StackBase:
  .quad FD_BASE         /* Text Offset */

_StackSize:
  .quad FD_SIZE         /* Image Size */
  .quad 0               /* Flags */
  .quad 0               /* Reserved */
  .quad 0               /* Reserved */
  .quad 0               /* Reserved */
  .ascii "ARM\x64"      /* ARM64 Magic */
  .long 0               /* Reserved */
#endif

_Start:
  mov   x4, x1          /* Source address */
#if REQUIRES_KERNEL_HEADER == 1
  ldr   x5, _StackBase
#else
  ldr   x5, =FD_BASE    /* Destination address in RAM */
#endif
  
  cmp   x4, x5
  beq   _CheckEL        /* Skip copying if already at destination */

#if REQUIRES_KERNEL_HEADER == 1
  ldr   x6,  _StackSize
#else
  ldr   x6,  =FD_SIZE
#endif

_CopyLoop:              /* Copy EDK2 FD to target memory location */
  ldp   x2, x3, [x4], #16
  stp   x2, x3, [x5], #16
  subs  x6, x6, #16
  b.ne  _CopyLoop

#if REQUIRES_KERNEL_HEADER == 1
  ldr   x5, _StackBase
#else
  ldr   x5, =FD_BASE
#endif

_CheckEL:
  /* Check current Exception Level */
  mrs   x0, CurrentEL
  lsr   x0, x0, #2
  cmp   x0, #2
  b.eq  _SetupKVM       /* If already in EL2, configure virtualization */
  b     _Entry          /* If not in EL2, jump to EDK2 directly */

_SetupKVM:
  /* * Configure HCR_EL2 (Hypervisor Configuration Register)
   * Bit 31: RW=1 (Execution state for EL1 is AArch64)
   * Bit 34: E2H=1 (Enable Virtualization Host Extensions - VHE)
   */
  mov   x0, #(1 << 31)    
  orr   x0, x0, #(1 << 34) 
  msr   hcr_el2, x0
  isb                     /* Synchronize context */

_Entry:
  /* Clear registers to ensure a clean state for EDK2 */
  mov   x0, #0
  mov   x1, #0
  mov   x2, #0
  mov   x3, #0
  br    x5               /* Jump to EDK2 Entry Point */

_Dead:
  b     _Dead

.text
.align 4

_Payload:
/* EDK2 binary will be appended here during the build process */
