/*
 * MZ-80C on FPGA (Altera DE0 version)
 * Disk I/O routines
 *
 * (c) Nibbles Lab. 2012-2014
 *
 */

#include "sys/alt_stdio.h"
#include "system.h"
#include "altera_avalon_spi.h"
#include "altera_avalon_pio_regs.h"

#include "unistd.h"

#include "diskio.h"
#include "integer.h"

DSTATUS status;

typedef volatile unsigned char *pUBYTE;
typedef volatile unsigned char	UBYTE;

#define SPI_DUMMY_PORT 0
#define SPI_SD_PORT 1

UBYTE EN_BLOCK;

//void buffer_dump(pUBYTE p)
//{
//	UBYTE c;
//	int	i,l;
//	for(i=0;i<512;i=i+16){
/*	for(i=0;i<128;i=i+16){*/
//		for(l=0;l<16;l++){
//			out2h(*(p+i+l));
//		}
//		putss("| ");
//		for (l=0;l<16;l++) {
//			c=*(p+i+l);
//			if ((c>=0x20)&&(c<0x7f)) {
//				send1ch(c);
//			} else {
//				putss(".");
//			}
//		}
//		putss("\r");
//	}
//	putss("\r");
//}

/*
 * Send MMC Access Command
 */
unsigned char mmc_cmd(unsigned char cmd, DWORD addr){
	unsigned char c[6],d;
	unsigned int n;

	// CS=L
	IOWR_ALTERA_AVALON_PIO_DATA(SPI_CS_BASE, 0x00);

	c[0]=0x40+cmd;
	c[1]=(addr >> 24) & 0xff;
	c[2]=(addr >> 16) & 0xff;
	c[3]=(addr >> 8) & 0xff;
	c[4]=addr & 0xff;
	switch(cmd){
	case 0:	c[5]=0x95;
			break;
	case 8: c[5]=0x87;	// addr=0x1aa
			break;
	default: c[5]=0;
			break;
	}
	n=alt_avalon_spi_command(SPI_BASE, SPI_SD_PORT, 6, c, 0, &d, 0);

	c[0]=0xff;
	n=alt_avalon_spi_command(SPI_BASE, SPI_DUMMY_PORT, 0, c, 1, &d, 0);

	//while(d==0xff){
	//	n=alt_avalon_spi_command(SPI_BASE, 1, 0, c, 1, &d, ALT_AVALON_SPI_COMMAND_MERGE);
	//}
	return(d);
}

/*
 * Terminate Command
 */
void mmc_quit(void){
	unsigned char c,d;
	unsigned int n;

	// CS=H
	IOWR_ALTERA_AVALON_PIO_DATA(SPI_CS_BASE, 0x01);

	c=0xff;
	n=alt_avalon_spi_command(SPI_BASE, SPI_DUMMY_PORT, 1, &c, 0, &d, 0);
}

/*
 * Send Command No.5
 */
DSTATUS cmd0(void){
	unsigned char c=0xff, d, r;
	unsigned int i;

	// CMD0
	d=mmc_cmd(0,0);
	//alt_putstr("CMD0 ");
	// wait idle state
	i=0;
	while(d==0xff){
		r=alt_avalon_spi_command(SPI_BASE, SPI_DUMMY_PORT, 0, &c, 1, &d, 0);
		//alt_putstr("W ");
		//alt_printf("%x ",d);
		if(++i==32){
			mmc_quit();	// CS=H
			//alt_putstr("not response.\n");
			status=STA_NOINIT+STA_NODISK;
			return status;
		}
	}

	// check idle state
	while(d!=0x01){
		r=alt_avalon_spi_command(SPI_BASE, SPI_DUMMY_PORT, 0, &c, 1, &d, 0);
		//alt_putstr("w ");
		//alt_printf("%x ",d);
	}
	//alt_putstr("\n");

	mmc_quit();	// CS=H

	return 0;
}

/*
 * Send Command No.55
 */
DSTATUS cmd55(void){
	unsigned char c=0xff, d, r;

	// CMD55
	d=mmc_cmd(55,0);
	//alt_putstr("APP_CMD ");
	// wait busy
	while(d==0xff){
		r=alt_avalon_spi_command(SPI_BASE, SPI_DUMMY_PORT, 0, &c, 1, &d, 0);
		//alt_putstr("W ");
	}

	//alt_printf("%x ",d);
	//alt_putstr("\n");
	mmc_quit();	// CS=H

	return 0;
}

