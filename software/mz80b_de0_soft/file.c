/*
 * MZ-80C on FPGA (Altera DE0 version)
 * File Access routines
 *
 * (c) Nibbles Lab. 2012-2014
 *
 */

#include "system.h"
#include "io.h"
#include "alt_types.h"
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include "altera_avalon_pio_regs.h"
#include "sys/alt_flash.h"
#include "mz80b_de0_main.h"
#include "mzctrl.h"
#include "integer.h"
#include "ff.h"
#include "file.h"

FATFS fs;
DIR dirs;
FIL tobj;
FILINFO finfo;
char fname[13];
//
// Variable for CMT
char tname[13];
DWORD t_bpos[10];		// block positions of every blocks
int t_bnum;			// exist blocks in tape file
int t_block;		// current block number
DWORD tremain;		// current block remaining size
//
// Variable for FDD
char dname[2][13];
TCHAR dpath[2][256];
int d_tnum[2];			// Current Track number
int d_size[2];			// Image file size
int d_mode[2];			// Image file format 0:D88 1:DSK 2:Plain_2D
int d_sectors[2];		// Number of sectors in Plain format
int d_length[2];		// Sector length in Plain format
int track_offset[2][204];	// Track-Info table in DSK-format
DWORD ql_pt;
extern volatile z80_t z80_sts;

/*
 * Mount SD Card
 */
void sd_mount(void)
{
	f_mount(0,&fs);
}

/*
 * Read File (bulk)
 */
UINT file_bulk_read(char *fname, unsigned char *buf, UINT size)
{
	FIL fobj;
	FRESULT res;
	UINT r;

	// File Read
	res=f_open(&fobj, fname, FA_OPEN_EXISTING | FA_READ);
	if(res!=FR_OK) return(0);
	res=f_read(&fobj, buf, size, &r);
	res=f_close(&fobj);
	return(r);
}

/*
 * Read File (bulk) with Progress Bar
 */
UINT file_bulk_read_progress(char *fname, unsigned char *buf, UINT size)
{
	FIL fobj;
	FRESULT res;
	UINT i,r,bsize,rr=0;

	// File Read
	res=f_open(&fobj, fname, FA_OPEN_EXISTING | FA_READ);
	if(res!=FR_OK) return(0);
	for(i=0;i<40;i++) MZ_disp(i, 24, 0x1f);
	if(size>fobj.fsize) size=fobj.fsize;
	bsize=size/40;
	for(i=0;i<39;i++){
		res=f_read(&fobj, buf, bsize, &r);
		rr+=r;
		buf+=bsize;
		MZ_disp(i, 24, 0x1e);
	}
	res=f_read(&fobj, buf, bsize+bsize, &r);
	rr+=r;
	MZ_disp(39, 24, 0x1e);
	res=f_close(&fobj);
	return(rr);
}

/*
 * Write File (bulk) with Progress Bar
 */
UINT file_bulk_write_progress(char *fname, unsigned char *buf, UINT size)
{
	FIL fobj;
	FRESULT res;
	UINT i,r,bsize,rr=0;

	// File Read
	res=f_open(&fobj, fname, FA_CREATE_ALWAYS | FA_WRITE);
	if(res!=FR_OK) return(0);
	for(i=0;i<40;i++) MZ_disp(i, 24, 0x1f);
	bsize=size/40;
	for(i=0;i<39;i++){
		res=f_write(&fobj, buf, bsize, &r);
		rr+=r;
		buf+=bsize;
		MZ_disp(i, 24, 0x1e);
	}
	if(rr<size) res=f_write(&fobj, buf, size-rr, &r);
	rr+=r;
	MZ_disp(39, 24, 0x1e);
	res=f_close(&fobj);
	return(rr);
}

/*
 * Force put memory from MZT file
 */
void direct_load(void)
{
	UINT i,size,dtadr;
	unsigned char buf[65536];

	// File Read
	if(file_bulk_read((TCHAR *)fname, buf, 65536)){
		for(i=0;i<128;i++){	// Information
			MZ80B_MEM(0x1140+i)=buf[i];
		}
		size=(buf[0x13]<<8)+buf[0x12];
		dtadr=(buf[0x15]<<8)+buf[0x14];
		for(i=0;i<size;i++){	// Body
			MZ80B_MEM(dtadr+i)=buf[128+i];
		}
		MZ80B_MEM(0x1155)=0xc3;
	}

}

/*
 * ROM data setting
 */
