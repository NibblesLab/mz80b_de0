/*
 * MZ-80C on FPGA (Altera DE0 version)
 * File Access routines header
 *
 * (c) Nibbles Lab. 2012
 *
 */

#ifndef FILE_H_
#define FILE_H_

void sd_mount(void);
UINT file_bulk_read(char *, unsigned char *, UINT);
void direct_load(void);
void set_rom(int);
void clear_rom(int);
void GetPrivateProfileString(char *, char *, char *, char *, const char *);
DWORD GetPrivateProfileInt(char *, char *, DWORD, const char *);
int tape_mount(void);
int tape_unmount(void);
void tape_rdinf_bulk(unsigned char *);
void tape_rddat_bulk(unsigned char *, UINT);
void tape_rewind(void);
int cmtload(void);
void apss_f(void);
void apss_r(void);
void fd_mount(int);
void fd_unmount(int);
int read_1sector(int, int, unsigned char *, unsigned int *);
void track_setting(int, int);
void head_step(void);
void quick_load(void);
int quick_save(void);

// D88-format header
typedef struct {
	unsigned char name[17];
	char reserve[9];
	unsigned char wp_flag;
	unsigned char kind;
	unsigned int size;
	unsigned int t_track[164];
} HEADER_D88_t;

// DSK-format Disk Information
typedef struct {
	unsigned char disk_name[34];
	unsigned char tool_name[14];
	unsigned char tracks;
	unsigned char heads;
	char reserve[2];
	unsigned char track_size[204];
} HEADER_DSK_DI_t;

// DSK-format Sector Information
typedef struct {
	unsigned char track;
	unsigned char head;
	unsigned char sector;
	unsigned char BPS;
	unsigned char error1;
	unsigned char error2;
	unsigned short length;
} HEADER_DSK_SI_t;

// DSK-format Track Information
typedef struct {
	unsigned char track_name[13];
	char reserve1[3];
	unsigned char track;
	unsigned char head;
	char reserve2[2];
	unsigned char BPS;
	unsigned char SPT;
	unsigned char GAP3;
	unsigned char fill;
	HEADER_DSK_SI_t s_info[29];
} HEADER_DSK_TI_t;

#define F_NULL 0
#define F_D88 1
#define F_DSK 2
#define F_2D 3

#endif /* FILE_H_ */
