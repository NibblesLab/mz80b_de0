/*
 * MZ-80B on FPGA (Altera DE0 version)
 * Main module header
 *
 * (c) Nibbles Lab. 2013-2014
 *
 */

#ifndef MZ80B_DE0_MAIN_H_
#define MZ80B_DE0_MAIN_H_

typedef struct {
	unsigned char char80b[2048];
	char char80b_name[13];
	unsigned char key80b[256];
	char key80b_name[13];
} ROMS_t;

#define version "0.2"
#define MZ80B_MEM(i) ((unsigned char*)(0xfe0000))[i]
#define MZ80B_GRAM(i) ((unsigned char*)(0xfd0000))[i]

#endif /* MZ80B_DE0_MAIN_H_ */
