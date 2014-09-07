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
char fname[13],tname[13],dname1[13],dname2[13];
DWORD t_bpos[10];		// block positions of every blocks
int t_bnum;			// exist blocks in tape file
int t_block;		// current block number
DWORD tremain;		// current block remaining size
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
	return(r);
}

/*
 * Force put memory from MZT file
 */
void direct_load(void)
{
	UINT i,r,size,dtadr;
	unsigned char buf[65536];

	// File Read
	r=file_bulk_read((TCHAR *)fname, buf, 65536);

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

/*
 * ROM data setting
 */
void set_rom(int select){
	alt_flash_fd *fd;
	ROMS_t romdata;
	int i;
	unsigned char *buf;
	char *name;
	UINT r;

	for(i=0;i<sizeof(ROMS_t);i++)
		((char *)&romdata)[i]=((char *)(CFI_BASE+0x100000))[i];

	switch(select){
	case 40:
		buf=romdata.char80b;
		name=romdata.char80b_name;
		break;
	case 41:
		buf=romdata.key80b;
		name=romdata.key80b_name;
		break;
	default:
		break;
	}

	// File Read
	r=file_bulk_read((TCHAR *)fname, buf, 4096);
	strcpy(name, "            ");
	strcpy(name, fname);

	fd=alt_flash_open_dev(CFI_NAME);
	if(fd)
		alt_write_flash(fd, 0x100000, (char *)&romdata, sizeof(ROMS_t));
	alt_flash_close_dev(fd);
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
		size=(*(buf+0x13))<<8+*(buf+0x12)+128;
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
			usleep(600000);
			if((z80_sts.status&S_CMT)==S_CMT){
				while((IORD_8DIRECT(REG_BASE, MZ_CMT_CTRL)&C_FF)!=0);
				z80_sts.status&=~S_CMT;
			}
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
	unsigned char buf[128];
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