void set_rom(int select){
	alt_flash_fd *fd;
	ROMS_t romdata;
	int i,nums;
	unsigned char *buf;
	char *name;

	for(i=0;i<sizeof(ROMS_t);i++)
		((char *)&romdata)[i]=((char *)(CFI_BASE+0x100000))[i];

	switch(select){
	case 40:
		buf=romdata.char80b;
		name=romdata.char80b_name;
		nums=2048;
		break;
	case 41:
		buf=romdata.key80b;
		name=romdata.key80b_name;
		nums=256;
		break;
	default:
		break;
	}

	// File Read
	if(file_bulk_read((TCHAR *)fname, buf, nums)){
		strcpy(name, "            ");
		strcpy(name, fname);

		fd=alt_flash_open_dev(CFI_NAME);
		if(fd)
			alt_write_flash(fd, 0x100000, (char *)&romdata, sizeof(ROMS_t));
		alt_flash_close_dev(fd);
	}
}

void clear_rom(int select){
	alt_flash_fd *fd;
	ROMS_t romdata;
	int i;
	unsigned char *buf;
	char *name;
	size_t size;

	for(i=0;i<sizeof(ROMS_t);i++)
		((char *)&romdata)[i]=((char *)(CFI_BASE+0x100000))[i];

	switch(select){
	case 50:
		buf=romdata.char80b;
		name=romdata.char80b_name;
		size=sizeof(romdata.char80b);
		break;
	case 51:
		buf=romdata.key80b;
		name=romdata.key80b_name;
		size=sizeof(romdata.key80b);
		break;
	default:
		break;
	}

	// File Read
	memset(buf, 0xff, size);
	strcpy(name, "            ");

	fd=alt_flash_open_dev(CFI_NAME);
	if(fd)
		alt_write_flash(fd, 0x100000, (char *)&romdata, sizeof(ROMS_t));
	alt_flash_close_dev(fd);
}

WORD FindSectionAndKey(
	char *lpAppName,        /* セクション名 */
	char *lpKeyName,        /* キー名 */
	char *lpReturnedString,  /* 情報が格納されるバッファ */
	const char *lpFileName        /* .ini ファイルの名前 */
)
{
	WORD p;
	FIL fobj;
	FRESULT res;

	/* .iniファイルオープン */
	res=f_open(&fobj, lpFileName, FA_OPEN_EXISTING | FA_READ);
	/* .iniファイルがあるなら */
	if(res==FR_OK){
		/* セクション行検索 */
		do{
			/* 1行読んで、EOFだったらbreak */
			if(f_gets(lpReturnedString, 512, &fobj)==NULL) break;
			/* セクションを表わす'['なら */
			if(lpReturnedString[0]=='['){
				/* '['の次の文字 */
				p=1;
				/* セクション名の終わりを表わす']'か、行の終わりか、指定したセクション名の終わりまで */
				while(lpReturnedString[p]!=']' && lpReturnedString[p]!='\0' && lpAppName[p-1]!='\0'){
					/* bit5をマスクすることで大文字化した両方の文字列を比較し、違ったらbreak */
					if((lpReturnedString[p]&0xdf)!=(lpAppName[p-1]&0xdf)) break;
					/* まだ一致してるので次の文字へ */
					p++;
				}
				/* 今のループの脱出原因がセクション名完全一致なら */
				if(lpAppName[p-1]=='\0'){
					/* キー行検索 */
					do{
						/* 1行読んで、EOFだったらbreak */
						if(f_gets(lpReturnedString, 512, &fobj)==NULL) break;
						/* 読んだ行がセクションなら、新しいセクションに入るのでbreak */
						if(lpReturnedString[0]=='[') break;
						/* 読んだ行がコメントなら、その行を飛ばす */
						/*if(lpReturnedString[0]==';') continue;*/
						/* 行の先頭 */
						p=0;
						/* キー名の終わりとなる'='かスペースか、行の終わりか、タブか、指定したキー名の終わりまで */
						while(lpReturnedString[p]!='=' && lpReturnedString[p]!=' ' && lpReturnedString[p]!=0x09 && lpReturnedString[p]!='\0' && lpKeyName[p]!='\0'){
							/* bit5をマスクすることで大文字化した両方の文字列を比較し、違ったらbreak */
							if((lpReturnedString[p]&0xdf)!=(lpKeyName[p]&0xdf)) break;
							/* まだ一致してるので次の文字へ */
							p++;
						}
						/* 今のループの脱出原因がキー名完全一致なら */
						if(lpKeyName[p]=='\0'){
							/* スペースやタブ、'='はスキップしておく */
							while(lpReturnedString[p]=='=' || lpReturnedString[p]==' ' || lpReturnedString[p]==0x09) p++;
							/* .ini ファイルクローズ */
							res=f_close(&fobj);
							/* 文字列の場所を返す */
							return p;
						}
					/* まだEOFでなければ繰り返し */
					}while(fobj.fptr!=fobj.fsize);	/* while(!feof(&fobj1)); */
				}
			}
		/* まだEOFでなければ繰り返し */
		}while(fobj.fptr!=fobj.fsize);	/* while(!feof(&fobj1)); */
	}
	/* .iniファイルクローズ */
	res=f_close(&fobj);
	/* .iniファイルがないかセクションまたはキーが見つからない */
	return 0;
}