/*
 * Send Command No.41
 */
unsigned char cmd41(DWORD addr){
	unsigned char c=0xff, d, r;

	d=mmc_cmd(41,addr);	// HCS=1
	//alt_putstr("CMD41 ");
	// wait busy
	while(d==0xff){
		r=alt_avalon_spi_command(SPI_BASE, SPI_DUMMY_PORT, 0, &c, 1, &d, 0);
		//alt_putstr("W ");
	}

	//alt_printf("%x ",d);
	//alt_putstr("\n");
	mmc_quit();	// CS=H

	return d;
}

/*
 * Interface Initialize
 */
DSTATUS disk_initialize(
  BYTE Drive          /* 物理ドライブ番号 */
)
{
	unsigned char c=0xff, d, r, dc[10];
	unsigned int i;

	usleep(1000);
	EN_BLOCK=0;		// not block address

	// dummy clock
	for(i=0;i<10;i++) dc[i]=0xff;
	alt_avalon_spi_command(SPI_BASE, SPI_DUMMY_PORT, 10, dc, 0, &d, 0);
	//alt_putstr("Dummy Clock.\n");

	// Software reset
	// CMD0
	if(cmd0()!=0) return status;

	// Initialize I/F
	// CMD8
	d=mmc_cmd(8,0x1aa);
	//alt_putstr("CMD8 ");
	// wait busy
	while(d==0xff){
		r=alt_avalon_spi_command(SPI_BASE, SPI_DUMMY_PORT, 0, &c, 1, &d, 0);
		//alt_putstr("W ");
	}
	//alt_printf("%x ",d);
	r=alt_avalon_spi_command(SPI_BASE, SPI_DUMMY_PORT, 0, &c, 4, dc, 0);
	//alt_printf("%x %x %x %x\n",dc[0],dc[1],dc[2],dc[3]);
	mmc_quit();	// CS=H
	alt_putstr("\n");

	if((d&0x04)==0) {		/* SDC V2 */
		//alt_putstr("This card might be SDHC.\n");
		if((((dc[0]<<24)+(dc[1]<<16)+(dc[2]<<8)+dc[3])&0xfff)!=0x1aa){
			//alt_putstr("Illegal SDHC.\n");
			status=STA_NOINIT;
			return status;
		}

		do{
			// ACMD41
			cmd55();
			d=cmd41(0x40000000);	// HCS=1
		}while(d!=0x00);

		// Read OCR
		d=mmc_cmd(58,0);
		//alt_putstr("CMD58 ");
		// wait busy
		while(d==0xff){
			r=alt_avalon_spi_command(SPI_BASE, SPI_DUMMY_PORT, 0, &c, 1, &d, 0);
			//alt_putstr("W ");
		}
		r=alt_avalon_spi_command(SPI_BASE, SPI_DUMMY_PORT, 0, &c, 4, dc, 0);
		mmc_quit();	// CS=H
		if(dc[0]&0x40) EN_BLOCK=1;	// Enable block address

	} else {

		//alt_putstr("This card might be SD.\n");
		// CMD0
		if(cmd0()!=0) return status;

		do{
			// ACMD41
			cmd55();
			d=cmd41(0);
			if(d&0x04) break;		/* Illegal Command */
		}while(d!=0x00);

		if(d&0x04){	/* Illegal Command ... this card is MMC */
			//alt_putstr("This card might be MMC.\n");
			// CMD0
			if(cmd0()!=0) return status;

			do{
				d=mmc_cmd(1,0);
				//alt_putstr("CMD1 ");
				/* wait busy */
				while(d==0xff){
					r=alt_avalon_spi_command(SPI_BASE, SPI_DUMMY_PORT, 0, &c, 1, &d, 0);
					//alt_putstr("W ");
				}

				mmc_quit();	// CS=H
				//alt_putstr("\n");

			}while(d!=0x00);
		}

		/* CMD16 */
		d=mmc_cmd(16,512);
		//alt_putstr("CMD16 ");
		/* wait busy */
		while(d==0xff){
			r=alt_avalon_spi_command(SPI_BASE, SPI_DUMMY_PORT, 0, &c, 1, &d, 0);
			//alt_putstr("W ");
		}

		//alt_putstr("\n");
		mmc_quit();	// CS=H
	}

	status=0;
	return 0;

}

