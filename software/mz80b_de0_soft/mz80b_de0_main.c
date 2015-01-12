/*
 * MZ-80B on FPGA (Altera DE0 version)
 * Main module
 *
 * (c) Nibbles Lab. 2013-2014
 *
 */

#include "system.h"
#include "io.h"
#include <stdio.h>
#include <string.h>
#include "unistd.h"
#include "integer.h"
//#include "altera_avalon_pio_regs.h"
#include "sys/alt_irq.h"
#include "mz80b_de0_main.h"
#include "mzctrl.h"
#include "key.h"
#include "menu.h"
#include "file.h"

extern volatile z80_t z80_sts;

// Globals
extern char fname[13],tname[13],dname[2][13];
extern int t_block;				// current block number
extern int d_tnum[2];			// Current Track number
//extern DWORD ql_pt;
unsigned char settape[]={0x72, 0x5a, 0x5a,'\0'};
unsigned char setfd1[]={0x72, 0x5a, 0x72, 0x5a, '\0'};
unsigned char setfd2[]={0x72, 0x5a, 0x72, 0x72, 0x5a, '\0'};

void menu_process(void)
{
	int k;

	// Z80-Bus request
//	MZ_Brequest();
	do {
		k=menu(0,0,0);	// Root menu
		switch(k){
			case 0:
				if(view_inventory()==999) continue;
				break;
			case 3:
				direct_load();
				break;
			case 7:
				sd_mount();
				tname[0]='\0'; dname[0][0]='\0'; dname[1][0]='\0';
				break;
			case 10:
				if(tname[0]!='\0'){	// if tape file is not empty
					tape_unmount();
				}
				tape_mount();
				break;
			case 11:
			case 12:
				fd_mount(k);
				break;
			case 20:
				tape_unmount();
				break;
			case 21:
			case 22:
				fd_unmount(k);
				break;
			case 40:
			case 41:
			case 42:
			case 43:
			case 44:
			case 45:
			case 46:
			case 47:
			case 48:
				set_rom(k);
				if(view_inventory()==999) continue;
				fname[0]='\0';
				break;
			case 50:
			case 51:
			case 52:
			case 53:
			case 54:
			case 55:
			case 56:
			case 57:
			case 58:
				clear_rom(k);
				if(view_inventory()==999) continue;
				break;
			case 60:
			case 61:
			default:
				break;
		}
		break;
	}while(1);
	keybuf_clear();

	// Z80-Bus release
//	MZ_Brelease();
}

void System_Initialize(void)
{
	char SecName[8],buffer[512],data[4096];
	unsigned char *cgrom,*keymap;
	int k;
	UINT i,r;
	ROMS_t *romdata=(ROMS_t *)(CFI_BASE+0x100000);

	// Interrupt regist
	int_regist();

	sd_mount();
	tname[0]='\0'; dname[0][0]='\0'; dname[1][0]='\0';

	// Clear VRAM
	for(i=0;i<1000;i++)
		IOWR_8DIRECT(REG_BASE, MZ_VRAM+i, 0);
	// Clear GRAM
	for(i=0;i<65536;i++)
		MZ80B_GRAM(i)=0;
	cgrom=romdata->char80b;
	keymap=romdata->key80b;
	// CG ROM
	for(i=0;i<2048;i++){	// (0xc800-0xcfff)
		IOWR_8DIRECT(REG_BASE, MZ_CGROM+i, cgrom[i]);
	}
	// Key Map Data
	for(i=0;i<256;i++){	// (0xc000-0xc0ff)
		IOWR_8DIRECT(REG_BASE, MZ_KMAP+i, keymap[i]);
	}

	if(IORD_8DIRECT(REG_BASE, MZ_SYS_SW70)&0x20){
		// Select Section Name by MZ mode
		if((IORD_8DIRECT(REG_BASE, MZ_SYS_SW98)&0x2))
			strcpy(SecName, "MZ-2000");
		else
			strcpy(SecName, "MZ-80B");

		// CG ROM
		GetPrivateProfileString(SecName, "CGROM", "NULL", buffer, "system.ini");
		if(strcmp(buffer,"NULL")==0)
			GetPrivateProfileString("COMMON", "CGROM", "NULL", buffer, "system.ini");
		if(strcmp(buffer,"NULL")!=0){
			file_bulk_read(buffer, data, 2048);
			for(i=0;i<2048;i++){	// (0xc800-0xcfff)
				IOWR_8DIRECT(REG_BASE, MZ_CGROM+i, data[i]);
			}
		}
		// Key Map Data
		GetPrivateProfileString(SecName, "KEYMAP", "NULL", buffer, "system.ini");
		if(strcmp(buffer,"NULL")==0)
			GetPrivateProfileString("COMMON", "KEYMAP", "NULL", buffer, "system.ini");
		if(strcmp(buffer,"NULL")!=0){
			file_bulk_read(buffer, data, 256);
			for(i=0;i<256;i++){	// (0xc000-0xc0ff)
				IOWR_8DIRECT(REG_BASE, MZ_KMAP+i, data[i]);
			}
		}
	}

}