void GetPrivateProfileString(
	char *lpAppName,        /* セクション名 */
	char *lpKeyName,        /* キー名 */
	char *lpDefault,        /* 既定の文字列 */
	char *lpReturnedString,  /* 情報が格納されるバッファ */
	const char *lpFileName        /* .ini ファイルの名前 */
)
{
	WORD p,q;

	p=FindSectionAndKey(lpAppName, lpKeyName, lpReturnedString, lpFileName);
	if(p==0){
		do{
			lpReturnedString[p]=lpDefault[p];
		}while(lpDefault[p++]!='\0');
	} else {
		q=p;
		do{
			lpReturnedString[p-q]=lpReturnedString[p];
		}while(lpReturnedString[p++]!='\0');
	}
}


DWORD GetPrivateProfileInt(
	char *lpAppName,  /* セクション名 */
	char *lpKeyName,  /* キー名 */
	DWORD nDefault,       /* キー名が見つからなかった場合に返すべき値 */
	const char *lpFileName  /* .ini ファイルの名前 */
)
{
	WORD c,p,q;
	char buffer[64];

	p=FindSectionAndKey(lpAppName, lpKeyName, buffer, lpFileName);
	if(p==0){
		return nDefault;
	} else {
		q=0;
		while(buffer[p]!='\0'){
			c=buffer[p];
			if(c<'0' || c>'9') break;
			q=c-0x30+q*10;
			p++;
		}
		return q;
	}
}

/*
 * mount Tape File
 */
//int tape_mount(int recordable){
int tape_mount(void)
{
	int i;
	FRESULT res;

	strcpy(tname, fname);
	res=f_open(&tobj, tname, FA_OPEN_EXISTING | FA_READ);
	if(res!=FR_OK) return(-1);

	for(i=0;i<10;i++) t_bpos[i]=0;
	t_bnum=0; t_block=0; tremain=0;
	IOWR_8DIRECT(REG_BASE, MZ_CMT_CTRL, C_TAPE);	// recorded tape insert
	return 0;
}

/*
 * unmount Tape File
 */
int tape_unmount(void)
{
	FRESULT res;

	res=f_close(&tobj);
	if(res!=FR_OK) return(-1);
	IOWR_8DIRECT(REG_BASE, MZ_CMT_CTRL, 0);	// tape remove
	tname[0]='\0';
	return 0;
}

/*
 * Read Information block (bulk)
 */
void tape_rdinf_bulk(unsigned char *buf)
{
	FRESULT res;
	UINT r;
	DWORD size;

	res=f_read(&tobj, buf, 128, &r);
	if(t_bnum==t_block){
		size=((*(buf+0x13))<<8)+*(buf+0x12)+128;
		if(t_bpos[t_block]+size<=tobj.fsize){
			t_bpos[t_block+1]=t_bpos[t_block]+size;
			t_bnum=t_block+1;
		}
	}
}

/*
 * Read Data block (bulk)
 */
void tape_rddat_bulk(unsigned char *buf, UINT size)
{
	FRESULT res;
	UINT r;

	res=f_read(&tobj, buf, size, &r);
	if(t_bnum>t_block) t_block++;
}

/*
 * Move to top of tape
 */
void tape_rewind(void)
{
	FRESULT res;

	res=f_lseek(&tobj, 0);
	IOWR_8DIRECT(REG_BASE, MZ_CMT_CTRL, C_ANIM+C_TAPE);	// Animation On
	usleep(1000000);
	IOWR_8DIRECT(REG_BASE, MZ_CMT_CTRL, C_TAPE);	// Animation Off
	t_block=0;
	tremain=0;
}

/*
 * Read Information block (SHARP PWM)
 */
