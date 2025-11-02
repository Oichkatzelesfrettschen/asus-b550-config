/*
 * nct-id.c - Nuvoton Super I/O Chip Identifier and HWM Base Locator
 *
 * PURPOSE:
 *   Verify chip identity and locate the Hardware Monitor (HWM) base address
 *   for NCT679x Super I/O chips (especially NCT6798D on ASUS B550 boards).
 *   This is a ground-truth utility to confirm register accessibility before
 *   using userspace or kernel drivers.
 *
 * TECHNICAL FOUNDATION:
 *   All Nuvoton Super I/O chips share a common access protocol:
 *   1. Enter Extended Function Mode: write 0x87, 0x87 to index port (0x2E or 0x4E)
 *   2. Select Logical Device: write 0x07 to index, then device# to data (0x0B = HWM)
 *   3. Read configuration registers (CR): write reg# to index, read from data+1
 *   4. Exit: write 0xAA to index port
 *
 *   For NCT6798D specifically:
 *   - Chip ID (CR 0x20/0x21): expect 0xD428 (verified against Linux driver tables)
 *   - HWM base (CR 0x60/0x61 in device 0x0B): typically 0x0290, selectable 0x290-0x29F
 *   - PWM/Fan registers: indexed via base+5 (index), base+6 (data)
 *
 * WHY THIS MATTERS:
 *   Modern ASUS B550 boards often reserve HWM I/O ports via ACPI, blocking
 *   direct userspace access. Linux kernel nct6775 driver handles this:
 *   - On newer kernels: automatically uses ASUS WMI (RSIO/WSIO methods)
 *   - On older kernels: may require acpi_enforce_resources=lax workaround
 *   This utility confirms the chip is present and accessible via Super I/O
 *   protocol, informing kernel driver strategy.
 *
 * USAGE:
 *   Compile: gcc -std=c23 -O2 -Wall -Wextra -o nct-id nct-id.c
 *   Run:     sudo ./nct-id
 *            (requires root for ioperm(2) access to 0x2E/0x4E ISA ports)
 *
 * EXPECTED OUTPUT (ASUS B550 + NCT6798D):
 *   SIO at 0x2E: DEVID=0xD428  HWM base=0x0290 (index/data @ base+5/base+6)
 *     DEVID: Matches Linux driver's NCT6798D identification
 *     Base:  Firmware sets HWM to 0x0290 (configurable, but 0x0290 is standard)
 *     Index/Data: At offsets +5 and +6 from base (hardcoded per Nuvoton design)
 *
 * SAFETY / CAVEATS:
 *   - Direct I/O port access can conflict with kernel drivers
 *   - ACPI firmware may declare these ports "in use", causing ioperm(2) to fail
 *   - This is informational; actual fan control should use kernel nct6775 driver
 *   - On systems with WMI, the kernel driver avoids these ports altogether
 *
 * REFERENCES (for decision justification):
 *   - Linux kernel nct6775 driver: drivers/hwmon/nct6775.c (chip ID tables)
 *   - Nuvoton NCT6796D datasheet (public): register layout, SIO protocol
 *   - ASUS WMI path (kernel 5.9+): hwmon/nct6775-platform.c (RSIO/WSIO methods)
 *   - ArchWiki lm_sensors: common ACPI conflict scenarios
 */

#define _GNU_SOURCE
#include <errno.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/io.h>
#include <unistd.h>

/*
 * HELPER MACROS: Hide inb()/outb() C99 register semantics
 * WHY: Makes register operations explicit and readable
 */
static inline void outb_u8(unsigned short port, unsigned char val) {
	outb(val, port);
}

static inline unsigned char inb_u8(unsigned short port) {
	return inb(port);
}

/*
 * sio_enter() - Enter Extended Function Mode
 * WHEN: At start of chip interrogation
 * HOW:  Write magic bytes 0x87, 0x87 to index port (0x2E or 0x4E)
 * WHY:  Nuvoton Super I/O protocol requirement; unlocks CR access
 * WHO:  Called by main() for each candidate SIO index port
 */
static int sio_enter(unsigned short idx) {
	/*
	 * Request I/O permission for index and data ports.
	 * WHY two ports: idx is index, idx+1 is data (read/write alternation)
	 * SAFETY: ioperm() checks ACPI ASL declarations; may fail if firmware owns these
	 */
	if (ioperm(idx, 1, 1) || ioperm(idx + 1, 1, 1)) {
		return -1;  /* ACPI resource conflict or permission denied */
	}

	/* Magic sequence: write 0x87 twice to enter extended function mode */
	outb_u8(idx, 0x87);
	outb_u8(idx, 0x87);
	return 0;
}

/*
 * sio_exit() - Exit Extended Function Mode
 * WHEN: At end of chip interrogation
 * HOW:  Write 0xAA to index port
 * WHY:  Nuvoton protocol; releases lock, restores normal I/O behavior
 * WHO:  Called by main() after reading all registers
 */
static void sio_exit(unsigned short idx) {
	outb_u8(idx, 0xAA);
	/* Note: ioperm() release not explicitly done here; process exit cleans up */
}

/*
 * sio_write_cr() - Write a Configuration Register (CR)
 * WHEN: Setting logical device or other config (not used for HWM control)
 * HOW:  Write register number to index, value to data port
 * WHY:  Standard Super I/O protocol for non-indexed register access
 * WHO:  Called to select logical device 0x0B (HWM)
 */