/*
 * IPL Emulation(CMT only)
 */
int IPL_from_tape(void)
{
	UINT size;
	unsigned char k;

	MZ_cls();
	t_block=0;

	// Select Tape file
	if(tname[0]=='\0'){
		MZ_msg(10,0,"Make Ready CMT");

		do{
			k=get_key();
			if((k&'C')=='C'){
				key0(settape);
				z80_sts.status|=S_FBTN;	// Set Flag
			}else if(k==0x1b&&!(IORD_8DIRECT(REG_BASE, MZ_SYS_SW70)&0x10)){
				return -1;
			}else if((z80_sts.status&S_FBTN)!=S_FBTN){
				continue;
			}
			SaveVRAM();
			menu_process();
			z80_sts.status&=~S_FBTN;	// Clear Flag
			RestoreVRAM();
		}while(fname[0]=='\0');

		tape_mount();
	}

	while(1){
		// File Read
		MZ_msg(4,0,"IPL is looking for a program");
		usleep(500000);
		tape_rdinf_bulk(&MZ80B_MEM(0x4f00));
		MZ_cls();
		MZ_msg(0,0,"IPL is loading ");
		MZ_msgx(16,0,(char *)&MZ80B_MEM(0x4f01),16);
		if((MZ80B_MEM(0x4f00))==0x01) break;
		MZ_cls();
		MZ_msg(10,0,"File Mode error");
		tape_unmount();
		fname[0]='\0';
		if(!(IORD_8DIRECT(REG_BASE, MZ_SYS_SW70)&0x10)) return -1;
		MZ_msg(4,2,"Pressing S key starts the CMT");
		while(1){
			if((get_key()&'S')=='S'){
				if(fname[0]!='\0') break;
			}else if((z80_sts.status&S_FBTN)==S_FBTN){
				SaveVRAM();
				menu_process();
				z80_sts.status&=~S_FBTN;	// Clear Flag
				RestoreVRAM();
			}
		}
		MZ_cls();
	}

	size=(MZ80B_MEM(0x4f13)<<8)+MZ80B_MEM(0x4f12);
	tape_rddat_bulk(&MZ80B_MEM(0),size);
	return 0;
}

/*
 * IPL Emulation
 */
void IPL(void)
{
	UINT size,record,i,silent_boot,l_track;
	int length;
	unsigned char k;

	// Enter Boot Mode
	MZ_BOOT();
	MZ_cls();
	fname[0]='\0';
	// disk already exists
	if(dname[0][0]=='\0')
		silent_boot=0;
	else
		silent_boot=1;

	if(IORD_8DIRECT(REG_BASE, MZ_SYS_SW70)&0x10){
		IPL_from_tape();
	} else {
		// Boot from FD or CMT
		if(silent_boot==0){
			MZ_msg(10,0,"Make Ready FD");
		}

		while(1){
			if(silent_boot==0){
				MZ_msg(10,2,"Press F or C");
				MZ_msg(11,4,"F:Floppy Disk");
				if(!(IORD_8DIRECT(REG_BASE, MZ_SYS_SW98)&0x2)) MZ_msg(24,4,"ette");
				MZ_msg(11,5,"C:Cassette Tape");
			}
			while(1){
				if(silent_boot==0){
					if((z80_sts.status&S_FBTN)==S_FBTN){
						SaveVRAM();
						menu_process();
						z80_sts.status&=~S_FBTN;	// Clear Flag
						RestoreVRAM();
					}
					k=get_key();
				}else{
					k='F';
				}
				if((k&'C')=='C'){
					if(IPL_from_tape()==0) return; else break;
				}
				if((k&'F')=='F'){
					if(silent_boot==0){
						MZ_cls();
						MZ_msg(10,2,"Drive No? (1-4)");
						do{ k=get_key(); }while(k<'1' || k>'4');
						MZ80B_MEM(0x7fec)=k-'1';
						if((k=='1'&&dname[0][0]=='\0')||(k=='2'&&dname[1][0]=='\0')||k=='3'||k=='4'){
							MZ_cls();
							MZ_msg(10,0,"Loading error");
							break;
						}
					}else{
						k='1';
					}
					read_1sector(k-'1', 0, &MZ80B_MEM(0x4f00), &l_track);
					if(MZ80B_MEM(0x4f00)==0x01&&strncmp((char *)&MZ80B_MEM(0x4f01), "IPLPRO", 6)==0){
						MZ_cls();
						MZ_msg(0,0,"IPL is loading ");
						MZ_msgx(16,0,(char *)&MZ80B_MEM(0x4f07),10);
						size=(MZ80B_MEM(0x4f15)<<8)+MZ80B_MEM(0x4f14);
						record=(MZ80B_MEM(0x4f1f)<<8)+MZ80B_MEM(0x4f1e);
						for(i=0;i<size;i+=length){
							length=read_1sector(k-'1', record++, &MZ80B_MEM(i), &l_track);
							if(length<0) break;
						}
						if(length>0){
							d_tnum[k-'1']=l_track/2;
							track_setting(k-'1', l_track/2);
							return;
						}
					}
					MZ_cls();
					MZ_msg(7,0,"This disk is not master");
					silent_boot=0;
					break;
				}
			}
		}

	}

}