int tape_rdinf_spwm(void)
{
	int bn,sum=0;
	unsigned char tdata[128];
	DWORD size;
	UINT r;
	FRESULT res;

	// Tape End Check
	if(t_bnum==t_block && t_bpos[t_block]==tobj.fsize){
		IOWR_8DIRECT(REG_BASE, MZ_CMT_CTRL, C_TAPE);	// Motor Off
		return -1;
	}

	// INF Block Read
	res=f_read(&tobj, tdata, 128, &r);
	size=(tdata[0x13]<<8)+tdata[0x12]+128;
	tremain=size;
	IOWR_16DIRECT(REG_BASE, MZ_CMT_COUNT, tremain);	// display data size
	if(t_bnum==t_block){
		if(t_bpos[t_block]+size<=tobj.fsize){
			t_bpos[t_block+1]=t_bpos[t_block]+size;
			t_bnum=t_block+1;
		}
	}

	for(bn=0;bn<22000;bn++){
		pout(0);
		if((IORD_8DIRECT(REG_BASE, MZ_CMT_CTRL)&C_MTON)==0) return -1;	// tape stop
	}
	for(bn=0;bn<40;bn++){
		pout(1);
		if((IORD_8DIRECT(REG_BASE, MZ_CMT_CTRL)&C_MTON)==0) return -1;	// tape stop
	}
	for(bn=0;bn<40;bn++){
		pout(0);
		if((IORD_8DIRECT(REG_BASE, MZ_CMT_CTRL)&C_MTON)==0) return -1;	// tape stop
	}
	pout(1);
	for(bn=0;bn<128;bn++){
		sum+=bout(tdata[bn]);
		if((IORD_8DIRECT(REG_BASE, MZ_CMT_CTRL)&C_MTON)==0) return -1;	// tape stop
		IOWR_16DIRECT(REG_BASE, MZ_CMT_COUNT, --tremain);	// display data size
	}
	sumout(sum); sum=0;
	if((IORD_8DIRECT(REG_BASE, MZ_CMT_CTRL)&C_MTON)==0) return -1;	// tape stop
	pout(1);

	return 0;
}

/*
 * Read Data block (SHARP PWM)
 */
int tape_rddat_spwm(void)
{
	int bn,sum=0;
	unsigned char tdata[128];
	UINT r;
	FRESULT res;

	for(bn=0;bn<11000;bn++){
		pout(0);
		if((IORD_8DIRECT(REG_BASE, MZ_CMT_CTRL)&C_MTON)==0) return -1;	// tape stop
	}
	for(bn=0;bn<20;bn++){
		pout(1);
		if((IORD_8DIRECT(REG_BASE, MZ_CMT_CTRL)&C_MTON)==0) return -1;	// tape stop
	}
	for(bn=0;bn<20;bn++){
		pout(0);
		if((IORD_8DIRECT(REG_BASE, MZ_CMT_CTRL)&C_MTON)==0) return -1;	// tape stop
	}
	pout(1);
	do {
		res=f_read(&tobj, tdata, 128, &r);
		for(bn=0;bn<128;bn++){
			sum+=bout(tdata[bn]);
			if((IORD_8DIRECT(REG_BASE, MZ_CMT_CTRL)&C_MTON)==0) return -1;	// tape stop
			IOWR_16DIRECT(REG_BASE, MZ_CMT_COUNT, --tremain);	// display data size
		}
	}while(tremain>128);
	res=f_read(&tobj, tdata, tremain, &r);
	for(bn=0;bn<tremain;bn++){
		sum+=bout(tdata[bn]);
		if((IORD_8DIRECT(REG_BASE, MZ_CMT_CTRL)&C_MTON)==0) return -1;	// tape stop
		IOWR_16DIRECT(REG_BASE, MZ_CMT_COUNT, tremain-bn);	// display data size
	}
	sumout(sum);
	pout(1);
	if(t_bnum>t_block) t_block++;
	tremain=0;

	return 0;
}

/*
 * Load MZT file
 */
int cmtload(void)
{
	if(tremain==0){
		return tape_rdinf_spwm();
	} else {
		if(tape_rddat_spwm()==0){
			// Wait for APSS
			while((IORD_8DIRECT(REG_BASE, MZ_CMT_CTRL)&C_MTON)!=0);
			usleep(2000000);
			while((IORD_8DIRECT(REG_BASE, MZ_CMT_STATUS)&C_FF)!=0);
			z80_sts.status&=~S_CMT;
		}
	}

	return 0;
}

/*
 * APSS Forward
 */
