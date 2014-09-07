/*
 * MZ-80C on FPGA (Altera DE0 version)
 * MZ control routines header
 *
 * (c) Nibbles Lab. 2012
 *
 */

#ifndef MZCTRL_H_
#define MZCTRL_H_

typedef struct {
	unsigned int status;
	unsigned char kcode[32];
	unsigned int wptr;
	unsigned int rptr;
	unsigned int flagf0;
	unsigned int flage0;
	unsigned int Lshift;
	unsigned int Rshift;
} z80_t;

void int_regist(void);
void MZ_release(void);
void SaveVRAM(void);
void RestoreVRAM(void);
void MZ_Brequest(void);
void MZ_Brequest2(void);
void MZ_Brelease(void);
void MZ_BOOT(void);
void MZ_disp(unsigned int, unsigned int, unsigned char);
void MZ_msg(unsigned int, unsigned int, char *);
void MZ_msgx(unsigned int, unsigned int, char *, unsigned int);
void pout(char);
int bout(char);
void sumout(int);

#define MZ_SYS_BUTTON 0x0000
#define MZ_SYS_SW70 0x0002
#define MZ_SYS_SW98 0x0003
#define MZ_SYS_KBDT 0x0004
#define MZ_SYS_IREQ 0x0005
#define MZ_SYS_IENB 0x0006
#define MZ_SYS_STATUS 0x0007
#define MZ_SYS_CTRL 0x0007
#define MZ_CMT_POUT 0x0010
#define MZ_CMT_STATUS 0x0011
#define MZ_CMT_COUNT 0x0012
#define MZ_CMT_COUNTH 0x0013
#define MZ_CMT_CTRL 0x0014
#define MZ_VRAM 0xd000
#define MZ_CGROM 0xc800
#define MZ_KMAP 0xc000

// Interrupt from MZ
#define I_KBD 0x01
#define I_FBTN 0x02
#define I_CMT 0x04

// Status flag
#define S_FBTN 0x01
#define S_CMT 0x02
#define S_TAPE 0x04

// CMT flag
#define C_POUT 0x01
#define C_OPEN 0x01
#define C_PLAY 0x02
#define C_FF 0x04
#define C_REW 0x08
#define C_APSS 0x10
#define C_TAPE 0x01
#define C_MTON 0x02
#define C_WP 0x04
#define C_PON 0x08
#define C_ANIM 0x10

#endif /* MZCTRL_H_ */
