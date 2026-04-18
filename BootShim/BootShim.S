/*
 * BootShim for Miatoll (SM7125)
 * Optimized for EL2 Handoff and KVM Support
 * Fixed: Address relocation and register preservation
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
  .ascii "ARM\x64"      /* ARM64 Magic */
  .long 0               /* Reserved */
#endif

_Start:
  mov   x4, x1          /* Source address (where ABL loaded us) */
#if REQUIRES_KERNEL_HEADER == 1
  ldr   x5, _StackBase
#else
  ldr   x5, =FD_BASE    /* Target destination address in RAM */
#endif
  
  cmp   x4, x5
  beq   _CheckEL        /* Skip copying if already at destination */

#if REQUIRES_KERNEL_HEADER == 1
  ldr   x6, _StackSize
#else
  ldr   x6, =FD_SIZE
#endif

_CopyLoop:              /* Relocate EDK2 FD to target memory location */
  ldp   x2, x3, [x4], #16
  stp   x2, x3, [x5], #16
  subs  x6, x6, #16
  b.ne  _CopyLoop

_CheckEL:
  /* IMPORTANT: Restore x5 to the base address as it was modified in _CopyLoop */
#if REQUIRES_KERNEL_HEADER == 1
  ldr   x5, _StackBase
#else
  ldr   x5, =FD_BASE
#endif

  /* Check current Exception Level */
  mrs   x0, CurrentEL
  lsr   x0, x0, #2
  cmp   x0, #2
  b.ne  _Entry          /* If not in EL2, skip KVM setup */

_SetupKVM:
  /* * Configure HCR_EL2 (Hypervisor Configuration Register)
   * Bit 31: RW=1 (EL1 remains AArch64)
   * VHE (Bit 34) is disabled for initial boot stability
   */
  mov   x0, #(1 << 31)    
  msr   hcr_el2, x0
  isb                   /* Instruction synchronization barrier */

_Entry:
  /* * Preserve x0 (contains FDT address from ABL)
   * Clear x1-x3 for a clean EDK2 entry state
   */
  mov   x1, #0
  mov   x2, #0
  mov   x3, #0
  br    x5               /* Branch to EDK2 Entry Point */

_Dead:
  b     _Dead

.text
.align 4

_Payload:
/* EDK2 binary will be appended here during the build process */