/*
 * Read Status
 */
DSTATUS disk_status(
  BYTE Drive          /* 物理ドライブ番号 */
)
{
	return status;
}

/*
 * Read 1 Sector
 */
DRESULT disk_read(
  BYTE Drive,          // 物理ドライブ番号
  BYTE* Buffer,        // 読み出しバッファへのポインタ
  DWORD SectorNumber,  // 読み出し開始セクタ番号
  BYTE SectorCount     // 読み出しセクタ数
)
{
	BYTE i,c;
	DWORD SN;
	unsigned char dc[2],d;
	unsigned short r;
	//pUBYTE buf;

	if(status!=0) return RES_NOTRDY;

	//buf=Buffer;

	for(i=0;i<SectorCount;i++){
		SN= EN_BLOCK==1 ? SectorNumber : (SectorNumber<<9);
		d=mmc_cmd(17, SN);
		SectorNumber++;
		// wait busy
		while(d==0xff){
			r=alt_avalon_spi_command(SPI_BASE, SPI_DUMMY_PORT, 0, &c, 1, &d, 0);
			//alt_putstr("W ");
		}
		if(d!=0x00){
			//putss("1e\r");
			mmc_quit();	// CS=H
			return RES_ERROR;
		}
		//putss("1\r");

		// wait token
		do{
			r=alt_avalon_spi_command(SPI_BASE, SPI_DUMMY_PORT, 0, &c, 1, &d, 0);
			//alt_putstr("W ");
		}while(d==0xff);
		if(d<0x80){
			//putss("2e\r");
			mmc_quit();	// CS=H
			return RES_ERROR;
		}
		//putss("2\r");
		r=alt_avalon_spi_command(SPI_BASE, SPI_DUMMY_PORT, 0, &c, 512, Buffer, 0);
		Buffer+=512;

		// CRC
		r=alt_avalon_spi_command(SPI_BASE, SPI_DUMMY_PORT, 0, &c, 2, dc, 0);

		mmc_quit();	// CS=H
	}


	//buffer_dump(Buffer);
	return RES_OK;
}

/*
 * Write 1 Sector
 */
DRESULT disk_write(
  BYTE Drive,          // 物理ドライブ番号
  const BYTE* Buffer,  // 書き込むデータへのポインタ
  DWORD SectorNumber,  // 書き込み開始セクタ番号
  BYTE SectorCount     // 書き込みセクタ数
)
{
	BYTE i,c;
	DWORD SN;
	unsigned char dc[3],d;
	unsigned short r;

	if(status!=0) return RES_NOTRDY;

	for(i=0;i<SectorCount;i++){
		SN= EN_BLOCK==1 ? SectorNumber : (SectorNumber<<9);
		d=mmc_cmd(24, SN);
		SectorNumber++;
		// wait busy
		while(d==0xff){
			r=alt_avalon_spi_command(SPI_BASE, SPI_DUMMY_PORT, 0, &c, 1, &d, 0);
			//alt_putstr("W ");
		}
		if(d!=0x00){
			//putss("1e\r");
			mmc_quit();	// CS=H
			return RES_ERROR;
		}

		// wait and send token
		dc[0]=0xff; dc[1]=0xff; dc[2]=0xfe;
		r=alt_avalon_spi_command(SPI_BASE, SPI_SD_PORT, 3, dc, 0, &d, 0);

		r=alt_avalon_spi_command(SPI_BASE, SPI_SD_PORT, 512, Buffer, 0, &d, 0);
		Buffer+=512;

		// CRC
		r=alt_avalon_spi_command(SPI_BASE, SPI_SD_PORT, 2, dc, 0, &d, 0);
		do{
			r=alt_avalon_spi_command(SPI_BASE, SPI_DUMMY_PORT, 0, &c, 1, &d, 0);
			//alt_putstr("W ");
			if((d&0x1f)==0x0d) return RES_ERROR;
		}while(d!=0xff);
		mmc_quit();	// CS=H
	}

	return RES_OK;
}

/*
 * Disk Control
 */
DRESULT disk_ioctl (
  BYTE Drive,      /* 物理ドライブ番号 */
  BYTE Command,    /* 制御コマンド */
  void* Buffer     /* データ受け渡しバッファ */
)
{
	return RES_OK;
}

/*
 * Get Time
 */
DWORD get_fattime(void)
{
	return 0x36210000;	// 2007/1/1 0:00:00
}