void apss_f(void)
{
	int i;
	unsigned char buf[128];
	FRESULT res;

	if(t_bnum==t_block && t_bpos[t_bnum]>=tobj.fsize){		// Tape End?
		while((IORD_8DIRECT(REG_BASE, MZ_CMT_STATUS)&C_FF)!=0);	// do nothing
		return;
	} else {
		while(1){
			IOWR_8DIRECT(REG_BASE, MZ_CMT_CTRL, C_PON+C_TAPE);	// Force On
			usleep(1000000);
			IOWR_8DIRECT(REG_BASE, MZ_CMT_CTRL, C_TAPE);	// Force Off
			if(t_bnum==t_block){
				if(t_bpos[t_bnum]<tobj.fsize){
					tape_rdinf_bulk(buf);
				}
			}
			t_block++;
			res=f_lseek(&tobj, t_bpos[t_block]);
			tremain=0;
			if(f_eof(&tobj)){
				IOWR_8DIRECT(REG_BASE, MZ_CMT_STATUS, C_APSS+C_FF);
				return;
			}
			for(i=0;i<500000;i++){
				if((IORD_8DIRECT(REG_BASE, MZ_CMT_STATUS)&C_FF)==0) return;
			}
		}
	}
}

/*
 * APSS Rewind
 */
void apss_r(void)
{
	int i;
	FRESULT res;

	if(t_block==0 && tremain==0){		// Tape Top?
		while((IORD_8DIRECT(REG_BASE, MZ_CMT_STATUS)&C_REW)!=0);	// do nothing
		return;
	} else {
		while(1){
			IOWR_8DIRECT(REG_BASE, MZ_CMT_CTRL, C_PON+C_TAPE);	// Force On
			usleep(1000000);
			IOWR_8DIRECT(REG_BASE, MZ_CMT_CTRL, C_TAPE);	// Force Off
			if(t_block>0) t_block--;
			res=f_lseek(&tobj, t_bpos[t_block]);
			tremain=0;
			if(t_block==0){
				IOWR_8DIRECT(REG_BASE, MZ_CMT_STATUS, C_APSS+C_REW);
				return;
			}
			for(i=0;i<500000;i++){
				if((IORD_8DIRECT(REG_BASE, MZ_CMT_STATUS)&C_REW)==0) return;
			}
		}
	}
}

/*
 * Track pointer setting (after seek)
 */