int main()
{
	int i,k,ipl_mode=1;
	//UINT r;

	// Initialize Disk I/F and ROM
	System_Initialize();

	/* Event loop never exits. */
	while (1){
		// IPL
		if(ipl_mode==1){
			// System Program Load
			IPL();
			// Start MZ
			MZ_release();
			ipl_mode=0;
		}

		// CMT Control
		if((z80_sts.status&S_CMT)==S_CMT){
			z80_sts.status&=~S_CMT;
			// Eject and Set Tape
			if((IORD_8DIRECT(REG_BASE, MZ_CMT_STATUS)&C_OPEN)==C_OPEN){
				IOWR_8DIRECT(REG_BASE, MZ_CMT_STATUS, C_OPEN);
				tape_unmount();
				fname[0]='\0';
				key0(settape);
				z80_sts.status|=S_FBTN;	// Set Flag
				MZ_Brequest();
				menu_process();
				MZ_Brelease();
				z80_sts.status&=~S_FBTN;	// Clear Flag
			}
			// Load
			if((IORD_8DIRECT(REG_BASE, MZ_CMT_STATUS)&C_PLAY)==C_PLAY){
				IOWR_8DIRECT(REG_BASE, MZ_CMT_STATUS, C_PLAY);
				IOWR_8DIRECT(REG_BASE, MZ_CMT_CTRL, C_MTON+C_TAPE);	// Motor On
				cmtload();
			}
			// Rewind
			if((IORD_8DIRECT(REG_BASE, MZ_CMT_STATUS)&C_REW)==C_REW){
				if((IORD_8DIRECT(REG_BASE, MZ_CMT_STATUS)&C_APSS)==C_APSS){
					apss_r();
				} else {
					tape_rewind();
					IOWR_8DIRECT(REG_BASE, MZ_CMT_STATUS, C_REW);
				}
			}
			// F.Forward
			if((IORD_8DIRECT(REG_BASE, MZ_CMT_STATUS)&C_FF)==C_FF){
				if((IORD_8DIRECT(REG_BASE, MZ_CMT_STATUS)&C_APSS)==C_APSS){
					apss_f();
				} else {
					IOWR_8DIRECT(REG_BASE, MZ_CMT_STATUS, C_FF);
				}
			}
		}

		// Function Button
		if((z80_sts.status&S_FBTN)==S_FBTN){
			MZ_Brequest();
			menu_process();
			MZ_Brelease();
			z80_sts.status&=~S_FBTN;
		}

		// BST check
		if((IORD_8DIRECT(REG_BASE, MZ_SYS_STATUS)&S_BST)==S_BST){
			ipl_mode=1;
		}

		// Quick Load/Save
//		if((z80_sts.status&0x02)==0x02){
//			if(IORD(CMT_0_BASE, 3)==0x0f){	// CMD is Load
//				IOWR(CMT_0_BASE, 2, 0x80);	// set STAT busy

				// Wait for confirm busy by Z80
//				while(IORD(CMT_0_BASE, 3)!=0);

//				if(tname[0]=='\0'){	// if tape file is empty
//					z80_sts.status=0x03;
//					// Z80-Bus request
//					MZ_Brequest();
//					key0(settape);
//					k=menu(0,0,0);	// Root menu
//					// Z80-Bus release
//					MZ_Brelease();
//					z80_sts.status=0x02;
//					if(k!=10){
//						z80_sts.status=0;
//						IOWR(CMT_0_BASE, 2, 0xff);	// set STAT error
//						continue;
//					}
//					//keybuf_clear();
//					strcpy(tname, fname);
//					IOWR(CMT_0_BASE, 1, 1);
//					ql_pt=0;
//				}

//				quick_load();
//				IOWR(CMT_0_BASE, 2, 0);	// set STAT free
//				z80_sts.status&=0xfffffffd;
//			}

//			if(IORD(CMT_0_BASE, 3)==0xf0){	// CMD is Save
//				IOWR(CMT_0_BASE, 2, 0x80);	// set STAT busy

//				// Wait for confirm busy by Z80
//				while(IORD(CMT_0_BASE, 3)!=0);

//				if(tname[0]=='\0'){	// if tape file is empty
//					// Z80-Bus request
//					MZ_Brequest();
//					i=input_file_name();
//					// Z80-Bus release
//					MZ_Brelease();
//					if(tname[0]=='\0'||i<0){
//						z80_sts.status=0;
//						IOWR(CMT_0_BASE, 2, 0xff);	// set STAT error
//						continue;
//					}
//					keybuf_clear();
//					IOWR(CMT_0_BASE, 1, 1);
//				}

//				if(quick_save()!=FR_OK)
//					IOWR(CMT_0_BASE, 2, 0xff);	// set STAT error
//				else
//					IOWR(CMT_0_BASE, 2, 0);	// set STAT free
//				z80_sts.status&=0xfffffffd;
//			}
// 		}
	}

	return 0;
}
