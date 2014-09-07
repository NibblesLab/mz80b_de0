/*
 * MZ-80B on FPGA (Altera DE0 version)
 * MZ control routines
 *
 * (c) Nibbles Lab. 2013-2014
 *
 */

#include "system.h"
#include "io.h"
#include "alt_types.h"
#include <stdio.h>
#include "altera_avalon_pio_regs.h"
#include "sys/alt_irq.h"
#include "mzctrl.h"

unsigned char buvram[2000];

volatile z80_t z80_sts;

/*
 * ISR
 */
static void int_service(void* context)
{
	volatile z80_t* z80sts_pt = (volatile z80_t*)context;

	// Keyboard
	if((IORD_8DIRECT(REG_BASE, MZ_SYS_IREQ)&I_KBD)==I_KBD){
		z80sts_pt->kcode[z80sts_pt->wptr++]=IORD_8DIRECT(REG_BASE, MZ_SYS_KBDT);
		z80sts_pt->wptr=z80sts_pt->wptr&0x1f;
		IOWR_8DIRECT(REG_BASE, MZ_SYS_IREQ, I_KBD);	// IRQ Clear
	}

	// Function Button
	if((IORD_8DIRECT(REG_BASE, MZ_SYS_IREQ)&I_FBTN)==I_FBTN){
		if((z80sts_pt->status&S_FBTN)==0)
			z80sts_pt->status|=S_FBTN;	// Set Flag
		else
			z80sts_pt->status&=~S_FBTN;	// Clear Flag
		IOWR_8DIRECT(REG_BASE, MZ_SYS_IREQ, I_FBTN);	// IRQ Clear
	}

	// CMT Control
	if((IORD_8DIRECT(REG_BASE, MZ_SYS_IREQ)&I_CMT)==I_CMT){
		z80sts_pt->status|=S_CMT;	// Set Flag
		IOWR_8DIRECT(REG_BASE, MZ_SYS_IREQ, I_CMT);	// IRQ Clear
	}

	IOWR_ALTERA_AVALON_PIO_EDGE_CAP(INTC_BASE, 0);
	IOWR_ALTERA_AVALON_PIO_IRQ_MASK(INTC_BASE, 0xf);
}

/*
 * ISR registration
 */
void int_regist(void)
{
	alt_ic_isr_register(INTC_IRQ_INTERRUPT_CONTROLLER_ID, INTC_IRQ, int_service, (void*)&z80_sts, 0x0);
	IOWR_ALTERA_AVALON_PIO_EDGE_CAP(INTC_BASE, 0);
	IOWR_ALTERA_AVALON_PIO_IRQ_MASK(INTC_BASE,0xf);
	IOWR_8DIRECT(REG_BASE, MZ_SYS_IREQ, 0xff);	// IRQ Clear
	IOWR_8DIRECT(REG_BASE, MZ_SYS_IENB, I_CMT+I_KBD+I_FBTN);	// IRQ Enable
}

/*
 * Release Reset for MZ
 */
void MZ_release(void)
{
	IOWR_8DIRECT(REG_BASE, MZ_SYS_CTRL, 0x03);	// Reset Release
}

/*
 * Save and Clear VRAM
 */
void SaveVRAM(void)
{
	unsigned int i;

	for(i=0;i<2000;i++){
		buvram[i]=IORD_8DIRECT(REG_BASE, MZ_VRAM+i);
		IOWR_8DIRECT(REG_BASE, MZ_VRAM+i, 0);
	}
}

/*
 * Restore VRAM
 */
void RestoreVRAM(void)
{
	unsigned int i;

	for(i=0;i<2000;i++)
		IOWR_8DIRECT(REG_BASE, MZ_VRAM+i, buvram[i]);
}

/*
 * Bus Request for MZ
 */
void MZ_Brequest(void)
{
	IOWR_8DIRECT(REG_BASE, MZ_SYS_CTRL, 0x02);	// Bus Request
	while((IORD_8DIRECT(REG_BASE, MZ_SYS_STATUS)&0x01)!=0);	// Wait Bus Acknowledge

	// Save and Clear VRAM
	SaveVRAM();
}

/*
 * Bus Request for MZ(not Clear Screen)
 */
void MZ_Brequest2(void)
{
	IOWR_8DIRECT(REG_BASE, MZ_SYS_CTRL, 0x02);	// Bus Request
	while((IORD_8DIRECT(REG_BASE, MZ_SYS_STATUS)&0x01)!=0);	// Wait Bus Acknowledge

	// Save and Clear VRAM
	SaveVRAM();
}

/*
 * Bus Release for MZ
 */
void MZ_Brelease(void)
{
	// Restore VRAM
	RestoreVRAM();

	IOWR_8DIRECT(REG_BASE, MZ_SYS_CTRL, 0x03);	// Bus Release

}

/*
 * Boot Mode for MZ
 */
void MZ_BOOT(void)
{
	IOWR_8DIRECT(REG_BASE, MZ_SYS_CTRL, 0x05);	// Reset and Boot
}

/*
 * Display 1 character to MZ screen
 */
void MZ_disp(unsigned int x, unsigned int y, unsigned char ch)
{
	IOWR_8DIRECT(REG_BASE, MZ_VRAM+(y*40+x), ch);
}

/*
 * Display Message(until NULL) to MZ screen
 */
void MZ_msg(unsigned int x, unsigned int y, char *msg)
{
	while((*msg)!=0){
		MZ_disp(x,y,*msg);
		x++;
		if(x>=40){
			y++;
			x=0;
		}
		msg++;
	}
}

/*
 * Display Message(for numbers) to MZ screen
 */
void MZ_msgx(unsigned int x, unsigned int y, char *msg, unsigned int num)
{
	while((num--)!=0){
		MZ_disp(x,y,*msg);
		x++;
		if(x>=40){
			y++;
			x=0;
		}
		msg++;
	}
}

/*
 * Sharp PWM Pulse Generate
 */
// output 1bit
void pout(char n)
{
	int stat;

	do{
		stat=IORD_8DIRECT(REG_BASE, MZ_CMT_POUT);
	}while(stat&C_POUT);					// still output
	IOWR_8DIRECT(REG_BASE, MZ_CMT_POUT, n);		// output 1 pulse
}

// output 1byte
int bout(char c)
{
	int n,sum=0;

	pout(1);
	for(n=0;n<8;n++){
		if((c&0x80)==0x80){
			pout(1);
			sum++;
		}else{
			pout(0);
		}
		c<<=1;
	}

	return sum;
}

// output checksum
void sumout(int sum)
{
	bout((sum>>8)&0xff);
	bout(sum&0xff);
}