void track_setting(int drive, int track)
{
	HEADER_D88_t *d88_fdd;
	HEADER_DSK_DI_t *dsk_fdd;
	HEADER_DSK_TI_t *dsk_trk;
	int sector,head,i,offset,s,l,reg,den,tracksize,sectorsize,gap3,gap4;

	if(drive!=0 && drive!=1) return;
	if(dname[drive][0]=='\0') return;
	reg=(drive==0?MZ_FD0_REGS:MZ_FD1_REGS);

	switch(d_mode[drive]){
	case F_D88:
		d88_fdd=(HEADER_D88_t *)(drive==0?&MZ80B_FDD1(0):&MZ80B_FDD2(0));
		for(head=0;head<2;head++){
			IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_HSEL, head);
			offset=d88_fdd->t_track[track*2+head];
			// Sector Numbers
			s=*((unsigned char *)d88_fdd+offset+4);
			if(s>16) sector=16; else sector=s;
			IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_MAXS, sector-1);
			// Top Offset for track
			IOWR_32DIRECT(REG_BASE, reg+MZ_FDD_TADR, offset+(unsigned int)d88_fdd+16);
			// Logical Sector Number and Sector size
			tracksize=0; den=0x40;
			for(i=0;i<sector;i++){
				den&=*((unsigned char *)d88_fdd+offset+6);		// sector density
				s=(*((unsigned char *)d88_fdd+offset+3))&0x3;	// size in ID
				switch(s){
				case D_S1K:
					l=1024;
					break;
				case D_S512:
					l=512;
					break;
				case D_S256:
					l=256;
					break;
				default:
					l=128;
					break;
				}
				s+=((*((unsigned char *)d88_fdd+offset+2))<<2);	// number in ID
				s+=((*((unsigned char *)d88_fdd+offset+1))<<7);	// head in ID
				IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_LSEL, i);
				IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_ID, s);
				offset+=(l+16);
				tracksize+=(22+22+18+l);
			}
			// Density
			IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_DDEN, (den==0x40?0:D_DDEN));
			// GAP3/GAP4 length
			if(den==0x40){	// FM
				gap3=(3125-(16+tracksize+94))/sector;
				gap4=3125-16-tracksize-gap3*sector;
			}else{			// MFM
				gap3=(6250-(32+tracksize+208))/sector;
				gap4=6250-32-tracksize-gap3*sector;
			}
			IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_G3, gap3);
			IOWR_16DIRECT(REG_BASE, reg+MZ_FDD_G4, gap4);
		}
		break;
	case F_DSK:
		dsk_fdd=(HEADER_DSK_DI_t *)(drive==0?&MZ80B_FDD1(0):&MZ80B_FDD2(0));
		for(head=0;head<2;head++){
			IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_HSEL, head);
			dsk_trk=(HEADER_DSK_TI_t *)((unsigned char *)dsk_fdd+track_offset[drive][track*2+head]);
			// Sector Numbers
			s=dsk_trk->SPT;
			if(s>16) sector=16; else sector=s;
			IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_MAXS, sector-1);
			// Top Offset for track
			IOWR_32DIRECT(REG_BASE, reg+MZ_FDD_TADR, (unsigned int)dsk_trk+256);
			// Logical Sector Number and Sector size
			tracksize=0; sectorsize=128;
			for(i=0;i<sector;i++){
				s=dsk_trk->s_info[i].BPS&0x3;	// size in ID
				s+=(dsk_trk->s_info[i].sector)<<2;	// number in ID
				s+=(dsk_trk->s_info[i].head)<<7;	// head in ID
				l=dsk_trk->s_info[i].length;
				if(l>128) sectorsize=l;
				IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_LSEL, i);
				IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_ID, s);
				tracksize+=(22+22+18+l);
			}
			// Density
			if(sectorsize==128){
				IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_DDEN, 0);
			}else{
				IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_DDEN, D_DDEN);
			}
			// GAP3/GAP4 length
			if(sectorsize==128){	// FM
				gap3=(3125-(16+tracksize+94))/sector;
				gap4=3125-16-tracksize-gap3*sector;
			}else{					// MFM
				gap3=(6250-(32+tracksize+208))/sector;
				gap4=6250-32-tracksize-gap3*sector;
			}
			IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_G3, gap3);
			IOWR_16DIRECT(REG_BASE, reg+MZ_FDD_G4, gap4);
		}
		break;
	case F_2D:
		for(head=0;head<2;head++){
			IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_HSEL, head);
			// Density
			IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_DDEN, D_DDEN);
			// Top Offset for track
			IOWR_32DIRECT(REG_BASE, reg+MZ_FDD_TADR, (drive==0?(unsigned int)&MZ80B_FDD1(0):(unsigned int)&MZ80B_FDD2(0))+(track*2+head)*d_sectors[drive]*d_length[drive]);
			// Sector Numbers
			IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_MAXS, d_sectors[drive]-1);
			// Logical Sector Number
			for(i=0;i<d_sectors[drive];i++){
				if(d_length[drive]==1024){
					s=D_S1K;
				}else if(d_length[drive]==512){
					s=D_S512;
				}else {
					s=D_S256;
				}
				s+=(i+1)<<2;
				s+=head<<7;
				IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_LSEL, i);
				IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_ID, s);
			}
			// GAP3/GAP4 length
			if(d_length[drive]==1024){
				IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_G3, 116);
				IOWR_16DIRECT(REG_BASE, reg+MZ_FDD_G4, 208);
			}else if(d_length[drive]==512){
				IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_G3, 84);
				IOWR_16DIRECT(REG_BASE, reg+MZ_FDD_G4, 296);
			}else {
				IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_G3, 54);
				IOWR_16DIRECT(REG_BASE, reg+MZ_FDD_G4, 266);
			}
		}
		break;
	default:
		break;
	}

	IOWR_8DIRECT(REG_BASE, reg+MZ_FDD_TRK, track);
	return;
}

/*
 * mount Floppy Image File
 */
