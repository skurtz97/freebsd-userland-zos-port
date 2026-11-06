/*
 * z/OS link driver.
 *
 * This file exists to be empty. Its presence in the target makes
 * ibm-clang64 see a C source file on the link command, which is what
 * makes it add the Language Environment C runtime linkage. With
 * objects only, the driver adds nothing, and any archive that expects
 * the CRT -- zopen's libncursesw.a is one -- comes up short:
 *
 *   IEW2456E SYMBOL __fopen_ascii UNRESOLVED
 *   IEW2456E SYMBOL __sysconf UNRESOLVED
 *
 * Established by bisection (docs/port.md P17): the same objects and the
 * same archive link cleanly when a .c file is on the command line and
 * fail when only .obj files are.
 *
 * Deliberately includes nothing. It must not depend on pconfig.h,
 * sh.h or any z/OS header -- its whole job is to be a source file on
 * the command line, and an include would only add ways to fail.
 *
 * Do not delete this because it looks empty. It is a link flag in the
 * only form CMake will pass through unchanged.
 */

#if defined(__MVS__)

/* One symbol, so that a compiler cannot discard the unit as empty. */
int zksh_zos_link_driver;

#endif /* __MVS__ */
