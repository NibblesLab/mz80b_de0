MZ-80B on FPGA
=============

What is this?
-------------------
This is a implementation Sharp MZ-80B/MZ-2000 series to FPGA.

Requirements
--------------------
* Altera(Terasic) DE0 board
* Quartus II (I use 13.1.4, 64bit)
* SD, SDHC or MMC card

How to reproduction project
----------------------------------------
1. Download [zip](https://github.com/NibblesLab/mz80b_de0/archive/master.zip) file.
* Create folder to build project in your PC.
* Put these files in zip to folder.
    * logic/
    * internal\_sram\_hw.tcl
    * internal\_sram8\_hw.tcl
    * mz80b.cdf
    * mz80b.pin
    * mz80b.qsf
    * mz80b.sdc
    * mz80b.qpf
    * mz80b\_de0.qsys
* Start Quartus II.
* Open project. File->Open Project...->mz80b_de0.qpf
* Start Qsys. Tools->Qsys
* Start Ganerate. Generate->Generate...
* Select "VHDL" on Synthesis part, then push Generate button.
* When generate successfully, exit Qsys. Ignore warning about CFI and uart.
* Start Compilation at Quartus II.
* Program to DE0 board with mz80b.pof.
* Start NiosII EDS. Tools->Nios II Software Build Tools for Eclipse
* When does PC ask workspace, push OK as it is.
* Create new application and BSP. File->New->Nios II Application and BSP from Template
* Set parameters and push Finish button.
    * SOPC Information File name:->mz80b\_de0.sopcinfo
    * CPU name:->NiosII
    * Project name:->mz80b\_de0\_soft
    * Project template->Hello World
* Put these files in zip(software/mz80b\_de0\_soft/*) to software/mz80b\_de0\_soft folder.
    * diskio.c
    * diskio.h
    * ff.c
    * ff.h
    * ffconf.h
    * file.c
    * file.h
    * integer.h
    * key.c
    * key.h
    * menu.c
    * menu.h
    * mz80b\_de0\_main.c
    * mz80b\_de0\_main.h
    * mzctrl.c
    * mzctrl.h
* Delete hello\_world.c.
* At Project Explorer, expand mz80b\_de0\_soft, then right-click and select Refresh(F5).
* Build project. Project->Build All
* Program to DE0 board with mz80b\_de0\_soft.elf.
* Put the files in CARD folder to SD/MMC card.
* Set card to slot, SW5 is ON(upper), then push power-switch off-on.

Special thanks to ...
-----------------------------
* Z80 core ''T80'' from OpenCores by Wllnar, Daniel and MikeJ
* ''Looks like font'' from [MZ700WIN](http://retropc.net/mz-memories/) by marukun
* [FatFs module](http://elm-chan.org/fsw/ff/00index_j.html) by ChaN
* [Japan Andriod Group Kobe](http://sites.google.com/site/androidjpkobe/)