void fd_mount(int select)
{
	int k,s,i,j,offset,flags=D_DISK;
	HEADER_D88_t *d88_fdd;
	HEADER_DSK_DI_t *dsk_fdd;
	HEADER_DSK_TI_t *dsk_trk;

	// Convert menu-number to drive-number
	s=select-11;
	if(s!=0 && s!=1) return;

	// Set Image Format number
	for(k=0;k<13;){
		if(fname[k++]=='.') break;
	}
	if(fname[k]=='D' && fname[k+1]=='8' && fname[k+2]=='8'){
		d_mode[s]=F_D88;
	}else if(fname[k]=='D' && fname[k+1]=='S' && fname[k+2]=='K'){
		d_mode[s]=F_DSK;
	}else if(fname[k]=='2' && fname[k+1]=='D' && (fname[k+2]=='\0'||fname[k+2]==' ')){
		d_mode[s]=F_2D;
	}else{
		d_mode[s]=0;
	}

	// Mount start
	strcpy(dname[s], fname);
	f_getcwd(dpath[s], sizeof(dpath[s]));
	d_size[s]=file_bulk_read_progress((TCHAR *)fname, (s==0?&MZ80B_FDD1(0):&MZ80B_FDD2(0)), 512*1024);
	switch(d_mode[s]){
	case F_D88:
		d88_fdd=(HEADER_D88_t *)(s==0?&MZ80B_FDD1(0):&MZ80B_FDD2(0));
		flags+=D_D88;
		if(d88_fdd->wp_flag==0x10) flags+=D_WP;
		break;
	case F_DSK:
		dsk_fdd=(HEADER_DSK_DI_t *)(s==0?&MZ80B_FDD1(0):&MZ80B_FDD2(0));
		offset=256;	// Disk-Info
		for(i=0;i<(dsk_fdd->tracks*dsk_fdd->heads);i++){
			if(dsk_fdd->track_size[i]!=0){
				track_offset[s][i]=offset;
				dsk_trk=(HEADER_DSK_TI_t *)((unsigned char *)dsk_fdd+offset);
				for(j=0;j<dsk_trk->SPT;j++){
					offset+=dsk_trk->s_info[j].length;
				}
				offset+=256;
			}else{
				track_offset[s][i]=0;
			}
		}
		break;
	case F_2D:
		if(d_size[s]>=409600){
			d_sectors[s]=5;
			d_length[s]=1024;	//D_S1K;
		}else if(d_size[s]>=368640){
			d_sectors[s]=9;
			d_length[s]=512;	//D_S512;
		}else{
			d_sectors[s]=16;
			d_length[s]=256;	//D_S256;
		}
		break;
	default:
		break;
	}
	IOWR_8DIRECT(REG_BASE, (s==0?MZ_FD0_REGS:MZ_FD1_REGS)+MZ_FDD_CTRL, flags);
	track_setting(s, d_tnum[s]);
}

/*
 * unmount Floppy Image File
 */
void fd_unmount(int select)
{
	int s,size;
	TCHAR tmppath[256];

	// Convert menu-number to drive-number
	s=select-21;
	if(s!=0 && s!=1) return;

	if((IORD_8DIRECT(REG_BASE, (s==0?MZ_FD0_REGS:MZ_FD1_REGS)+MZ_FDD_CTRL)&D_MF)==D_MF){
		f_getcwd(tmppath, sizeof(tmppath));
		f_chdir(dpath[s]);
		size=file_bulk_write_progress((TCHAR *)"TEMP.$$$", (s==0?&MZ80B_FDD1(0):&MZ80B_FDD2(0)), d_size[s]);
		if(size==d_size[s]){	// success to write
			f_unlink(dname[s]);
			f_rename((TCHAR *)"TEMP.$$$", dname[s]);
		}
		f_chdir(tmppath);
	}

	dname[s][0]='\0';
	d_size[s]=0;
	IOWR_8DIRECT(REG_BASE, (s==0?MZ_FD0_REGS:MZ_FD1_REGS)+MZ_FDD_CTRL, 0);
}

/*
 * Read 1 record for Pseudo IPL
 */
int read_1sector(int drive, int record, unsigned char *buf, unsigned int *track)
{
	HEADER_D88_t *d88_fdd;
	HEADER_DSK_TI_t *dsk_trk;
	int i,offset,length;
	unsigned char sector,spt;

	if(drive!=0 && drive!=1) return -1;
	if(dname[drive][0]=='\0') return -1;

	sector=record&0xf;
	record>>=4;
	*track=record^1;
	switch(d_mode[drive]){
	case F_D88:
		d88_fdd=(HEADER_D88_t *)(drive==0?&MZ80B_FDD1(0):&MZ80B_FDD2(0));
		offset=d88_fdd->t_track[*track];
		spt=(*((unsigned char *)d88_fdd+offset+4))+((*((unsigned char *)d88_fdd+offset+5))<<8);
		for(i=0;i<spt;i++){
			length=(*((unsigned char *)d88_fdd+offset+14))+((*((unsigned char *)d88_fdd+offset+15))<<8);
			if((*((unsigned char *)d88_fdd+offset+2))==(sector+1)) break;
			offset+=(length+16);
		}
		if((*((unsigned char *)d88_fdd+offset+6))!=0) return -1;	// single density disk
		offset+=16;
		break;
	case F_DSK:
		dsk_trk=(HEADER_DSK_TI_t *)((drive==0?&MZ80B_FDD1(0):&MZ80B_FDD2(0))+track_offset[drive][*track]);
		offset=256;
		for(i=0;i<dsk_trk->SPT;i++){
			length=dsk_trk->s_info[i].length;
			if(dsk_trk->s_info[i].sector==(sector+1)) break;
			offset+=length;
		}
		if(length<256) return -1;	// single density disk
		offset+=track_offset[drive][*track];
		break;
	case F_2D:
		offset=((*track)*d_sectors[drive]+sector)*d_length[drive];
		length=d_length[drive];
		break;
	default:
		break;
	}
	for(i=0;i<length;i++){
		*(buf++)=~(*((unsigned char *)(drive==0?&MZ80B_FDD1(0):&MZ80B_FDD2(0))+(offset++)));
	}

	return length;
}

