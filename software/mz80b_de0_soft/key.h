/*
 * MZ-80C on FPGA (Altera DE0 version)
 * PS/2 Keyboard Input routines header
 *
 * (c) Nibbles Lab. 2012-2014
 *
 */

#ifndef KEY_H_
#define KEY_H_

//typedef struct {
//	unsigned char kcode[32];
//	unsigned int wptr;
//	unsigned int rptr;
//	unsigned int flagf0;
//	unsigned int flage0;
//	unsigned int Lshift;
//	unsigned int Rshift;
//} keyb_t;

//void key_int_regist(void);
unsigned char get_key(void);
void key0(unsigned char *);
void keybuf_clear(void);

#endif /* KEY_H_ */