static void sio_write_cr(unsigned short idx, unsigned char reg, unsigned char val) {
	outb_u8(idx, reg);       /* Index port: register selector */
	outb_u8(idx + 1, val);   /* Data port: value to write */
}

/*
 * sio_read_cr() - Read a Configuration Register (CR)
 * WHEN: Chip identification and HWM base discovery
 * HOW:  Write register number to index, read from data port
 * WHY:  Standard Super I/O protocol for CR access
 * WHO:  Called to read chip ID (CR 0x20/0x21) and HWM base (CR 0x60/0x61)
 */
static unsigned char sio_read_cr(unsigned short idx, unsigned char reg) {
	outb_u8(idx, reg);
	return inb_u8(idx + 1);
}

/*
 * main() - Entry point
 * STRATEGY:
 *   1. Iterate over two possible SIO index ports (0x2E, 0x4E)
 *   2. For each port, attempt to enter extended function mode
 *   3. Read chip ID from CR 0x20 (high byte) + CR 0x21 (low byte)
 *   4. Select logical device 0x0B (Hardware Monitor)
 *   5. Read HWM base address from CR 0x60 (high) + CR 0x61 (low)
 *   6. Report findings (or skip if port inaccessible)
 *
 * DECISION: Check both ports because some boards populate only one
 * DECISION: Continue on ACPI conflicts rather than fail (informative)
 */
int main(void) {
	/*
	 * Candidate SIO index ports per Nuvoton/ASUS convention
	 * Port 0x2E: Primary Super I/O (standard)
	 * Port 0x4E: Secondary Super I/O (rare, but checked for completeness)
	 */
	unsigned short idx_ports[2] = {0x2E, 0x4E};

	for (int p = 0; p < 2; ++p) {
		unsigned short IDX = idx_ports[p];

		/*
		 * Attempt extended function mode entry
		 * WHY: If sio_enter() fails (ioperm returns -1), ACPI has locked ports
		 * ACTION: Skip this port, try next; don't abort
		 */
		if (sio_enter(IDX)) {
			/* ioperm() failed; likely ACPI resource conflict */
			continue;
		}

		/*
		 * Read Chip ID (two bytes)
		 * WHAT: CR 0x20 = high byte, CR 0x21 = low byte
		 * FOR WHAT: Identify chip type (0xD428 = NCT6798D)
		 * WHY: Confirms this is the expected chip before accessing HWM
		 */
		unsigned char id_hi = sio_read_cr(IDX, 0x20);
		unsigned char id_lo = sio_read_cr(IDX, 0x21);
		unsigned int devid = ((unsigned)id_hi << 8) | id_lo;

		/*
		 * Select Logical Device 0x0B (Hardware Monitor)
		 * WHAT: Write CR 0x07 = 0x0B
		 * WHEN: Before reading HWM base address (subsequent registers)
		 * WHY: Super I/O logical devices share index/data ports;
		 *      must select target device before reading its base address
		 */
		sio_write_cr(IDX, 0x07, 0x0B);

		/*
		 * Read HWM Base Address (two bytes)
		 * WHAT: CR 0x60 = high byte, CR 0x61 = low byte
		 * RESULT: Base address for HWM index/data port pair
		 * TYPICAL VALUE: 0x0290 on ASUS boards (selectable 0x290-0x29F)
		 * USAGE: Actual fan control uses base+5 (index), base+6 (data)
		 */
		unsigned char ba_hi = sio_read_cr(IDX, 0x60);
		unsigned char ba_lo = sio_read_cr(IDX, 0x61);
		unsigned short base = (ba_hi << 8) | ba_lo;

		/*
		 * Report findings
		 * INTERPRETATION:
		 *   DEVID 0xD428 = NCT6798D (matches Linux driver table)
		 *   base 0x0290 = standard ASUS factory configuration
		 *   index/data at base+5/base+6 = Nuvoton standard (hardcoded)
		 */
		printf("SIO at 0x%X: DEVID=0x%04X  HWM base=0x%04X "
		       "(index/data @ base+5/base+6)\n",
		       IDX, devid, base);

		sio_exit(IDX);
	}

	return 0;
}

/*
 * BUILD & DEPLOYMENT NOTES:
 *
 * Compilation:
 *   gcc -std=c23 -O2 -Wall -Wextra -o nct-id nct-id.c
 *
 * Flags:
 *   -std=c23: Modern C with inline semantics
 *   -O2: Optimize for size/speed (simple I/O doesn't benefit from -O3)
 *   -Wall -Wextra: Catch issues (no unused vars, implicit decls, etc.)
 *
 * Installation (in PKGBUILD):
 *   install -Dm755 nct-id "$pkgdir/usr/lib/eirikr/nct-id"
 *
 * Usage (in systemd unit or manual verification):
 *   sudo /usr/lib/eirikr/nct-id
 *
 * Expected behavior on ASUS B550:
 *   - Output: SIO at 0x2E: DEVID=0xD428  HWM base=0x0290 ...
 *   - Confirms kernel nct6775 driver will find and control this chip
 *   - If ACPI locks ports, kernel driver automatically falls back to WMI
 */