/*
 * ISR for Head Step
 */
void head_step(void)
{

	if((IORD_8DIRECT(REG_BASE, MZ_FD0_REGS+MZ_FDD_STEP)&D_STEP)==D_STEP){
		if((IORD_8DIRECT(REG_BASE, MZ_FD0_REGS+MZ_FDD_STEP)&D_DIRC)==D_DIRC){
			if(d_tnum[0]>0) d_tnum[0]--;
		}else{
			if(d_tnum[0]<41) d_tnum[0]++;
		}
		track_setting(0, d_tnum[0]);
		IOWR_8DIRECT(REG_BASE, MZ_FD0_REGS+MZ_FDD_STEP, D_STEP);	// Flag Clear
	}

	if((IORD_8DIRECT(REG_BASE, MZ_FD1_REGS+MZ_FDD_STEP)&D_STEP)==D_STEP){
		if((IORD_8DIRECT(REG_BASE, MZ_FD1_REGS+MZ_FDD_STEP)&D_DIRC)==D_DIRC){
			if(d_tnum[1]>0) d_tnum[1]--;
		}else{
			if(d_tnum[1]<41) d_tnum[1]++;
		}
		track_setting(1, d_tnum[1]);
		IOWR_8DIRECT(REG_BASE, MZ_FD1_REGS+MZ_FDD_STEP, D_STEP);	// Flag Clear
	}
}

/*
 * Quick Load MZT file
 */
void quick_load(void)
{
	DWORD tadr,size;
	UINT i,r;
	FIL fobj;
	FRESULT res;
	unsigned char *buf;

//	tadr=(IORD(CMT_0_BASE, 1)&0xffff)*2;
//	size=IORD(CMT_0_BASE, 2)&0xffff;
	buf=malloc(size);

	res=f_open(&fobj, tname, FA_OPEN_EXISTING | FA_READ);
	res=f_lseek(&fobj, ql_pt);
	res=f_read(&fobj, buf, size, &r);
//	IOWR_ALTERA_AVALON_PIO_DATA(PAGE_BASE,0);	// Set Page
	for(i=0;i<size;i++){
//		((volatile unsigned char*)(INTERNAL_SRAM2_0_BASE+tadr))[i*2]=buf[i];
	}

	if(f_eof(&fobj)){
		tname[0]='\0';	// Release Tape Data
//		IOWR(CMT_0_BASE, 1, 0);
	}

	res=f_close(&fobj);
	ql_pt+=size;
	free(buf);
}

/*
 * Quick Save MZT file
 */
int quick_save(void)
{
	DWORD tadr,size;
	UINT i,r;
	FIL fobj;
	FRESULT res;
	unsigned char *buf;

//	tadr=(IORD(CMT_0_BASE, 1)&0xffff)*2;
//	size=IORD(CMT_0_BASE, 2)&0xffff;
	buf=malloc(size);

	res=f_open(&fobj, tname, FA_OPEN_ALWAYS | FA_WRITE);
	if(res!=FR_OK) return(res);
	res=f_lseek(&fobj, f_size(&fobj));			// Ready to Append
//	IOWR_ALTERA_AVALON_PIO_DATA(PAGE_BASE,0);	// Set Page
	for(i=0;i<size;i++){
//		buf[i]=((volatile unsigned char*)(INTERNAL_SRAM2_0_BASE+tadr))[i*2];
	}
	res=f_write(&fobj, buf, size, &r);

	res=f_close(&fobj);
	free(buf);
	return(0);
}
