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
void quick_load(void);
int quick_save(void);

#endif /* FILE_H_ */
