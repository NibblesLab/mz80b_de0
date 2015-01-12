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
void MZ_cls(void);
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
#define MZ_FDD_CTRL 0x0000
#define MZ_FDD_TRK 0x0001
#define MZ_FDD_STEP 0x0002
#define MZ_FDD_HSEL 0x0003
#define MZ_FDD_ID 0x0004
#define MZ_FDD_LSEL 0x0005
#define MZ_FDD_DDEN 0x0006
#define MZ_FDD_MAXS 0x0007
#define MZ_FDD_TADR 0x0008
#define MZ_FDD_TALH 0x0009
#define MZ_FDD_TAHL 0x000a
#define MZ_FDD_G3 0x000c
#define MZ_FDD_G4 0x000e
#define MZ_FDD_G4H 0x000f
#define MZ_FD0_REGS 0x0040
#define MZ_FD1_REGS 0x0050
#define MZ_VRAM 0xd000
#define MZ_CGROM 0xc800
#define MZ_KMAP 0xc000

// Interrupt from MZ
#define I_KBD 0x01
#define I_FBTN 0x02
#define I_CMT 0x04
#define I_FDD 0x08

// Status flag
#define S_FBTN 0x01
#define S_CMT 0x02
#define S_TAPE 0x04
#define S_BST 0x02

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

// FDD flag
#define D_DISK 0x01
#define D_WP 0x02
#define D_D88 0x04
#define D_MF 0x08
#define D_DDEN 0x01
#define D_STEP 0x01
#define D_DIRC 0x02	// 0=Step in, 1=Step out
#define D_S128 0x00
#define D_S256 0x01
#define D_S512 0x02
#define D_S1K 0x03

#endif /* MZCTRL_H_ */
