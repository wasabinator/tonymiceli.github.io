*********************************************************
*     MegaView - IFF/GIF file/download displayer.       *
*     -------------------------------------------       *
*                                                       *
*           Written by Tony Miceli 30/12/91             *
*               Version 2.40b  21/5/93                  *
*               Written using devpac 2                  *
*                                                       *
*          CLI Usage : MEGAVIEW filename1 filename2 ... *
*    Workbench Usage : a) Set MEGAVIEW as default tool  *
*                                      OR               *
*                      b) Shift click on picture icons, *
*                         then double-click on program. *
*                                                       *
* FEATURES:                                             *
*                                                       *
*  o Scrolls bitmaps which are larger than the screen.  *
*  o Automatic fading of non-HAM screens.               *
*  o Supports IFF/GIF format files.                     *
*  o 256 colour GIF files converted to 16 grey shades.  *
*  o Full colour GIF/HAM8 support for AGA equipped      *
*    systems.                                           *
*  o Can monitor and view IFF/GIF modem downloads.      *
*  o CLI/Workbench driven.                              *
*  o Compatible with workbench 1.2/1.3/2.0/3.0.         *
*  o Full screenmode database support under 2.0+        *
*                                                       *
*********************************************************

                INCDIR  Work:Programming/Devpac/Include/Include

                include exec/exec.i
                include exec/exec_lib.i
                include graphics/gfx.i
                include graphics/graphics_lib.i
                include graphics/displayinfo.i
                ;include        graphics/view.i
                include intuition/intuition.i
                include intuition/intuition_lib.i
                include intuition/screens.i
                include libraries/dos.i
                include libraries/dosextens.i
                include libraries/dos_lib.i
                include libraries/asl.i
                include libraries/asl_lib.i
                include workbench/icon_lib.i

;program constants

FadeSpeed_AGA   equ     2       1 = slowest speed (= 1/2/4/8/16/32/64/128)
FadeSpeed_STD   equ     4       1 = slowest speed (= 1/2/4/8/16/32/64/128)
bufsize         equ     8192    read buffer size (the bigger, the faster!)
DL_Mode         equ     0       flag number for DL mode
WB_Mode         equ     1       flag number for WB mode
WB_2.0          equ     2       set if running under workbench v2.0+
WB_3.0          equ     3       set if running under workbench v3.0+
IFF             equ     4       flag for IFF format file
GIF             equ     5       flag for GIF format file
DL_IN_PROGRESS  equ     6       flag to say dl initiated
NTSC_Mode       equ     7       set if running on a 60Hz NTSC amiga

GIF_INTERLACED  equ     0       GIF flag for interlace
GIF_GREYSCALE   equ     1       GIF flag for greyscale
WINDOW_WIDTH    equ     355     Width of main program window
WINDOW_HEIGHT   equ     74      Height of main program window

;system constants

sm_NumArgs      equ     $1c
sm_ArgList      equ     $24
wa_Name         equ     4

;exec library base, offsets and constants

execbase        equ     4

lib_Version     equ     20
mp_SigBit       equ     15              signal bit for the task
TC_SPLower      equ     58
TC_SPUpper      equ     62
TC_Size         equ     92

;intuition library offsets & constants

DRAGBAR         equ     $0002
DEPTHGADGET     equ     $0004
CLOSEGADGET     equ     $0008

JAM1            equ     0

;graphics library offsets and constants

NORMAL          equ     0               font style
ROMFONT         equ     $0001           font flag

_LVOSetRGB32    equ     -$0354
_LVOLoadRGB32   equ     -$0372

;viewmode bit definitions

VB_LACE            = 2
VB_SUPERHIRES      = 5
VB_EXTRA_HALFBRITE = 7
VB_HAM             = 11
VB_HIRES           = 15

;reqtools library offsets and constants

RtAllocRequestA equ     -30             function offsets
RtFreeRequest   equ     -36
RtFileRequestA  equ     -54

rtfr_Flags      equ     8               filerequester structure offsets
rtfr_Dir        equ     rtfr_Flags+8
rtfr_MatchPat   equ     rtfr_Dir+4
rtfr_ReqHeight  equ     rtfr_MatchPat+26

RT_FILEREQ      equ     0               filerequester indicator

FREQF_MULTISELECT =     1
FREQF_PATGAD    equ     16

REQPOS_CENTERWIN  =     1

RT_REQPOS       equ     $80000003       tags for use with reqtools library
RT_UNDERSCORE   equ     $8000000b

RTFI_FLAGS      equ     $80000028
RTFI_HEIGHT     equ     $80000029
RTFI_OKTEXT     equ     $8000002a

;workbench library constants

do_ToolTypes    equ     54

*************** START   OF   PROGRAM ***************

start           move.l  a7,Initial_SP   save intial stack pointer
                movem.l d0/a0,-(a7)     push d0 & a0 onto stack

                movea.l (execbase).w,a6
                bclr.b  #NTSC_Mode,Run_Mode
                cmpi.b  #60,VBlankFrequency(a6) check if running on
                bne.s   itsPAL                  a poor old NTSC Amiga
                bset.b  #NTSC_Mode,Run_Mode
                
itsPAL          lea     dosname(pc),a1
                clr.l   d0
                jsr     _LVOOpenLibrary(a6)
                move.l  d0,dosbase
                bne.s   1$
                addq    #8,a7           fix stack
                rts                     exit if couldn't open dos library

1$              lea     iconname(pc),a1
                clr.l   d0
                jsr     _LVOOpenLibrary(a6)
                move.l  d0,iconbase
                bne.s   2$
                bra     Cleanup

2$              move.b  #%00100101,PreferenceModes      setup defaults

                suba.l  a1,a1
                jsr     _LVOFindTask(a6)        find this task
                move.l  d0,TaskCB       save address of task control block
                
                movea.l d0,a0           a0 = task pointer
                tst.l   pr_CLI(a0)      run from CLI?
                bne     runCLI
                
                addq    #8,a7           adjust stack pointer
                
                bset.b  #WB_Mode,Run_Mode

                lea     pr_MsgPort(a0),a0       ptr to workench message port
                move.l  a0,-(a7)
                jsr     _LVOWaitPort(a6)
                movea.l (a7)+,a0
                jsr     _LVOGetMsg(a6)          get wb_startup message
                move.l  d0,WBmessage

                movea.l d0,a0
                move.l  sm_NumArgs(a0),d0
                movea.l sm_ArgList(a0),a0
                move.l  a0,a2
                subq.l  #1,d0
                move.l  d0,NumArgs
                beq.s   get_wb_tools

                addq    #8,a0           skip first arg (progname arg)
get_wb_args     move.l  (a0)+,-(a7)     lock
                move.l  (a0)+,-(a7)     fnameptr
                subq.l  #1,d0           do for remaining args
                bne.s   get_wb_args

get_wb_tools    move.l  (a2),d1         program lock
                movea.l dosbase(pc),a6
                jsr     _LVOCurrentDir(a6)
                
                movea.l 4(a2),a0        a0->program name
                movea.l iconbase(pc),a6
                jsr     _LVOGetDiskObject(a6)
                move.l  d0,DiskObjectptr
                beq.s   1$
                move.l  d0,a0
                movea.l do_ToolTypes(a0),a0
                cmpa.w  #0,a0
                beq.s   2$
                bsr     CheckToolTypes
2$              movea.l DiskObjectptr(pc),a0
                movea.l iconbase(pc),a6
                jsr     _LVOFreeDiskObject(a6)
1$              bra.s   proceed

runCLI          movem.l (a7)+,d0/a0     pop d0 & a0 off stack
get_args        subq.w  #1,d0           skip past trailing CR ($0a) char
arg_loop        subq.w  #1,d0
                bmi.s   end_arg_loop
next_arg        cmpi.b  #$20,0(a0,d0)   skip spaces between filenames
                beq.s   arg_loop
                clr.b   1(a0,d0)        set end of filename+1 to null
scan_arg        subq.w  #1,d0
                bmi.s   push_arg
                cmpi.b  #$20,0(a0,d0)   scan for start of filename
                bne.s   scan_arg
push_arg        move.l  #0,-(a7)        push dummy lock (for wb-startup)
                lea     1(a0,d0),a1
                move.l  a1,-(a7)        push address of filename on stack
                addq.l  #1,NumArgs
                tst.w   d0
                bpl.s   next_arg
end_arg_loop    tst.l   NumArgs
                bne.s   proceed

ListHelp        movea.l dosbase(pc),a6
                jsr     _LVOOutput(a6)  find stdout
                move.l  d0,d1           d1 = output handle
                beq.s   1$              no output handle?
                move.l  #Help_Msg,d2    d2 = buffer
                move.l  #Help_Len,d3    d3 = length
                jsr     _LVOWrite(a6)
1$              movea.l a6,a1
                movea.l (execbase).w,a6
                jsr     _LVOCloseLibrary(a6)
                clr.l   d0
                rts

proceed         movea.l (execbase).w,a6
                lea     grname(pc),a1
                clr.l   d0
                jsr     _LVOOpenLibrary(a6)
                move.l  d0,grbase
                beq.s   TerminateProg
                
                lea     intuition(pc),a1
                clr.l   d0
                jsr     _LVOOpenLibrary(a6)
                move.l  d0,intuitionbase
                beq.s   TerminateProg

                lea     reqtoolsname(pc),a1
                moveq.l #37,d0
                jsr     _LVOOpenLibrary(a6)
                move.l  d0,ReqToolsBase
                beq.s   1$
                movea.l d0,a6
                moveq.l #RT_FILEREQ,d0
                suba.l  a0,a0                   no taglist
                jsr     RtAllocRequestA(a6)     allocate a requester
                move.l  d0,ReqPtr
                bra.s   2$

1$              lea     aslname(pc),a1          libname
                moveq.l #37,d0                  version
                jsr     _LVOOpenLibrary(a6)     attempt to open asl library
                move.l  d0,AslBase
                beq.s   2$
                movea.l d0,a6
                moveq.l #ASL_FileRequest,d0
                lea     ASLTagList(pc),a0
                jsr     _LVOAllocAslRequest(a6) allocate a requester
                move.l  d0,ReqPtr

2$              moveq   #MEMF_PUBLIC,d1
                move.l  #bufsize,d0
                move.l  (execbase).w,a6
                jsr     _LVOAllocMem(a6)        allocate disk-read buffer
                move.l  d0,buffer               MUST be done!
                bne.s   AllocOK                 Even if in DL MODE!!

                move.w  #BUFFER_RAM,d0          couldn't allocate buffer RAM
                bsr     DisplayError
TerminateProg   move.l  #1,NumArgs
                bra     QuitProg

AllocOK         bsr     SetUpWindow             draw main window
                movea.l windowptr(pc),a0
                movea.l wd_UserPort(a0),a0
                move.l  a0,UserPort1
                
                move.b  mp_SigBit(a0),d0        get userport's signal bit
                move.b  d0,Signal_1             save it for later
                clr.l   d1
                bset    d0,d1                   calculate its signal mask
                move.l  d1,SignalMask           save it

View_Loop       clr.b   FileError
                btst.b  #DL_Mode,Run_Mode
                bne     Show_DL_msg

                tst.l   NumArgs                 no wb args given?
                bne.s   4$
                move.l  #1,NumArgs
                bra     ExitProg

4$              movea.l dosbase(pc),a6
                movea.l (a7)+,a0                ptr to filename
                move.l  a0,filename
                bsr     CopyFilename
                move.l  (a7)+,d1                d1 = lock
                beq.s   2$                      skip if CLI dummy-lock
;               cmpi.l  #-1,d1                  reqtools file? (lock = -1)
;               bne.s   1$
;               move.l  ReqPtr(pc),a0           pointer to requester
;               move.l  rtfr_Dir(a0),d1         pointer to dir name
;               moveq.l #ACCESS_READ,d2
;               jsr     _LVOLock(a6)            lock the directory
;               move.l  d0,d1
;               jsr     _LVOCurrentDir(a6)
;               move.l  d0,d1
;               jsr     _LVOUnLock(a6)
;               bra.s   2$

1$              jsr     _LVOCurrentDir(a6)      set current directory

2$              movea.l filename(pc),a0         ptr to arg/fname
                bsr     CheckForArg             interpret commandline switch
                bne     MainArgLoop             skip viewer if command switch

                bsr     ClearWindow             paint the window
                bsr     DrawFilename
                move.l  filename(pc),d1
                move.l  #MODE_OLDFILE,d2        use to be proceed:
                movea.l dosbase(pc),a6
                jsr     _LVOOpen(a6)            open IFF file
                move.l  d0,filehandle
                
3$              tst.l   filehandle
                bne.s   CanGetFname

                move.w  #FILE_NOT_FOUND,d0      file not found error
                bsr     DisplayError
                bra     ExitProg

DL_Loop         
Show_DL_msg     move.w  #WAITING_FOR_DL,d0      display: waiting for download
                bsr     DisplayError
                clr.l   filename
                clr.l   filehandle
                bsr     ClearWindow             paint the window

CanGetFname
Not_DL          bsr     ReadFile
                beq.s   load_ok                 check for errors

                cmpi.w  #END_OF_FILE,d0         show partially loaded pic
                beq.s   load_ok

                move.l  d0,-(a7)
                bsr     CleanupDisplay
                move.l  (a7)+,d0
                bsr     DisplayError            display the error

                cmpi.w  #TERMINATE_NOW,d0       closescreen selected?
                bne.s   load_ok
                move.l  #1,NumArgs
                bra     ExitProg

load_ok         movea.l (execbase).w,a6         deallocate old DL buffer
                move.l  buffer_size(pc),d0
                movea.l DL_buffer(pc),a1
                cmpa.w  #0,a1
                beq.s   1$
                jsr     _LVOFreeMem(a6)
                clr.l   DL_buffer               allow close to occur in DL

1$              tst.b   foundChunks
                bne.s   2$
                btst.b  #DL_Mode,Run_Mode
                beq.s   ExitProg
                bra.s   DL_Loop

2$              move.b  foundChunks(pc),d6

                btst.b  #GIF,Run_Mode           was a GIF load attempted?
                beq.s   3$
                btst    #0,d6                   was screen displayed?
                bne.s   File_OK                 yes, display screen
                bra.s   ExitProg

3$              btst    #0,d6
                bne.s   BMHD_OK

                move.w  #BMHD_MISSING,d0
                bsr     DisplayError            missing BMHD chunk

BMHD_OK         btst    #1,d6
                bne.s   CMAP_OK

                move.w  #CMAP_MISSING,d0
                bsr     DisplayError            missing CMAP chunk

CMAP_OK         btst    #3,d6
                bne.s   BODY_OK

                move.w  #BODY_MISSING,d0
                bsr     DisplayError            missing BODY chunk

BODY_OK         btst    #1,FileError
                bne.s   ExitProg

File_OK         btst.b  #DL_Mode,Run_Mode
                bne.s   1$
                bsr     ShowPic         show the bitmap
1$              bsr     CleanupDisplay  free the display structures
                btst.b  #DL_Mode,Run_Mode
                bne     DL_Loop

ExitProg        btst.b  #DL_Mode,Run_Mode
                beq.s   1$

                bsr     UnpatchDOS
                beq.s   QuitProg        check for DOS vectors altered
                bsr     DisplayError    Display error
                bra     CanGetFname     don't return if couldn't release
                                        ;DL-patch
1$              move.l  filehandle(pc),d1       close file
                beq.s   MainArgLoop
                movea.l dosbase(pc),a6
                jsr     _LVOClose(a6)           

MainArgLoop     subq.l  #1,NumArgs
                bne     View_Loop
                btst.b  #DL_Flag,PreferenceModes
                beq.s   QuitProg
                bsr     View_DL_Mode
                bclr.b  #DL_Flag,PreferenceModes
                bra     DL_Loop

QuitProg        bsr     Cleanup
                movea.l Initial_SP(pc),a7
                movea.l (execbase).w,a6
                tst.l   WBmessage
                beq.s   1$
                jsr     _LVOForbid(a6)
                movea.l WBmessage(pc),a1
                jsr     _LVOReplyMsg(a6)
                jsr     _LVOPermit(a6)
1$              clr.l   d0              return-code = 0
                rts

*****************************************************************
*                                                               *
* CleanupDisplay - Closes window and screen structures used to  *
*                  display the picture.                         *
*                                                               *
*****************************************************************

CleanupDisplay  movea.l screenptr(pc),a0
                cmpa.w  #0,a0
                beq.s   free_bitmap
                movea.l intuitionbase(pc),a6    send screen to back
                jsr     _LVOScreenToBack(a6)    to avoid glitching

                movea.l windowptr2(pc),a0       close IDCMP window
                cmpa.w  #0,a0
                beq.s   close_screen
                jsr     _LVOCloseWindow(a6)
                clr.l   windowptr2

close_screen    movea.l screenptr(pc),a0        close display screen
                jsr     _LVOCloseScreen(a6)
                clr.l   screenptr

free_bitmap     movea.l grbase(pc),a6
                lea     bm_Planes1(pc),a2
                move.w  #7,d7                   up to 8 planes
                movea.l grbase(pc),a6
FreeRasters     move.w  iWidth(pc),d0
                move.w  iHeight(pc),d1
                tst.l   (a2)                    no more planes left?
                beq.s   FreeCTable
                movea.l (a2),a0                 a0 = plane (n)
                jsr     _LVOFreeRaster(a6)
                clr.l   (a2)+
                dbf     d7,FreeRasters

FreeCTable      movea.l (execbase).w,a6
                movea.l ColourTab(pc),a1
                cmpa.w  #0,a1
                beq.s   1$
                move.l  ColourTabSize(pc),d0
                jsr     _LVOFreeMem(a6)
                clr.l   ColourTab
1$              movea.l BlankColourTab(pc),a1
                cmpa.w  #0,a1
                beq.s   2$
                move.l  ColourTabSize(pc),d0
                jsr     _LVOFreeMem(a6)
                clr.l   BlankColourTab
2$              rts

*****************************************************************
*                                                               *
*       Cleanup - Deallocates memory used by program, and       *
*                 closes all open libraries.                    *
*                                                               *
*****************************************************************

Cleanup         movea.l (execbase).w,a6
                move.b  Signal_3(pc),d0
                beq.s   free_buffer
                jsr     _LVOFreeSignal(a6)      free task signal

free_buffer     move.l  #bufsize,d0             deallocate buffer
                movea.l buffer(pc),a1
                cmpa.w  #0,a1
                beq.s   close_asl
                jsr     _LVOFreeMem(a6)

close_asl       movea.l AslBase(pc),a6
                cmpa.w  #0,a6
                beq.s   close_reqtools
                movea.l ReqPtr(pc),a0
                cmpa.w  #0,a0
                beq.s   1$
                jsr     _LVOFreeAslRequest(a6)
1$              movea.l a6,a1
                movea.l (execbase).w,a6
                jsr     _LVOCloseLibrary(a6)

close_reqtools  movea.l ReqToolsBase(pc),a6
                cmpa.w  #0,a6
                beq.s   close_font
                movea.l ReqPtr(pc),a1
                cmpa.w  #0,a1
                beq.s   1$
                jsr     RtFreeRequest(a6)
1$              movea.l a6,a1
                movea.l (execbase).w,a6
                jsr     _LVOCloseLibrary(a6)

close_font      movea.l TextFont1(pc),a1
                cmpa.w  #0,a1
                beq.s   close_window1
                movea.l grbase(pc),a6
                cmpa.w  #0,a6
                beq.s   close_window1
                jsr     _LVOCloseFont(a6)       close ROM font

close_window1   movea.l intuitionbase(pc),a6    close window
                movea.l windowptr(pc),a0
                cmpa.w  #0,a0
                beq.s   close_intuition
                jsr     _LVOCloseWindow(a6)

close_intuition movea.l a6,a1                   close intuition library
                cmpa.w  #0,a1
                beq.s   CloseGFX
                movea.l (execbase).w,a6
                jsr     _LVOCloseLibrary(a6)

CloseGFX        movea.l grbase(pc),a1           close graphics library
                cmpa.w  #0,a1
                beq.s   CloseDOS
                movea.l (execbase).w,a6
                jsr     _LVOCloseLibrary(a6)
                
CloseDOS        movea.l dosbase(pc),a1          close DOS library
                cmpa.w  #0,a1
                beq.s   CloseIcon
                move.l  DirLock(pc),d1
                beq.s   1$
                movea.l a1,a6
                jsr     _LVOUnLock(a6)
                movea.l a6,a1           
1$              movea.l (execbase).w,a6
                jsr     _LVOCloseLibrary(a6)

CloseIcon       movea.l iconbase(pc),a1         close Icon library
                cmpa.w  #0,a1
                beq.s   1$
                movea.l (execbase).w,a6
                jsr     _LVOCloseLibrary(a6)

1$              rts

*****************************************************************
*                                                               *
*       View_DL_Mode - Activates download scanning mode.        *
*                                                               *
*****************************************************************
                
View_DL_Mode    bset.b  #DL_Mode,Run_Mode
                bsr     PatchDOS
                moveq   #-1,d0
                movea.l (execbase).w,a6
                jsr     _LVOAllocSignal(a6)
                move.b  d0,Signal_3
                move.l  SignalMask(pc),d1       recalculate signal mask value
                bset    d0,d1
                move.l  d1,SignalMask
                rts

*****************************************************************
*                                                               *
*       CopyFilename - Copies filename text into buffer.        *
*                                                               *
* INPUTS: a0 = ptr to filename.                                 *
*                                                               *
*****************************************************************

CopyFilename    movem.l d0/a1,-(a7)

                tst.b   (a0)
                beq.s   no_fname

                movea.l a0,a1
                cmp.b   #'"',(a0)       remove leading "
                bne.s   NameLoop
                addq    #1,a0
                movea.l a1,a0

NameLoop        cmp.b   #':',(a1)
                beq.s   NameLoop2
                cmp.b   #'/',(a1)
                beq.s   NameLoop2
                tst.b   (a1)
                beq.s   NameLoop3
                
                addq    #1,a1
                bra.s   NameLoop

NameLoop2       addq    #1,a1
                movea.l a1,a0
                bra.s   NameLoop

NameLoop3       lea     filename_buf(pc),a1
                moveq.w #31,d0

1$              tst.b   (a0)
                beq.s   no_fname
                cmpi.b  #'"',(a0)
                beq.s   no_fname
                move.b  (a0)+,(a1)+
                dbf     d0,1$

no_fname        clr.b   (a1)+

                movem.l (a7)+,d0/a0
                rts

*****************************************************************
*                                                               *
*       SetUpWindow - Creates initial window display            *
*                                                               *
* INPUTS: None.                                                 *
* OUTPUT: d0 =  0 if window could not be opened.                *
*         d0 <> 0 if no error occurred.                         *
*                                                               *
*****************************************************************

SetUpWindow     move.l  #$00010203,Pens         set kick1.3 pen numbers
                move.b  Pen1(pc),d0
                move.b  Pen2(pc),d1
                bclr.b  #WB_2.0,Run_Mode
                movea.l dosbase(pc),a0
                cmpi.w  #37,lib_Version(a0)     workbench v2.0+?
                blt.s   notv2.0
                move.l  #$00020103,Pens         set kick2.0 pen numbers
                exg     d0,d1                   swap pen colours
                bset.b  #WB_2.0,Run_Mode
                bclr.b  #WB_3.0,Run_Mode
                cmpi.w  #39,lib_Version(a0)
                blt.s   notv3.0
                bset.b  #WB_3.0,Run_Mode
notv3.0
notv2.0         movea.l intuitionbase(pc),a6
                movea.l ib_FirstScreen(a6),a0
1$              cmpa.w  #0,a0
                beq.s   NoScreen
                move.w  sc_Flags(a0),d0
                andi.w  #SCREENTYPE,d0
                cmpi.w  #WBENCHSCREEN,d0
                beq.s   2$
                movea.l (a0),a0                 locate nextscreen
                bra.s   1$

2$              move.w  sc_Width(a0),d0
                subi.w  #WINDOW_WIDTH,d0
                lsr.w   #1,d0                   xpos=(ns_width-width)/2
                move.w  d0,window_xpos

                move.w  sc_Height(a0),d0
                move.w  d0,d1
                subi.w  #WINDOW_HEIGHT,d0
                lsr.w   #1,d0                   ypos=(ns_height-height)/2
                move.w  d0,window_ypos

                subi.w  #20,d1
                move.w  d1,ReqReqHeight+2       calc reqtools req height
                move.w  d1,AslReqHeight+2       calc asl requester height

                move.w  sc_Width(a0),d0
                subi.w  #318,d0
                lsr.w   #1,d0
                move.w  d0,AslReqLeftEdge+2

NoScreen        lea     NewWindow1(pc),a0
                jsr     _LVOOpenWindow(a6)
                move.l  d0,windowptr
                beq     BadOpen

                movea.l d0,a2
                movea.l wd_RPort(a2),a2
                move.l  a2,RastPort1

                lea     TextAttrStruct(pc),a0   open ROM resident font
                movea.l grbase(pc),a6
                jsr     _LVOOpenFont(a6)
                move.l  d0,TextFont1
                beq.s   4$

                movea.l d0,a0
                movea.l a2,a1                   rastport
                jsr     _LVOSetFont(a6)

4$              movea.l a2,a1
                move.b  Pen0(pc),d0
                jsr     _LVOSetAPen(a6)
                
                lea     Message1(pc),a0         ptr to text
                moveq   #82,d0                  xpos
                moveq   #4,d1                   ypos
                move.b  Pen3(pc),d2             colour1
                move.b  Pen1(pc),d3             colour2
                bsr     OPrint                  display outlined text
                
                lea     Message2(pc),a0
                moveq   #82,d0
                moveq   #16,d1
                move.b  Pen3(pc),d2
                move.b  Pen1(pc),d3
                bsr     OPrint
                
                lea     Message3(pc),a0
                moveq   #7,d0
                moveq   #33,d1
                move.b  Pen1(pc),d2
                bsr     Print
                
                lea     Message4(pc),a0
                moveq   #7,d0
                moveq   #43,d1
                bsr     Print
                
                lea     Message5(pc),a0
                moveq   #7,d0
                moveq   #53,d1
                bsr     Print
                st.b    d0              signal no error

BadOpen         rts

RefreshWindow   bsr     ClearWindow
                bsr     DrawFilename
                bsr     PrintFormat
                bsr     PrintCAMGMode
                rts

ClearWindow     movea.l RastPort1(pc),a2
                movea.l grbase(pc),a6

                movea.l a2,a1
                clr.l   d0              use background pen
                jsr     _LVOSetAPen(a6)
                
                movea.l a2,a1
                moveq   #87,d0          x1
                moveq   #33+9,d1        y1
                move.l  #354-4,d2       x2
                moveq   #63+8,d3        y2
                jsr     _LVORectFill(a6)
                rts

DrawFilename    moveq   #87,d0
                moveq   #33,d1
                moveq   #1,d2
                lea     filename_buf(pc),a0
                bsr     Print
                rts
                
*****************************************************************
*                                                               *
*       Print - Prints a line of text into the main window      *
*                                                               *
* INPUTS: a0 = Pointer to null terminated text                  *
*         d0 = Xpos of text                                     *
*         d1 = Ypos of text                                     *
*         d2 = Foreground pen colour                            *
* OUTPUT: d0 = New Xpos of text                                 *
*         Other regisers unchanged                              *
*                                                               *
*****************************************************************

Print           move.l  d4,-(a7)
                movem.l d0-d1/a0/a6,-(a7)
                clr.l   d0
1$              tst.b   0(a0,d0.w)      count length of string
                beq.s   2$
                addq.w  #1,d0
                bra.s   1$

2$              movea.l grbase(pc),a6
                move.l  RastPort1(pc),a1
                jsr     _LVOTextLength(a6)
                move.l  d0,d4
                
                movem.l (a7),d0-d1/a0/a6
                movea.l intuitionbase(pc),a6
                move.b  d2,FrontPen
                move.l  a0,IText

                move.l  RastPort1(pc),a0
                lea     IntuiTextStruct(pc),a1
                jsr     _LVOPrintIText(a6)
                movem.l (a7)+,d0-d1/a0/a6
                add.l   d4,d0
                move.l  (a7)+,d4
                rts
                
*****************************************************************
*                                                               *
*       OPrint - Prints text with an outline                    *
*                                                               *
* INPUTS: a0 = Pointer to null terminated text                  *
*         d0 = Xpos of text (including outline)                 *
*         d1 = Ypos of text (including outline)                 *
*         d2 = Text pen colour                                  *
*         d3 = Outline pen colour                               *
*                                                               *
*****************************************************************

OPrint          exg     d3,d2           swap pen colours
                moveq   #2,d6           Ypos counter            

OPrintloopY     moveq   #2,d7           Xpos counter
OPrintloopX     move.l  d0,-(a7)
                bsr.s   Print
                move.l  (a7)+,d0
                addq    #1,d0
                dbf     d7,OPrintloopX
                
                subq    #3,d0
                addq    #1,d1
                dbf     d6,OPrintloopY
                
                addq    #1,d0
                subq    #2,d1
                exg     d3,d2           swap pen colours
                move.l  d0,-(a7)
                bsr.s   Print
                move.l  (a7)+,d0
                rts

*****************************************************************
*                                                               *
*       IPrint - Prints integer in the range 0 - 65535          *
*                                                               *
* INPUTS: d0 = Xpos to be printed                               *
*         d1 = Ypos to be printed                               *
*         d2 = Text pen colour                                  *
*         d3 = Integer word to be printed                       *
*                                                               *
*****************************************************************

IPrint          moveq   #7,d4           digit counter
                link    a5,#-8          allocate space on stack
                move.b  #0,8(a7)        insert a null onto stack
IPrintloop      divu    #10,d3
                swap    d3              get remainder
                add.b   #'0',d3         convert to ASCII
                move.b  d3,0(a7,d4)     move digit onto stack
                clr.w   d3              remove remainder
                swap    d3              point to quotient
                subq    #1,d4           decrement buffer position
                tst.w   d3              any digits left to print
                bne.s   IPrintloop

DropLeadingZero cmp.b   #'0',0(a7,d4)
                bne     FinishDrop
                addq    #1,d4           increment buffer position
                bra.s   DropLeadingZero

FinishDrop      lea     1(a7,d4),a0
                bsr     Print

;               subq.b  #7,d4
;               neg.b   d4

;               mulu    #8,d4
                unlk    a5              deallocate space on stack

                rts

*****************************************************************
*                                                               *
*       PrintCAMGMode - Prints CamgMode                         *
*                                                               *
* INPUTS: None                                                  *
*                                                               *
*****************************************************************

PrintCAMGMode   moveq   #1,d2           pen colour
                moveq   #87,d0          set x pos
                moveq   #53,d1          set y pos

                move.w  ns_ViewModes1(pc),d5
                btst    #VB_SUPERHIRES,d5       test for SUPERHIRES
                beq.s   noSUPERHIRES
                lea     SUPERHIRES_msg(pc),a0
                bra.s   continue1

noSUPERHIRES    btst    #VB_HIRES,d5    test for HIRES
                beq.s   noHIRES
                lea     HIRES_msg(pc),a0
                bra.s   continue1

noHIRES         lea     LORES_msg(pc),a0
continue1       bsr     Print
                addq.w  #8,d0

                btst    #VB_HAM,d5      test for HAM
                beq.s   noHAM
                lea     HAM_msg(pc),a0
                cmpi.w  #8,ns_Depth1    test for HAM8
                bne.s   continue2
                lea     HAM8_msg(pc),a0
                bra.s   continue2

noHAM           btst    #VB_EXTRA_HALFBRITE,d5  test for EHB
                beq.s   no_special_mode
                lea     HALFBRITE_msg(pc),a0
continue2       bsr     Print
                addq.w  #8,d0

no_special_mode btst    #VB_LACE,d5
                beq.s   noLACE
                lea     LACE_msg(pc),a0
                bsr     Print

noLACE          rts

*****************************************************************
*                                                               *
*       PrintFormat - Displays width x height x no. colours     *
*                                                               *
* INPUTS: None                                                  *
*                                                               *
*****************************************************************

PrintFormat     moveq   #87,d0          x pos
                moveq   #43,d1          y pos
                moveq   #1,d2           pen colour
                clr.l   d3
                move.w  iWidth(pc),d3   image width
                bsr     IPrint          print image width

                lea     _x_(pc),a0
                bsr     Print           print ' x '
                
                move.w  iHeight(pc),d3  image height
                bsr     IPrint          print image height
                
                lea     _x_(pc),a0
                bsr     Print           print ' x '
                
                clr.l   d3
                move.w  ns_Depth1(pc),d4
                bset    d4,d3

;               
; Adjust according to ns_ViewModes              
;               

                btst    #VB_HAM,ns_ViewModes1   test for HAM
                beq.s   2$
                cmpi.w  #8,ns_Depth1            test for HAM8
                bne.s   1$
                lea     HAM8_cols(pc),a0
                bsr     Print
                bra.s   3$

1$              asl.w   #6,d3

2$              bsr     IPrint
                
3$              lea     Colours(pc),a0
                bsr     Print           print ' COLOURS'

                rts

*****************************************************************
*                                                               *
* CheckForArg - Tests for and interprets command line arguments *
*                                                               *
* INPUTS: a0 = Ptr to argument.                                 *
* OUTPUT: d0 = 0 string was a filename.                         *
*              1 if argument was performed.                     *
*                                                               *
*****************************************************************

CheckForArg     cmpi.b  #'-',(a0)+      commandline switch?
                bne.s   NotArg
CheckArgLoop    move.b  (a0)+,d0
                beq.s   EndOfArgs
                move.b  d0,Bad_Arg_Pos
                cmpi.b  #97,d0          check for lowercase char
                blt.s   2$
                subi.b  #32,d0          convert to uppercase
2$              clr.w   d1
1$              cmp.b   ValidArgs(pc,d1.w),d0
                beq.s   GoodArg
                addq.w  #1,d1
                cmpi.w  #MAX_ARGS,d1
                bne.s   1$
                move.l  a0,-(a7)
                movea.l dosbase(pc),a6
                jsr     _LVOOutput(a6)  find stdout
                move.l  d0,d1           handle
                beq.s   badarg_contin
                move.l  #BadArg_msg,d2  buffer
                moveq.l #BadArg_len,d3  length
                jsr     _LVOWrite(a6)   output string
badarg_contin   movea.l (a7)+,a0
                bra.s   CheckArgLoop

GoodArg         move.w  d1,d2
                asl.w   #2,d2           d2 * 4
                movea.l ArgCode(pc,d2.w),a1
                jsr     (a1)
                bra.s   CheckArgLoop
EndOfArgs       moveq.l #1,d0
                rts
NotArg          clr.l   d0
                rts

ValidArgs       dc.b    '*CDFQPSV'
MAX_ARGS        equ     *-ValidArgs
                even
ArgCode         dc.l    RequestFile,ToggleCentering
                dc.l    SetDLMode
                dc.l    ToggleFade,ToggleQuiet
                dc.l    TogglePAL,ToggleScroll
                dc.l    TVertCenterType

*****************************************************************
*                                                               *
* CheckToolTypes - Checks for & interprets workbench tooltypes  *
*                                                               *
* INPUTS: a0 = Pointer to tooltypes structure                   *
*                                                               *
*****************************************************************

CheckToolTypes  lea     ToolArgs(pc),a2

CheckTool       move.l  a0,RegSave_a0
                move.l  (a2),a1         ptr to tool name
                movea.l iconbase(pc),a6
                jsr     _LVOFindToolType(a6)
                tst.l   d0
                beq.s   ToolNotFound
                movea.l d0,a3
                move.w  4(a2),d2        bit number
                bpl.s   2$

                move.l  6(a2),a1        call On_Subroutine
                jsr     (a1)
                bra.s   ToolEnd

2$              movea.l a3,a0           tool value
                movea.l 6(a2),a1        On_Text
                movea.l iconbase(pc),a6
                jsr     _LVOMatchToolValue(a6)
                tst.l   d0
                beq.s   1$
                bset.b  d2,PreferenceModes
                bra.s   ToolEnd
1$              movea.l a3,a0           tool value
                movea.l 10(a2),a1       Off_Text
                movea.l iconbase(pc),a6
                jsr     _LVOMatchToolValue(a6)
                tst.l   d0
                beq.s   ToolNotFound
                bclr.b  d2,PreferenceModes
ToolNotFound    tst.w   4(a2)           bit no = -1?
                bpl.s   ToolEnd

                move.l  10(a2),a1       call Off_Subroutine
                jsr     (a1)

ToolEnd         move.l  RegSave_a0(pc),a0
                lea     14(a2),a2       go to next tool

                tst.l   (a2)
                bne.s   CheckTool
                rts

SetAutoRequest  tst.l   NumArgs         only request if no files selected
                bne.s   NoAutoRequest
                movem.l (a7)+,d0-d1     pop RTS1 & RTS2 off stack
                move.l  #0,-(a7)        push CLI dummy lock onto stack
                move.l  #AutoRequest,-(a7)      push -* command onto stack
                addi.l  #1,NumArgs      increment number of args
                movem.l d0-d1,-(a7)     push RTS1 & RTS2 onto stack
NoAutoRequest   rts

SetDL_Mode      bset.b  #DL_Flag,PreferenceModes
NoDL_Mode       rts

SetAuto_PAL     bset.b  #PAL_Mode,PreferenceModes
NoAuto_PAL      rts

RegSave_a0      dc.l    0

*****************************************************************
*                                                               *
*       !!! IMPORTANT NOTE FOR REQUESTFILE SUBROUTINE !!!       *
*                                                               *
*       Due to requestfile's stack manipulation, the            *
*       number of stack pops may need changing if the           *
*       program's calling structure is altered.                 *
*                                                               *
*       MY ASSUMPTION:                                          *
*                                                               *
*       Request file is called by:                              *
*               Main ---> CheckForArg ---> RequestFile          *
*                                                               *
*       Thus two return addresses must be popped in order       *
*       for parameters to be placed onto the stack.             *
*                                                               *
*****************************************************************

RequestFile     movea.l a0,a4                   save arg ptr
                movea.l AslBase(pc),a6          a6 = aslbase
                cmpa.w  #0,a6
                beq.s   RequestFile2
                movea.l ReqPtr(pc),a0           a0 = fileReq
                cmpa.w  #0,a0
                beq.s   ExitAslReq
                lea     ASLRequestTags(pc),a1
                jsr     _LVOAslRequest(a6)
                tst.l   d0
                beq.s   ExitAslReq              no files selected
                movem.l (a7)+,d0-d1             pop RTS1 & RTS2 off stack

                ;*** add more pops here if program structure changes ***

                movea.l ReqPtr(pc),a0           point to requester structure
                move.l  rf_NumArgs(a0),d2
                beq.s   ExitAslReq
                add.l   d2,NumArgs
                movea.l rf_ArgList(a0),a0

PushFileArgs    move.l  (a0)+,-(a7)             push lock onto stack
                move.l  (a0)+,-(a7)             push fname on stack

                subq.l  #1,d2
                bne.s   PushFileArgs

                movem.l d0-d1,-(a7)             push back RTS1 & RTS2

ExitAslReq      movea.l a4,a0                   restore arg ptr
                rts

RequestFile2    movea.l ReqToolsBase(pc),a6     a6 = aslbase
                cmpa.w  #0,a6
                beq.s   ExitReqToolsReq
                movea.l ReqPtr(pc),a1           a1 = fileReq
                cmpa.w  #0,a1
                beq.s   ExitReqToolsReq
                movea.l buffer(pc),a2           Filename buffer
                lea     ReqTitle(pc),a3
                lea     ReqToolsTags(pc),a0     taglist
                jsr     RtFileRequestA(a6)
                tst.l   d0
                beq.s   ExitReqToolsReq         no files selected
                move.l  d0,-(a7)

                move.l  ReqPtr(pc),a0           ptr to requester
                move.l  rtfr_Dir(a0),d1         ptr to dir
                moveq.l #ACCESS_READ,d2
                movea.l dosbase(pc),a6
                jsr     _LVOLock(a6)            lock the directory
                move.l  d0,d2
                move.l  d0,DirLock
                movea.l ReqToolsBase(pc),a6

                movea.l (a7)+,a0                a0 = ptr to filelist
                
                movem.l (a7)+,d0-d1             pop RTS1 & RTS2 off stack

                ;*** add more pops here if program structure changes ***

PushFileList    move.l  d2,-(a7)                push dir lock onto stack
                move.l  8(a0),-(a7)             push fname address onto stack
                addq.l  #1,NumArgs
                movea.l (a0),a0                 next field
                cmpa.w  #0,a0                   end of filelist?
                bne.s   PushFileList

                movem.l d0-d1,-(a7)             push back RTS1 & RTS2

ExitReqToolsReq movea.l a4,a0                   restore arg ptr
                rts

ToggleCentering bchg.b  #Centering,PreferenceModes
                rts
ToggleFade      bchg.b  #Fading,PreferenceModes
                rts
SetDLMode       bset.b  #DL_Flag,PreferenceModes
                rts

ToggleQuiet     rts

TogglePAL       bchg.b  #PAL_Mode,PreferenceModes
                rts
ToggleScroll    bchg.b  #Scroll_Mode,PreferenceModes
                rts
TVertCenterType bchg.b  #VertCentType,PreferenceModes
                rts

*****************************************************************
*                                                               *
*       DisplayError - Puts error message in title bar          *
*                                                               *
* INPUTS: d0 = Error number                                     *
*                                                               *
*****************************************************************

DisplayError    movem.l d0/a6,-(a7)

                cmpi.b  #HIDDEN_LEVEL,d0
                bge     1$

                asl.w   #2,d0           d0 x 4
                lea     Error_Table(pc),a1
                movea.l 0(a1,d0.w),a1   ptr to new window title
                movea.w #-1,a2          no new screen title
                movea.l windowptr(pc),a0
                movea.l intuitionbase(pc),a6
                jsr     _LVOSetWindowTitles(a6)

                cmpi.b  #FATAL_LEVEL,3(a7)      check for fatal error
                blt.s   1$              delay only for fatal errors

                btst    #1,FileError    fatal error already displayed?
                bne.s   1$

                btst.b  #DL_Mode,Run_Mode
                bne.s   2$              don't delay if in DL mode

                move.l  #15*16,d1       no. of 16ths of a second
                move.l  dosbase(pc),a6
                jsr     _LVODelay(a6)   delay for 5 seconds

2$              bset    #1,FileError
1$              movem.l (a7)+,d0/a6
                rts

*****************************************************************
*                                                               *
*        ReadFile - Reads in IFF/GIF format files               *
*                                                               *
* Errors: END_OF_FILE, READ_ERROR                               *
*                                                               *
*****************************************************************

ReadFile        bclr.b  #IFF,Run_Mode
                bclr.b  #GIF,Run_Mode

                clr.b   foundChunks
                clr.w   ns_ViewModes1
                clr.l   bufferptr
                clr.l   buffersize
                clr.b   FileError

                moveq   #4,d3
                bsr     readit
                bmi     chunk_read_err
                cmpi.l  #'FORM',(a0)            IFF format file?
                bne.s   Checkformat2
                bset.b  #IFF,Run_Mode
                bsr     ReadIFF                 read IFF file
                rts

Checkformat2    move.l  (a0),d0
                move.b  d0,Gifversion           store 1 char of version
                move.b  d0,Gifversion2
                andi.l  #$ffffff00,d0           mask out format byte
                cmpi.l  #('G'<<24|'I'<<16|'F'<<8),d0    GIF format?
                bne.s   Checkformat3
                bset.b  #GIF,Run_Mode
                bsr     ReadGIF                 read GIF file
                rts

Checkformat3    move.w  #UNKNOWN_TYPE,d0        unknown file format
                rts

*****************************************************************
*                                                               *
* ReadIFF - Reads IFF 85 format file                            *
*                                                               *
* OUTPUTS: d0.w >= 0 if no error occurred.                      *
*               <  0 if an error occurred.                      *
*                                                               *
*****************************************************************

ReadIFF         moveq   #8,d3                   read ILBMxxxx
                bsr     readit
                bmi     chunk_read_err
                cmpi.l  #'ILBM',4(a0)           check if ILBM type
                beq     GetChunks

                move.w  #IFF_NOT_ILBM,d0
                rts

GetChunks       move.w  #READING_IFF,d0
                btst.b  #DL_Mode,Run_Mode
                beq.s   5$
                move.w  #SCANNING_IFF,d0
5$              bsr     DisplayError    reading iff ilbm 85...

ChunkLoop       moveq   #8,d3
                bsr     readit
                ;beq.s  end_of_chunks
                bmi.s   chunk_read_err
                move.l  4(a0),d3        get chunk length
                move.l  (a0),d0         get chunk name
                cmpi.l  #'BMHD',d0      check for bitmap header chunk
                bne     1$
                bsr     ReadBMHD
                beq.s   ChunkLoop
                rts
1$              cmpi.l  #'CMAP',d0
                bne     2$
                bsr     ReadCMAP
                beq.s   ChunkLoop
                rts
2$              cmpi.l  #'CAMG',d0
                bne     3$
                bsr     ReadCAMG
                beq.s   ChunkLoop
                rts
3$              cmpi.l  #'BODY',d0
                bne     4$
                bsr     ReadBODY
                rts
4$              bsr     ReadUNKNOWN
                beq.s   ChunkLoop
chunk_read_err  rts

*****************************************************************
*                                                               *
* ReadBMHD -  Reads IFF BitMap Header chunk.                    *
*                                                               *
* OUTPUTS: d0.w = 0 if no error occurred.                       *
*               < 0 if an error occurred.                       *
* ERRORS:  d0.b = ALLOC_ERROR if bitmaps could not be allocated.*
*                 READ_ERROR if disk read error occurred.       *
*                 END_OF_FILE if end of file was reached.       *
*                                                               *
*****************************************************************

ReadBMHD        bset.b  #0,foundChunks
                bsr     readit
                bmi     BMHDError
                move.w  (a0),iWidth
                move.w  2(a0),iHeight
                move.w  4(a0),ns_LeftEdge1
                move.w  6(a0),ns_TopEdge1
                clr.b   ns_Depth1
                move.b  8(a0),ns_Depth1+1
                move.b  10(a0),iCompr
                move.w  16(a0),ns_Width1
                move.w  18(a0),ns_Height1

Alloc_Raster    move.w  iWidth(pc),d0           d0 = iWidth
                cmp.w   ns_Width1(pc),d0        is ns_Width > iWidth?
                bcc     ns_WidthOK

                move.w  d0,ns_Width1            ns_Width = iWidth

ns_WidthOK      move.w  iHeight(pc),d0          d0 = iHeight
                cmp.w   ns_Height1(pc),d0       is ns_Height > iHeight
                bcc     ns_HeightOK
                move.w  d0,ns_Height1           ns_Height = iHeight

ns_HeightOK     lea     BitMap1(pc),a0
                move.w  ns_Depth1(pc),d0
                clr.w   d7
                move.b  d0,d7
                move.w  iWidth(pc),d1
                move.w  iHeight(pc),d2
                movea.l grbase(pc),a6
                jsr     _LVOInitBitMap(a6)
                lea     bm_Planes1(pc),a2
                subq.w  #1,d7                   d7 = #planes-1
AllocPlanes     move.w  iWidth(pc),d0
                move.w  iHeight(pc),d1
                jsr     _LVOAllocRaster(a6)
                move.l  d0,(a2)+
                beq.s   AllocPlaneError
                
                movea.l d0,a1                   memblock
                move.w  bm_Rows1(pc),d0
                swap    d0                      upper 16-bits = #rows
                move.w  bm_BytesPerRow1(pc),d0  lower 16-bits = bytes/row
                moveq   #%00000010,d1           bit 1 = 1 : BytesPerRow is on
*                                               bit 0 = 0 : Wait for blitter
                jsr     _LVOBltClear(a6)        clear the raster with blitter
                dbf     d7,AllocPlanes
                clr.w   d0
BMHDError       rts
AllocPlaneError move.w  #ALLOC_ERROR,d0
                rts

*****************************************************************
*                                                               *
* ReadCMAP - Reads IFF ColourMap chunk.                         *
*                                                               *
* OUTPUTS: d0.w = 0 if no error occurred.                       *
*               < 0 if an error occurred.                       *
*          d3   = Size of colourmap.                            *
* ERRORS:  d0.b = READ_ERROR if disk read error occurred.       *
*                 END_OF_FILE if end of file was reached.       *
*                 ALLOC_ERROR if colormap couldn't be allocated.*
*                                                               *
*****************************************************************

ReadCMAP        bset.b  #1,foundChunks

                move.l  d3,d0
                divu    #3,d0                   ctab/3 = no. colours
                andi.l  #$0000ffff,d0
                move.w  d0,NoColours
                add.l   d0,d0                   colurtab_size = ncols * 2

                btst.b  #WB_3.0,Run_Mode
                beq.s   oldcoltable
                move.l  d3,d0
                asl.l   #2,d0                   *4 = colourtab_size
                addi.l  #8,d0                   colourtable size

oldcoltable     move.l  d0,ColourTabSize
                moveq   #MEMF_PUBLIC,d1
                move.l  (execbase).w,a6
                jsr     _LVOAllocMem(a6)        allocate disk-read buffer
                move.l  d0,ColourTab
                beq     BadCMAPAlloc

                move.l  ColourTabSize(pc),d0
                move.l  #MEMF_PUBLIC|MEMF_CLEAR,d1
                jsr     _LVOAllocMem(a6)        allocate black colour table
                move.l  d0,BlankColourTab
                beq     BadCMAPAlloc

                bsr     readit
                bmi     CMAPError

;NB. a0 now -> read buffer containing cmap chunk

                movea.l ColourTab(pc),a1
                move.w  NoColours(pc),d0
                subq.w  #1,d0                   dbf loop count
                btst.b  #WB_3.0,Run_Mode        24-bit pallette?
                bne.s   CmapLoop32

CmapLoop        clr.w   d1
                move.b  (a0)+,d1                red
                lsl.w   #4,d1
                move.b  (a0)+,d1                green
                lsl.w   #4,d1
                move.b  (a0)+,d1                blue
                lsr.w   #4,d1
                move.w  d1,(a1)+
                dbf     d0,CmapLoop
                clr.w   d0
CMAPError       rts

CmapLoop32      move.w  NoColours(pc),(a1)+     table size
                clr.w   (a1)+                   first index = 0

1$              move.b  (a0)+,(a1)+             red
                clr.b   (a1)+
                clr.w   (a1)+                   output => $rr000000
                move.b  (a0)+,(a1)+             green
                clr.b   (a1)+
                clr.w   (a1)+                   output => $gg000000
                move.b  (a0)+,(a1)+             blue
                clr.b   (a1)+
                clr.w   (a1)+                   output => $bb000000
                dbf     d0,1$

                clr.l   (a1)+                   terminate table with a NULL
                movea.l BlankColourTab(pc),a0
                move.w  NoColours(pc),(a0)+     blank table size
                clr.w   d0
                rts

BadCMAPAlloc    move.w  #ALLOC_ERROR,d0
                rts

*****************************************************************
*                                                               *
* ReadCAMG - Reads IFF Amiga ViewMode chunk.                    *
*                                                               *
* OUTPUTS: d0.w = 0 if no error occurred.                       *
*               < 0 if an error occurred.                       *
* ERRORS:  d0.b = READ_ERROR if disk read error occurred        *
*                 END_OF_FILE if end of file was reached.       *
*                                                               *
*****************************************************************

ReadCAMG        bset.b  #2,foundChunks
                bsr     readit
                bmi     1$
                move.w  2(a0),d0
                andi.w  #%1000111111111111,d0   mask out bitplanes
                move.w  d0,ns_ViewModes1
                clr.w   d0
1$              rts

*****************************************************************
*                                                               *
* ReadBODY - Reads IFF BODY chunk.                              *
*                                                               *
* OUTPUTS: d0.w >= 0 if no error occurred.                      *
*               <  0 if an error occurred.                      *
* ERRORS:  d0.b = READ_ERROR if disk read error occurred.       *
*                 END_OF_FILE if end of file was reached.       *
*                                                               *
*****************************************************************

ReadBODY        bset.b  #3,foundChunks

                move.l  d3,-(a7)

;
; Test whether CAMG chunk was found yet. If not, calculate it.
;

CamgCheck       move.w  ns_ViewModes1(pc),d0
                btst.b  #2,foundChunks  check for Camg chunk
                bne     foundCamg
                cmpi.w  #640,ns_Width1  work out what it should be
                blt.s   Camgtest2
                bset    #VB_HIRES,d0    hires mode on
Camgtest2       cmpi.w  #350,ns_Height1
                blt.s   Camgtest3
                bset    #VB_LACE,d0     interlace mode on               
Camgtest3       move.w  d0,ns_ViewModes1

foundCamg       bsr     CreateDisplay
                move.l  (a7)+,d3
                tst.w   d0              check for error from createdisplay
                bmi.s   Body_Exit

                cmpi.b  #0,iCompr
                bne.s   CmpByteRun1

NoCompr         move.l  dosbase(pc),a6
                clr.l   d4
Gloop4.1        clr.l   d5
                lea     bm_Planes1(pc),a2
Gloop4.2        move.l  (a2)+,d2        d2 = plane(pp)
                clr.l   d1
                move.w  bm_BytesPerRow1(pc),d1
                move.l  d1,d3
                mulu    d4,d1           rr*iRowBytes
                add.l   d1,d2           plane(pp) + (rr * iRowBytes)

                bsr     readit2
                bmi     BODYError
                addq.b  #1,d5
                cmp.b   bm_Depth1(pc),d5
                bne.s   Gloop4.2
                addq.w  #1,d4
                cmp.w   bm_Rows1(pc),d4
                bne.s   Gloop4.1
                clr.w   d0
Body_Exit       rts
                
CmpByteRun1     clr.l   d4
Gloop4.3        clr.l   d5
                lea     bm_Planes1(pc),a2
Gloop4.4        move.l  (a2)+,d2        d2 = plane(pp)
                clr.l   d1
                move.w  bm_BytesPerRow1(pc),d1
                mulu    d4,d1           rr*iRowBytes
                add.l   d1,d2           plane(pp) + (rr * iRowBytes)
                move.l  d2,currentpos
                clr.l   d6              bCnt = 0                

WhileLoop       clr.l   d7
                bsr     ReadByte
                bmi.s   BODYError
                move.b  d0,d7
                bmi.s   Code128         inCode > 128
                move.l  d7,d3
                addq    #1,d7           inCode + 1
                
                move.l  currentpos,d2
                add.l   d6,d2           scrRow + bCnt
                move.l  d2,a3
ReadLoop        bsr     ReadByte
                bmi.s   BODYError
                move.b  d0,(a3)+
                dbf     d3,ReadLoop
                add.l   d7,d6           bCnt = bCnt + inCode + 1                
                bra.s   loopcheck

Code128         bsr     ReadByte        d0 = inByte
                bmi.s   BODYError
                move.l  #256,d1
                sub.w   d7,d1           256 - inCode
                move.l  currentpos,d2
                add.l   d6,d2           scrRow + bCnt
                move.l  d2,a1
Codeloop        move.b  d0,(a1)+
                addq.l  #1,d6           bCnt = bCnt + 1
                dbf     d1,Codeloop
loopcheck       cmp.w   bm_BytesPerRow1(pc),d6
                blt.s   WhileLoop
                addq.b  #1,d5
                cmp.b   bm_Depth1(pc),d5
                blt.s   Gloop4.4
                addq.w  #1,d4
                cmp.w   bm_Rows1,d4
                blt.s   Gloop4.3
                clr.w   d0
BODYError       rts
                
*****************************************************************
*                                                               *
* ReadUNKNOWN - Reads unknown chunk type.                       *
*                                                               *
* OUTPUTS: d0.w >= 0 if no error occurred.                      *
*               <  0 if an error occurred.                      *
* ERRORS:  d0.b = READ_ERROR if a disk read error occurred.     *
*                 END_OF_FILE if end of file was reached.       *
*                                                               *
*****************************************************************

ReadUNKNOWN     move.l  4(a0),d7        read unknown chunk
                move.l  d7,d6
                subq    #1,d7
GetCloop        moveq   #1,d3
                bsr     readit
                
                bmi     2$
                dbf     d7,GetCloop
                btst    #0,d6
                beq     1$
                moveq   #1,d3
                bsr     readit          if odd length, read 1 more byte
                ;bmi.s  2$
1$              ;clr.l  d0
2$              rts

*****************************************************************
*                                                               *
* ReadGIF - Reads GIF 87a and 89a format files                  *
*                                                               *
* OUTPUTS: d0.w >= 0 if no error occurred.                      *
*               <  0 if an error occurred.                      *
*                                                               *
*****************************************************************

ReadGIF         moveq   #2,d3
                bsr     readit          read final 2 chars of GIF format
                bmi.s   Giferror
                move.b  (a0),Gifversion+1       store remaining 2 chars
                move.b  (a0),Gifversion2+1      of the GIF version
                move.b  1(a0),Gifversion+2      number.
                move.b  1(a0),Gifversion2+2

                move.w  #READING_GIF,d0
                btst.b  #DL_Mode,Run_Mode
                beq.s   5$
                move.w  #SCANNING_GIF,d0
5$              bsr     DisplayError            reading gif xxy...

                bsr     ReadScreenDescriptor    also reads cmap if M = 1
                bmi.s   Giferror

1$              moveq   #1,d3           virtual read 1 byte
                bsr     readit
                bmi.s   Giferror
                cmpi.b  #',',(a0)       reached image descriptor yet?
                bne.s   1$
                bsr     ReadImageDescriptor     also reads cmap if M = 1
                bmi.s   Giferror
                bsr     ReadGIFBody
Giferror        rts

*****************************************************************
*                                                               *
* ReadScreenDescriptor - Reads in GIF screen descriptor chunk   *
*                                                               *
* OUTPUTS: d0 >= 0 if no error occurred                         *
*          d0 <  0 if an error occurred                         *
*                                                               *
*****************************************************************

ReadScreenDescriptor:

                moveq   #7,d3
                bsr     readit          read screen descriptor into buffer
                bmi.s   2$
                move.w  (a0)+,d0        get screen width
                rol.w   #8,d0           swap lo/hi bytes
                move.w  d0,ns_Width1
                move.w  (a0)+,d0        get screen height
                rol.w   #8,d0           swap lo/hi bytes
                move.w  d0,ns_Height1
                move.b  (a0),d0         get misc byte
                andi.w  #15,d0          get 'pixel' (high bit = 0)
                addq.b  #1,d0           bits_per_pixel = pixel + 1
                move.b  d0,bits_per_pixel
                move.w  d0,ns_Depth1    screen depth
                btst.b  #7,(a0)         test 'M' bit
                beq.s   2$
                bsr     ReadColourMap
2$              rts

*****************************************************************
*                                                               *
* ReadImageDescriptor - Reads in GIF image descriptor chunk     *
*                                                               *
* OUTPUTS: d0 >= 0 if no error occurred                         *
*          d0 <  0 if an error occurred                         *
*                                                               *
*****************************************************************

ReadImageDescriptor:

                moveq   #9,d3
                bsr     readit          read image descriptor into buffer
                bmi.s   3$
                move.w  (a0),d0         get image x position
                rol.w   #8,d0           swap hi/lo bytes
                move.w  d0,ns_LeftEdge1
                move.w  2(a0),d0        get image y position
                rol.w   #8,d0           swap lo/hi bytes
                move.w  d0,ns_TopEdge1
                move.w  4(a0),d0        get image width
                rol.w   #8,d0           swap lo/hi bytes
                move.w  d0,iWidth
                move.w  6(a0),d0        get image height
                rol.w   #8,d0           swap lo/hi bytes
                move.w  d0,iHeight
                bclr.b  #GIF_INTERLACED,GifMode
                move.b  8(a0),d0        get misc byte
                btst    #6,d0           check 'I' bit
                beq.s   1$              clear = sequential raster order
                bset.b  #GIF_INTERLACED,GifMode
1$              btst    #7,d0           check 'M' bit
                beq.s   3$              ignore 'pixel'/use global cmap
                andi.w  #15,d0          get 'pixel' (high bit = 0)
                addq.b  #1,d0           bits_per_pixel = pixel + 1
                move.b  d0,bits_per_pixel
                move.w  d0,ns_Depth1    set screen depth
                bsr     ReadColourMap
3$              rts

*****************************************************************
*                                                               *
* ReadColourMap - Reads in GIF colourmap chunk                  *
*                                                               *
* OUTPUTS: d0 >= 0 if no error occurred                         *
*          d0 <  0 if an error occurred                         *
*                                                               *
*****************************************************************

ReadColourMap   ;First check for an existing colourmap here...

                move.b  bits_per_pixel(pc),d0
                clr.l   d7
                bset    d0,d7           d7 = # colours
                move.w  d7,NoColours
                move.w  d7,d3
                mulu.w  #3,d3           3 bytes per colour

                move.l  d7,d0
                add.l   d0,d0           ctablesize = 2*NoColours

                btst.b  #WB_3.0,Run_Mode
                beq.s   1$
                move.l  d3,d0
                add.l   d0,d0
                add.l   d0,d0           *4 = colourtab_size
                addi.l  #8,d0           colourtable size

1$              move.l  d0,ColourTabSize
                moveq   #MEMF_PUBLIC,d1
                move.l  (execbase).w,a6
                jsr     _LVOAllocMem(a6)        allocate disk-read buffer
                move.l  d0,ColourTab
                beq     BadCTabAlloc

                move.l  ColourTabSize(pc),d0
                move.l  #MEMF_PUBLIC|MEMF_CLEAR,d1
                jsr     _LVOAllocMem(a6)        allocate black colour table
                move.l  d0,BlankColourTab
                beq     BadCTabAlloc

                bsr     readit
                bmi.s   BadReadColour

;NB. a0 now -> read buffer containing cmap chunk

                movea.l ColourTab(pc),a1
                lea     ColourIndexTab(pc),a2
                move.w  NoColours(pc),d0
                subq.w  #1,d0                   dbf loop count
                btst.b  #WB_3.0,Run_Mode        24-bit pallette?
                bne.s   CTabLoop32

CTabLoop        clr.w   d1
                clr.l   d2
                clr.l   d3
                move.b  (a0)+,d1                red
                move.b  d1,d3
                lsl.w   #4,d1
                move.b  (a0)+,d1                green
                move.b  d1,d2
                add.w   d2,d3
                lsl.w   #4,d1
                move.b  (a0)+,d1                blue
                move.b  d1,d2
                add.w   d2,d3
                lsr.w   #4,d1
                move.w  d1,(a1)+
                divu.w  #48,d3
                move.b  d3,(a2)+                grey index value
                dbf     d0,CTabLoop
                clr.w   d0
BadReadColour   rts

CTabLoop32      move.w  NoColours(pc),(a1)+     table size
                clr.w   (a1)+                   first index = 0

1$              clr.l   d1
                clr.l   d2
                move.b  (a0)+,d1
                move.b  d1,(a1)+                red
                move.b  d1,d2
                clr.b   (a1)+
                clr.w   (a1)+                   output => $rr000000
                move.b  (a0)+,d1
                move.b  d1,(a1)+                green
                add.w   d1,d2
                clr.b   (a1)+
                clr.w   (a1)+                   output => $gg000000
                move.b  (a0)+,d1
                move.b  d1,(a1)+                blue
                add.w   d1,d2
                clr.b   (a1)+
                clr.w   (a1)+                   output => $bb000000
                divu.w  #48,d2
                move.b  d2,(a2)+                grey index value
                dbf     d0,1$

                clr.l   (a1)+                   terminate table with a NULL
                movea.l BlankColourTab(pc),a0
                move.w  NoColours(pc),(a0)+     blank table size
                clr.w   d0
                rts

BadCTabAlloc    move.w  #ALLOC_ERROR,d0
                rts

*****************************************************************
*                                                               *
* SetGreyMap - Sets up a 16-colour greyscale colourtable        *
*                                                               *
*                                                               *
*****************************************************************

SetGreyMap      bset.b  #GIF_GREYSCALE,GifMode
                move.w  #16,NoColours
                clr.l   d0
                move.w  #15,d1          NoColours-1
                movea.l ColourTab(pc),a1
                btst.b  #WB_3.0,Run_Mode
                beq.s   SetGreyMap4

                move.l  #$100000,(a1)+  set count+startindex
SetGreyMap32    move.l  d0,(a1)+        red
                move.l  d0,(a1)+        green
                move.l  d0,(a1)+        blue
                addi.l  #$10000000,d0   make next grey shade
                dbf     d1,SetGreyMap32
                clr.l   (a1)            add final NULL
                movea.l BlankColourTab(pc),a1
                move.l  #$100000,(a1)   set blank cmap size
                rts

SetGreyMap4     move.w  d0,(a1)+        store colour
                addi.w  #$0111,d0       make next grey shade
                dbf     d1,SetGreyMap4
                rts

*****************************************************************
*                                                               *
* ReadGIFBody - Reads in GIF raster image data                  *
*                                                               *
* OUTPUTS: d0 >= 0 if no error occurred                         *
*          d0 <  0 if an error occurred                         *
*                                                               *
*****************************************************************

ReadGIFBody     clr.w   d0
                cmpi.w  #640,ns_Width1  work out viewmode
                blt.s   1$
                bset    #VB_HIRES,d0    HIRES mode on
                ;bset   #2,d0           set ILACE to keep aspect ratio
1$              cmpi.w  #350,ns_Height1
                blt.s   2$
                bset    #VB_LACE,d0     ILACE mode on
                ;bset   #15,d0          set HIRES to keep aspect ratio
2$              move.w  d0,ns_ViewModes1
                bsr     Alloc_Raster
                bmi     ExpandError
                bsr     CreateDisplay
                bmi     ExpandError
                bset.b  #0,foundChunks

* LZW expander routine - expands the raster data stream that has been
* compressed with the LZW data compression method.

LARGEST_CODE    equ     4095
PREFIX_OFFSET   equ     0
SUFFIX_OFFSET   equ     (LARGEST_CODE+1)*2
STACK_OFFSET    equ     (LARGEST_CODE+1)*3
TABLE_SIZE      equ     STACK_OFFSET+(STACK_OFFSET-SUFFIX_OFFSET)
_sp             equr    d2
_shift          equr    d7

ExpandData      move.w  iWidth(pc),X_Pos
                clr.w   Y_Pos

                lea     RowAdd(pc),a0   setup interlace planeptr inc's
                lea     RowInit(pc),a1  setup interlace planeptr inits
                clr.l   d2
                move.w  bm_BytesPerRow1(pc),d2
                move.l  d2,d0

                move.l  d0,(a0)+        pass 1 rowadd
                move.l  d0,(a1)+        pass 1 init
                add.w   d0,d0           x 2
                move.l  d0,(a1)+        pass 2 init
                add.w   d2,d0           x 3
                move.l  d0,(a0)+        pass 2 rowadd
                move.l  d0,d1
                add.w   d2,d1           x 4
                move.l  d1,(a1)+        pass 3 init
                add.w   d0,d0           x 6
                add.w   d2,d0           x 7
                move.l  d0,(a0)+        pass 3 rowadd
                move.l  d0,(a0)+        pass 4 rowadd

                move.w  #12,Pass                reset interlace mode pass

                lea     bm_Planes1(pc),a0
                lea     Planeptrs(pc),a1
                clr.w   d0
                move.b  bm_Depth1(pc),d0
                subq    #1,d0
1$              move.l  (a0)+,(a1)+
                dbf     d0,1$

                move.l  #TABLE_SIZE,d0
                moveq.l #MEMF_PUBLIC,d1
                movea.l (execbase).w,a6
                jsr     _LVOAllocMem(a6)
                move.l  d0,code_table
                bne.s   AllocTable_OK
                move.w  #ALLOC_TABLE_ERR,d0
                rts

AllocTable_OK   bsr     ReadByte        get min_code_size
                bmi     ExpandError
                move.w  d0,min_code_size
                cmpi.b  #2,d0           min_code_size < 2?
                blt.s   1$              yep...
                cmpi.b  #9,d0           min_code_size > 9?
                ble.s   MinCodeSizeOK
1$              move.w  #BAD_MIN_CODE_SZ,d0
                bra     ExpandError

MinCodeSizeOK   bsr     init_table

                move.w  #16,_shift              intial shift count (assuming
                movea.l code_table(pc),a0       that iWidth >= 16)
                lea     SUFFIX_OFFSET(a0),a1
                lea     STACK_OFFSET(a0),a2
                lea     Planeptrs(pc),a3

                lea     ShiftItTab(pc),a5
                clr.w   d0              clear d0 word
                move.b  bm_Depth1(pc),d0
                subq.w  #1,d0           d0 = 0 - 7 bitplanes
                add.w   d0,d0           d0 = d0 * 2
                add.w   d0,d0           d0 = d0 * 4

* get address of relevant ShiftIt routine:

                movea.l 0(a5,d0.w),a4

* get address of relevant PutScrWord routine:

                movea.l PutScrWordTab-ShiftItTab(a5,d0.w),a5

                moveq.w #0,_sp
                move.w  #4*8,bit_offset         force 'read_code' to start
                clr.b   bytes_unread            a new record
Main_Loop       bsr     read_code
                bmi     ExpandError
                cmp.w   eof_code(pc),d0         code = eof_code?
                bne.s   1$
                clr.w   d0
                bra     ExpandError             finish decompression
1$              cmp.w   clear_code(pc),d0       code = clear_code?
                bne.s   _else
                move.w  min_code_size(pc),d0
                bsr     init_table              reset string table
                bsr     read_code
                bmi     ExpandError
                move.w  d0,old_code             old_code = code
                move.w  d0,suffix_char          suffix_char = code
                move.w  d0,final_char           final_char = code
                bsr     put_byte
                bmi.s   ExpandError             screen fully loaded
                bra.s   Main_Loop

_else           move.w  d0,input_code           input_code = code
                cmp.w   free_code(pc),d0        code >= free_code?
                blt.s   while_lp
                move.w  old_code(pc),d0         code = old_code
                move.b  final_char+1(pc),0(a2,_sp.w)
                addq.w  #1,_sp

while_lp        cmp.w   first_free(pc),d0       code >= first_free?
                blt.s   1$
                move.b  0(a1,d0.w),0(a2,_sp.w)
                addq.w  #1,_sp
                add.w   d0,d0           d0 * 2 = prefix index
                move.w  0(a0,d0.w),d0
                bra.s   while_lp

1$              move.w  d0,final_char           final_char = code
                move.w  d0,suffix_char          suffix_char = code
                move.b  d0,0(a2,_sp.w)
                addq.w  #1,_sp

while_lp2       tst.w   _sp             sp = 0?
                beq.s   end_while2
                subq.w  #1,_sp          --sp
                move.b  0(a2,_sp.w),d0
                bsr     put_byte
                beq.s   while_lp2

ExpandError     move.w  d0,-(a7)        push return code on stack
                movea.l code_table(pc),a1
                move.l  #TABLE_SIZE,d0
                movea.l (execbase).w,a6
                jsr     _LVOFreeMem(a6)
                move.w  (a7)+,d0        pop return code off stack
                rts

end_while2      move.w  free_code(pc),d1
                move.b  suffix_char+1(pc),0(a1,d1.w)
                add.w   d1,d1           generate prefix index
                move.w  old_code(pc),0(a0,d1.w)
                addq.w  #1,free_code
                move.w  input_code(pc),old_code
                move.w  free_code(pc),d1
                cmp.w   max_code(pc),d1         free_code > max_code?
                blt.s   1$
                cmpi.w  #12,code_size
                bge.s   1$
                addq.w  #1,code_size
                lsl.w   max_code        max_code << 1
1$              bra     Main_Loop       back for more...

*****************************************************************
*                                                               *
* Init_table - Initializes LZW string decoding table            *
*                                                               *
* INPUT: d0 = min_code_size                                     *
*                                                               *
*****************************************************************

init_table      clr.w   d1
                bset    d0,d1           
                move.w  d1,clear_code   clear_code = 2^min_code_size
                addq.w  #1,d1
                move.w  d1,eof_code     eof_code = clear_code + 1
                addq.w  #1,d1
                move.w  d1,first_free   first_free = clear_code + 2
                move.w  d1,free_code    free_code = first_free
                addq.w  #1,d0
                move.w  d0,code_size    code_size = min_code_size + 1
                clr.w   d1
                bset    d0,d1
                move.w  d1,max_code     max_code = 2^code_size
                rts

*****************************************************************
*                                                               *
* read_code - Reads next unpacked byte from compressed file     *
*                                                               *
* OUTPUTS: d0 >= 0, no error occurred (d0.w = code)             *
*          d0 <  0, an error occurred (d0.w = error code)       *
*                                                               *
*****************************************************************

_byte_offset    equr    d2
_bits_left      equr    d3

read_code       movem.l d1-d7/a0-a1/a6,-(a7)
                move.l  input_buffer(pc),d1
                move.w  bit_offset(pc),_bits_left
                move.w  _bits_left,_byte_offset
                andi.b  #7,_bits_left
                lsr.w   #3,_byte_offset
                beq.s   4$
                subq.w  #1,_byte_offset
1$              tst.b   bytes_unread
                bne.s   2$

                movem.l d1-d3,-(a7)
                bsr     ReadByte
                movem.l (a7)+,d1-d3
                bmi.s   read_code_error
                move.b  d0,bytes_unread
                beq.s   EndOfData

2$              movem.l d1-d3,-(a7)
                bsr     ReadByte
                movem.l (a7)+,d1-d3
                bmi.s   read_code_error
                move.b  d0,d1
                ror.l   #8,d1
                subq.b  #1,bytes_unread
3$              dbf     _byte_offset,1$

                move.w  _bits_left,bit_offset
                moveq.w #0,_byte_offset

4$              move.l  d1,input_buffer
                move.l  d1,d0
                move.w  code_size(pc),d1
                add.w   d1,bit_offset
                tst.b   _bits_left
                beq.s   5$
                lsr.l   _bits_left,d0

5$              add.w   d1,d1
                and.w   Mask-2(pc,d1.w),d0
EndOfData
read_code_error movem.l (a7)+,d1-d7/a0-a1/a6
                rts

Mask            dc.w    $0001,$0003,$0007,$000f
                dc.w    $001f,$003f,$007f,$00ff
                dc.w    $01ff,$03ff,$07ff,$0fff

*****************************************************************
*                                                               *
* put_byte - Sets a pixel in a GIF bitmap                       *
*                                                               *
* INPUT : d0.b = Pixel colour value                             *
* OUTPUT: d0.w = 0 if no error occurred                         *
*              < 0 if end of screen was passed                  *
*                                                               *
*****************************************************************

put_byte        btst.b  #GIF_GREYSCALE,GifMode
                beq.s   NormalCol
                move.b  ColourIndexTab(pc,d0.w),d0      

NormalCol       jsr     (a4)            shift the data byte
                subq.w  #1,_shift       shift = shift - 1
                bne.s   not_word

                cmp.w   #16,X_Pos
                bge.s   not_eol
                moveq.w #15,_shift
                move.w  X_Pos(pc),d0
                sub.w   d0,_shift
                moveq.w #0,d0
1$              jsr     (a4)            shift end of line data
                dbf     _shift,1$

not_eol         movem.l a4-a5,-(a7)
                jsr     (a5)            output screen word
                movem.l (a7)+,a4-a5

                move.w  X_Pos(pc),d0
                sub.w   #16,d0          xpos = xpos - shift
                bmi     newline
                move.w  d0,X_Pos
                beq     newline         end of line reached
                cmpi.w  #16,d0          xpos >= 16?
                blt.s   next_word
                move.w  #16,_shift      shift = 16
not_word        moveq.w #0,d0
                rts

next_word       move.w  d0,_shift       shift = xpos
                moveq.w #0,d0
                rts

ColourIndexTab  dcb.b   256,0

newline         move.w  iWidth(pc),X_Pos

                move.w  #16,_shift
                move.w  Y_Pos(pc),d0
                btst.b  #GIF_INTERLACED,GifMode GIF is in interlaced format
                beq     not_interlaced

                move.w  Pass(pc),d3
                add.w   YPosAdd+2(pc,d3.w),d0
                cmp.w   iHeight(pc),d0
                blt.s   do_next_row

                subq.w  #4,Pass
                bmi     end_of_screen

                movem.l a4-a5,-(a7)
                lea     bm_Planes1(pc),a4       reset plane pointers
                lea     Planeptrs(pc),a5        for next pass
                clr.w   d4
                move.b  bm_Depth1(pc),d4
                subq.w  #1,d4
                move.l  RowInit-4(pc,d3.w),d5
                move.w  YPosInit-2(pc,d3.w),Y_Pos
2$              move.l  (a4)+,(a5)
                add.l   d5,(a5)+
                dbf     d4,2$
                movem.l (a7)+,a4-a5
                moveq.w #0,d0
                rts

YPosInit        dc.l    1,2,4,0
YPosAdd         dc.l    2,4,8,8         used for interlaced raster format

do_next_row     move.w  d0,Y_Pos
                move.l  RowAdd(pc,d3.w),d0
                add.l   d0,(a3)         plane0ptr
                add.l   d0,4(a3)        plane1ptr
                add.l   d0,8(a3)        plane2ptr
                add.l   d0,12(a3)       plane3ptr
                add.l   d0,16(a3)       plane4ptr
                add.l   d0,20(a3)       plane5ptr
                add.l   d0,24(a3)       plane6ptr
                add.l   d0,28(a3)       plane7ptr
                moveq.w #0,d0
                rts

RowAdd          dc.l    0,0,0,0
RowInit         dc.l    0,0,0,0

not_interlaced  addq.w  #1,d0           ypos = ypos + 1
                cmp.w   iHeight(pc),d0
                blt.s   end_plot
end_of_screen   move.w  #END_OF_FILE,d0
                rts

end_plot        move.w  d0,Y_Pos
                moveq.w #0,d0
                rts

ShiftItTab      dc.l    ShiftIt_1,ShiftIt_2,ShiftIt_3,ShiftIt_4
                dc.l    ShiftIt_5,ShiftIt_6,ShiftIt_7,ShiftIt_8

PutScrWordTab   dc.l    PutScrWord_1,PutScrWord_2
                dc.l    PutScrWord_3,PutScrWord_4
                dc.l    PutScrWord_5,PutScrWord_6
                dc.l    PutScrWord_7,PutScrWord_8

* ShiftIt for 1 bitplane:

ShiftIt_1       lsr.b   #1,d0           shift data into plane bytes
                roxl.w  #1,d3
                rts

* ShiftIt for 2 bitplanes:

ShiftIt_2       lsr.b   #1,d0           shift data into plane bytes
                roxl.w  #1,d3
                lsr.b   #1,d0
                roxl.w  #1,d4
                rts

* ShiftIt for 3 bitplanes:

ShiftIt_3       lsr.b   #6,d0           shift data into plane bytes
                roxl.w  #1,d3
                lsr.b   #1,d0
                roxl.w  #1,d4
                lsr.b   #1,d0
                roxl.w  #1,d5
                rts

* ShiftIt for 4 bitplanes:

ShiftIt_4       lsr.b   #1,d0           shift data into plane bytes
                roxl.w  #1,d3
                lsr.b   #1,d0
                roxl.w  #1,d4
                lsr.b   #1,d0
                roxl.w  #1,d5
                lsr.b   #1,d0
                roxl.w  #1,d6
                rts

* ShiftIt for 5 bitplanes (32 COLOUR ONLY):

ShiftIt_5       lsr.b   #1,d0           shift data into plane bytes
                roxl.w  #1,d3
                swap    d3
                lsr.b   #1,d0
                roxl.w  #1,d3
                swap    d3
                lsr.b   #1,d0
                roxl.w  #1,d4
                swap    d4
                lsr.b   #1,d0
                roxl.w  #1,d4
                swap    d4
                lsr.b   #1,d0
                roxl.w  #1,d5
                rts

* ShiftIt for 6 bitplanes (AGA+ ONLY):

ShiftIt_6       lsr.b   #1,d0           shift data into plane bytes
                roxl.w  #1,d3
                swap    d3
                lsr.b   #1,d0
                roxl.w  #1,d3
                swap    d3
                lsr.b   #1,d0
                roxl.w  #1,d4
                swap    d4
                lsr.b   #1,d0
                roxl.w  #1,d4
                swap    d4
                lsr.b   #1,d0
                roxl.w  #1,d5
                swap    d5
                lsr.b   #1,d0
                roxl.w  #1,d5
                swap    d5
                rts

* ShiftIt for 7 bitplanes (AGA+ ONLY):

ShiftIt_7       lsr.b   #1,d0           shift data into plane bytes
                roxl.w  #1,d3
                swap    d3
                lsr.b   #1,d0
                roxl.w  #1,d3
                swap    d3
                lsr.b   #1,d0
                roxl.w  #1,d4
                swap    d4
                lsr.b   #1,d0
                roxl.w  #1,d4
                swap    d4
                lsr.b   #1,d0           ONLY DO THIS WITH 8-BITPLANE
                roxl.w  #1,d5
                swap    d5
                lsr.b   #1,d0           AGA VERSION!!!
                roxl.w  #1,d5
                swap    d5
                lsr.b   #1,d0
                roxl.w  #1,d6
                rts

* ShiftIt for 8 bitplanes (AGA+ ONLY):

ShiftIt_8       lsr.b   #1,d0           shift data into plane bytes
                roxl.w  #1,d3
                swap    d3
                lsr.b   #1,d0
                roxl.w  #1,d3
                swap    d3
                lsr.b   #1,d0
                roxl.w  #1,d4
                swap    d4
                lsr.b   #1,d0
                roxl.w  #1,d4
                swap    d4
                lsr.b   #1,d0
                roxl.w  #1,d5
                swap    d5
                lsr.b   #1,d0
                roxl.w  #1,d5
                swap    d5
                lsr.b   #1,d0
                roxl.w  #1,d6
                swap    d6
                lsr.b   #1,d0
                roxl.w  #1,d6
                swap    d6
                rts

* PutScrWord for 1 bitplane:

PutScrWord_1    move.l  (a3),a4
                move.w  d3,(a4)+        plane 0 word
                move.l  a4,(a3)
                rts

* PutScrWord for 2 bitplanes:

PutScrWord_2    movem.l (a3),a4-a5
                move.w  d3,(a4)+        plane 0 word
                move.w  d4,(a5)+        plane 1 word
                movem.l a4-a5,(a3)

                rts

* PutScrWord for 3 bitplanes:

PutScrWord_3    movem.l (a3),a4-a5
                move.w  d3,(a4)+        plane 0 word
                move.w  d4,(a5)+        plane 1 word
                movem.l a4-a5,(a3)

                move.l  8(a3),a4
                move.w  d5,(a4)+        plane 2 word
                move.l  a4,8(a3)

                rts

* PutScrWord for 4 bitplanes:

PutScrWord_4    movem.l (a3),a4-a5
                move.w  d3,(a4)+        plane 0 word
                move.w  d4,(a5)+        plane 1 word
                movem.l a4-a5,(a3)

                movem.l 8(a3),a4-a5
                move.w  d5,(a4)+        plane 2 word
                move.w  d6,(a5)+        plane 3 word
                movem.l a4-a5,8(a3)

                rts

* PutScrWord for 5 bitplanes (32 COL ONLY):

PutScrWord_5    movem.l (a3),a4-a5
                move.w  d3,(a4)+        plane 0 word
                swap    d3
                move.w  d3,(a5)+        plane 1 word
                movem.l a4-a5,(a3)

                movem.l 8(a3),a4-a5
                move.w  d4,(a4)+        plane 2 word
                swap    d4
                move.w  d4,(a5)+        plane 3 word
                movem.l a4-a5,8(a3)

                move.l  16(a3),a4
                move.w  d5,(a4)+        plane 4 word
                move.l  a4,16(a3)

                rts

* PutScrWord for 6 bitplanes (AGA+ ONLY):

PutScrWord_6    movem.l (a3),a4-a5
                move.w  d3,(a4)+        plane 0 word
                swap    d3
                move.w  d3,(a5)+        plane 1 word
                movem.l a4-a5,(a3)

                movem.l 8(a3),a4-a5
                move.w  d4,(a4)+        plane 2 word
                swap    d4
                move.w  d4,(a5)+        plane 3 word
                movem.l a4-a5,8(a3)

                movem.l 16(a3),a4-a5
                move.w  d5,(a4)+        plane 4 word
                swap    d5
                move.w  d5,(a5)+        plane 5 word
                movem.l a4-a5,16(a3)

                rts

* PutScrWord for 7 bitplanes (AGA+ ONLY):

PutScrWord_7    movem.l (a3),a4-a5
                move.w  d3,(a4)+        plane 0 word
                swap    d3
                move.w  d3,(a5)+        plane 1 word
                movem.l a4-a5,(a3)

                movem.l 8(a3),a4-a5
                move.w  d4,(a4)+        plane 2 word
                swap    d4
                move.w  d4,(a5)+        plane 3 word
                movem.l a4-a5,8(a3)

                movem.l 16(a3),a4-a5
                move.w  d5,(a4)+        plane 4 word
                swap    d5
                move.w  d5,(a5)+        plane 5 word
                movem.l a4-a5,16(a3)

                move.l  24(a3),a4
                move.w  d6,(a4)+        plane 6 word
                move.l  a4,24(a3)

                rts

* PutScrWord for 8 bitplanes (AGA+ ONLY):

PutScrWord_8    movem.l (a3),a4-a5
                move.w  d3,(a4)+        plane 0 word
                swap    d3
                move.w  d3,(a5)+        plane 1 word
                movem.l a4-a5,(a3)

                movem.l 8(a3),a4-a5
                move.w  d4,(a4)+        plane 2 word
                swap    d4
                move.w  d4,(a5)+        plane 3 word
                movem.l a4-a5,8(a3)

                movem.l 16(a3),a4-a5
                move.w  d5,(a4)+        plane 4 word
                swap    d5
                move.w  d5,(a5)+        plane 5 word
                movem.l a4-a5,16(a3)

                movem.l 24(a3),a4-a5
                move.w  d6,(a4)+        plane 6 word
                swap    d6
                move.w  d6,(a5)+        plane 7 word
                movem.l a4-a5,24(a3)

                rts

*****************************************************************
*                                                               *
*       ReadByte - Reads a byte from input buffer               *
*                                                               *
* OUTPUTS: d0.w >= 0 if no error occurred,                      *
*               d0.b = byte read from file.                     *
*          d0.w <  0 if an error occurred,                      *
*               d0.b = error code.                              *
* ERRORS:  READ_ERROR, END_OF_FILE, TERMINATE_NOW.              *
*                                                               *
*****************************************************************

ReadByte        move.l  bufferptr(pc),d0
                cmp.l   buffersize(pc),d0
                bne     GetByte

                btst.b  #DL_Mode,Run_Mode
                beq.s   2$
                move.l  a6,-(a7)                save a6 on the stack
                movea.l (execbase).w,a6
                move.l  buffer_size(pc),d0
                movea.l DL_buffer(pc),a1
                cmpa.w  #0,a1
                beq.s   3$
                jsr     _LVOFreeMem(a6)         free old buffer
                clr.l   DL_buffer
3$              move.l  SignalMask(pc),d0       wait for next buffer
                jsr     _LVOWait(a6)
                movea.l (a7)+,a6                restore a6 from stack

                move.b  Signal_1(pc),d1
                btst    d1,d0                   close window selected?
                bne.s   CloseSelected

                move.b  Signal_2(pc),d1
                btst    d1,d0                   mousebutton pressed?
                bne.s   BufferEnd               fake end of file

*** determine what the signal from the DOS-patch code meant ***

                move.l  buffer_size(pc),d0
                beq.s   BufferEnd       
                bra.s   ResumeRead
                
2$              movem.l d2-d3/a1/a6,-(a7)
                
                movea.l UserPort1(pc),a0        check for closewindow
                bsr     GetMessage
                beq.s   1$
                lea     16(a7),a7               fix the stack
                bra.s   CloseSelected
                
*** standard buffered read routine ***

1$              move.l  #bufsize,d3
                bsr     readit
                movem.l (a7)+,d2-d3/a1/a6
ResumeRead      bmi.s   EndReadByte             ;ReadError      check for errors
                ;beq.s  BufferEnd               check for EOF
                move.l  d0,buffersize
                clr.l   bufferptr
                clr.l   d0

GetByte         movea.l buffer(pc),a0
                btst.b  #DL_Mode,Run_Mode       check for DL mode
                beq.s   GetByte2
                movea.l DL_buffer(pc),a0
GetByte2        move.b  0(a0,d0.l),d0
                addq.l  #1,bufferptr
                andi.w  #$00ff,d0               signal no error (+ signed)
                rts

CloseSelected   move.w  #TERMINATE_NOW,d0
                bra.s   EndReadByte
ReadError       move.w  #READ_ERROR,d0
                bra.s   EndReadByte
BufferEnd       move.w  #END_OF_FILE,d0
EndReadByte     clr.l   DL_Handle
                tst.w   d0
                rts

* readit2 is entry point for routiness using own buffer
                
readit          move.l  buffer(pc),d2
readit2         move.l  filehandle(pc),d1
                beq.s   read_2

                move.l  dosbase(pc),a6  do this if not in DL mode
                jsr     _LVORead(a6)
                movea.l buffer(pc),a0
                tst.l   d0              check for error code
                bmi.s   ReadError
                beq.s   BufferEnd
                rts

* read_2 - Virtual disk read. d2 = buffer address, d3 = # bytes to read 

read_2          movea.l d2,a0           a0 = bufferptr
                move.l  a0,-(a7)
                move.l  d3,d1           d1 is new read length
1$              movem.l d1/a0,-(a7)
                bsr     ReadByte        get a byte
                movem.l (a7)+,d1/a0
                bmi.s   2$              exit on error
                move.b  d0,(a0)+        store char in buffer
                subq.l  #1,d1
                bne.s   1$              repeat until bytes read
                clr.w   d0              clear return code
2$              movea.l (a7)+,a0        restore bufferptr
                rts

*****************************************************************
*                                                               *
* CreateDisplay - Displays the loaded bitmap.                   *
*                                                               *
* OUTPUTS: d0.w >= 0 if no error occurred.                      *
*               <  0 if an error occurred (d0.b = error no).    *
* ERRORS:  SCREEN_ERROR, ALLOC_ERROR                            *
*                                                               *
*****************************************************************

CreateDisplay

; get the maximum movement available to mouse and max screen size...

                bsr     GetScreenSize
                bmi     bad_exit

                cmp.w   ns_Width1(pc),d2
                bge.s   3$
                move.w  d2,ns_Width1

3$              cmp.w   ns_Height1(pc),d3
                bge.s   4$
                move.w  d3,ns_Height1

4$              move.w  d0,d6                   save x_res for centering
                move.w  d1,d7                   save y_res for centering

                cmp.w   ns_Width1(pc),d0        mousexmax > screenwidth ? 
                ble.s   5$
                move.w  ns_Width1(pc),d0

5$              cmp.w   ns_Height1(pc),d1       mouseymax > screenheight ?
                ble.s   6$
                move.w  ns_Height1(pc),d1

6$              move.w  iWidth(pc),d4
                sub.w   ns_Width1(pc),d4
                move.w  d4,MaxX                 calculate MaxX

                move.w  iHeight(pc),d4
                sub.w   ns_Height1(pc),d4
                move.w  d4,MaxY

                btst.b  #WB_2.0,Run_Mode
                beq.s   9$

                move.w  ns_Width1(pc),d0        with wb2.0, mouse can go
                move.w  ns_Height1(pc),d1       into overscan area.

9$              subq.w  #1,d0                   range is 0..width-1
                subq.w  #1,d1
                move.w  d0,MouseXmax            store max mouse ranges
                move.w  d1,MouseYmax

                btst.b  #GIF,Run_Mode
                beq.s   DepthOK
                bclr.b  #GIF_GREYSCALE,GifMode
                move.w  ns_Depth1(pc),d0
                cmp.w   MaxDepth(pc),d0
                ble.s   DepthOK
                move.w  #4,ns_Depth1            set depth to 4 (grayscale)
                move.b  #4,bm_Depth1
                bsr     SetGreyMap

DepthOK         lea     NewScreen1(pc),a0
                movea.l intuitionbase(pc),a6

                btst.b  #WB_2.0,Run_Mode
                beq.s   wboldopen

                lea     ScreenTagList(pc),a1
                jsr     _LVOOpenScreenTagList(a6)
                bra.s   chkscr

wboldopen       jsr     _LVOOpenScreen(a6)
chkscr          move.l  d0,screenptr
                beq     screenerr

        *** horizontally centre the screen if centering is on ***

                movea.l d0,a0

                btst.b  #Centering,PreferenceModes      0 = off, 1 = on
                beq.s   nocentering

                sub.w   ns_Width1(pc),d6        d6 = x_res (see above)
                asr.w   #1,d6                   signed divide by 2
                move.w  d6,sc_ViewPort+vp_DxOffset(a0)  set viewport DxOffset
                move.w  d6,8(a0)                screen x-pos

        ***  vertically centre the screen  ***

                sub.w   ns_Height1(pc),d7       d7 = y_res (see above)
                bmi.s   1$
                btst.b  #VertCentType,PreferenceModes   centre down as well?
                beq.s   remakescreen

1$              asr.w   #1,d7                   signed divide by 2
                move.w  d7,sc_ViewPort+vp_DyOffset(a0)  set viewport DyOffset
                move.w  d7,10(a0)               screen y-pos

remakescreen    jsr     _LVOMakeScreen(a6)

nocentering     move.w  ns_Width1(pc),nw_Width1 open IDCMP window
                move.w  ns_Height1(pc),nw_Height1
                lea     IDCMP_Window(pc),a0
                jsr     _LVOOpenWindow(a6)
                move.l  d0,windowptr2
                beq     screenerr
                movea.l d0,a0
                movea.l wd_UserPort(a0),a0
                move.l  a0,UserPort2
                move.b  mp_SigBit(a0),d0        get windows signal number
                move.b  d0,Signal_2
                move.l  SignalMask(pc),d1
                bset    d0,d1
                move.l  d1,SignalMask

InitCMAP        btst.b  #DL_Mode,Run_Mode       check for DL mode
                bne.s   SetInitCmap
                btst.b  #3,ns_ViewModes1        check for HAM screen
                bne.s   SetInitCmap
                btst.b  #Fading,PreferenceModes 0 = off, 1 = on
                bne.s   SetBlankCmap

SetInitCmap     movea.l ColourTab(pc),a0
                movea.l BlankColourTab(pc),a1
                move.l  ColourTabSize(pc),d0
                subq.w  #1,d0                   dbf loop count
1$              move.b  (a0)+,(a1)+
                dbf     d0,1$

SetBlankCmap    movea.l screenptr(pc),a0
                lea     sc_ViewPort(a0),a0
                move.l  a0,scrViewPort
                movea.l BlankColourTab(pc),a1
                movea.l grbase(pc),a6

                btst.b  #WB_3.0,Run_Mode        24-bit palette?
                bne.s   SetBlankCmap32

SetBlankCmap4   move.w  NoColours(pc),d0
                jsr     _LVOLoadRGB4(a6)
                bra.s   Cmap2

SetBlankCmap32  jsr     _LVOLoadRGB32(a6)

Cmap2           btst.b  #DL_Mode,Run_Mode       check for DL mode
                beq.s   1$                      no, keep screen to back
                movea.l screenptr(pc),a0
                movea.l intuitionbase(pc),a6
                jsr     _LVOScreenToFront(a6)   yes, send screen to front

1$              bsr     RefreshWindow
                clr.w   d0
                rts

screenerr       move.w  #SCREEN_ERROR,d0
bad_exit        rts

*****************************************************************
*                                                               *
* GetScreenSize - Calculates required screen dimensions         *
*                                                               *
* INPUTS: d0 = screen mode                                      *
* OUTPUT: d0 = standard screen width                            *
*         d1 = standard screen height                           *
*         d2 = maximum overscan width                           *
*         d3 = maximum overscan height                          *
*                                                               *
*****************************************************************

GetScreenSize   btst.b  #WB_2.0,Run_Mode        If workbench2.0+, then
                bne.s   WB2_dimensions          consult display database

                move.w  #4,MaxDepth             default max screen depth

                move.w  #640,d0                 put max horiz. size in d0
                move.w  #512,d1                 PAL vert. size
                move.w  #704,d2                 std. PAL overscan dimensions

2$              move.w  #566,d3

1$              btst.b  #NTSC_Mode,Run_Mode     test for NTSC
                beq.s   PAL
                move.w  #400,d1                 set d1 to 400 (NTSC size)
                move.w  #480,d3                 set vert. overscan

PAL             btst.b  #VB_HIRES-8,ns_ViewModes1       test for HIRES
                bne.s   notlores
                move.w  #5,MaxDepth             max screen depth for LORES
;                                               not including HAM & EHB
                move.w  #320,d0                 set max x position
                move.w  #362,d2                 set max x overscan
                
notlores        btst.b  #VB_LACE,ns_ViewModes1+1        test for ILACE
                bne.s   notlaced
                lsr.w   #1,d1                   set max y position nonlaced
                lsr.w   #1,d3                   set max y overscan nonlaced

notlaced        move.w  #4096,PaletteRange
                rts

WB2_dimensions  movea.l grbase(pc),a6
                move.l  #NTSC_MONITOR_ID,d0
                or.w    ns_ViewModes1(pc),d0
                btst.b  #NTSC_Mode,Run_Mode
                beq.s   3$
                bsr.s   GetDisplaySize
                bmi.s   3$
                rts

3$              btst.b  #PAL_Mode,PreferenceModes       use PAL only?
                bne.s   2$
                bsr.s   GetDisplaySize          1st, check for NTSC
                bmi.s   1$
                cmp.w   ns_Height1(pc),d3       can it accommodate height?
                bge.s   1$                      yes!
2$              move.l  #PAL_MONITOR_ID,d0
                or.w    ns_ViewModes1(pc),d0    else, use best monitor
                bsr.s   GetDisplaySize
1$              rts

GetDisplaySize  move.l  d0,ExtViewModes
                jsr     _LVOFindDisplayInfo(a6)
                movea.l d0,a0                   a0->displayinfoheader
                movea.l buffer(pc),a1           a1->data buffer
                moveq.l #dis_SIZEOF,d0          size of buffer
                move.l  #DTAG_DISP,d1           display tag ID
                clr.l   d2                      displayID = NULL
                movem.l d2/a0/a1,-(a7)
                jsr     _LVOGetDisplayInfoData(a6)
                tst.l   d0
                beq.s   bad_mode
                movea.l buffer(pc),a0
                tst.w   dis_NotAvailable(a0)    check if mode available
                bne.s   bad_mode                no
;               move.l  dis_PropertyFlags(a0),DisplayProperties
                move.w  dis_PaletteRange(a0),PaletteRange

                movem.l (a7)+,d2/a0/a1

                move.l  dim_SIZEOF,d0
                move.l  #DTAG_DIMS,d1           dimension tag ID
                jsr     _LVOGetDisplayInfoData(a6)
                tst.l   d0
                beq.s   bad_mode
                movea.l buffer(pc),a0
                move.w  dim_MaxDepth(a0),MaxDepth
                move.w  dim_Nominal+ra_MaxX(a0),d0      normal width
                move.w  dim_Nominal+ra_MaxY(a0),d1      normal height
                move.w  dim_MaxOScan+ra_MinX(a0),d2
                neg.w   d2
                add.w   dim_MaxOScan+ra_MaxX(a0),d2     max oscan width
                move.w  dim_MaxOScan+ra_MinY(a0),d3
                neg.w   d3
                add.w   dim_MaxOScan+ra_MaxY(a0),d3     max oscan height
                
                addq.w  #1,d0   we want 1..width, rather than 0..width-1
                addq.w  #1,d1
                addq.w  #1,d2   ditto
                addq.w  #1,d3
                rts

bad_mode        lea     12(a7),a7               adjust stack
                move.w  #MODENOTSUPPORTED,d0
                rts

*****************************************************************
*                                                               *
* ShowPic - Displays, fades & scrolls screen.                   *
*                                                               *
*****************************************************************

ShowPic         movea.l screenptr(pc),a0
                movea.l a0,a2                   a2 = screenptr
                movea.l intuitionbase(pc),a6
                jsr     _LVOScreenToFront(a6)

                btst.b  #3,ns_ViewModes1
                bne.s   no_ham_fade_on
                btst.b  #Fading,PreferenceModes 0 = off, 1 = on
                beq.s   no_ham_fade_on
                clr.w   d7
                moveq.w #FadeSpeed_AGA,d6
                cmpi.w  #$ffff,PaletteRange     24-bit pallette? ie. AGA
                beq.s   fade_on
                moveq.w #FadeSpeed_STD,d6
fade_on         bsr     FadeScreen
                add.w   d6,d7
                cmpi.w  #$100,d7
                bne.s   fade_on

no_ham_fade_on  movea.l 80(a2),a3               a3 = rasinfo

ScrollLoop      movea.l grbase(pc),a6
                movea.l scrViewPort(pc),a0
                jsr     _LVOWaitBOVP(a6)

                tst.w   MaxX
                bne.s   3$
                tst.w   MaxY
                bne.s   4$
                bra.s   CheckForMsg

3$              move.w  sc_MouseX(a2),d0
                bpl.s   8$                      minus mouseX?
                moveq.w #0,d0
8$              beq.s   1$
                move.w  MaxX(pc),d1
                mulu    d1,d0
                move.w  MouseXmax(pc),d1        used to be ns_Width
                divu    d1,d0

                btst.b  #VB_HIRES-8,ns_ViewModes1       HIRES?
                beq.s   1$

                btst.b  #WB_2.0,Run_Mode
                bne.s   1$
                                                ;stop screen glitching
                andi.w  #$fff0,d0               ;with large high res
                                                ;4 bitplane displays
1$              move.w  d0,ri_RxOffset(a3)
                
4$              move.w  sc_MouseY(a2),d0
                bpl.s   9$                      minus mouseY?
                moveq.w #0,d0
9$              beq.s   2$
                move.w  MaxY(pc),d1
                mulu    d1,d0
                move.w  MouseYmax(pc),d1        used to be ns_Height
                divu    d1,d0
2$              move.w  d0,ri_RyOffset(a3)

                movea.l a2,a0                   a0 = screenptr
                movea.l intuitionbase(pc),a6
                jsr     _LVOMakeScreen(a6)      rebuild screen copperlist
                jsr     _LVORethinkDisplay(a6)  enable new copperlist

CheckForMsg     movea.l UserPort1(pc),a0
                bsr     GetMessage              check for closewindow
                bne.s   3$
                movea.l UserPort2(pc),a0        check left-mousebutton
                bsr     GetMessage
                beq     ScrollLoop

3$              btst.b  #3,ns_ViewModes1
                bne.s   no_ham_fade_off
                btst.b  #Fading,PreferenceModes 0 = off, 1 = on
                beq.s   no_ham_fade_off
                move.w  #$100,d7
fade_off        bsr     FadeScreen
                sub.w   d6,d7
                bne.s   fade_off
no_ham_fade_off rts

*****************************************************************
*                                                               *
* GetMessage - Tests for and replys to a received message.      *
*                                                               *
* INPUTS:  a0 = userport address                                *
* OUTPUTS: d0 = 0 if no message was received.                   *
*            <> 0 if message was received.                      *
*                                                               *
*****************************************************************

GetMessage      movea.l (execbase).w,a6         check for closewindow
                jsr     _LVOGetMsg(a6)
                tst.l   d0
                beq.s   1$
                movea.l d0,a1                   a1 = message
                move.l  d0,-(a7)
                jsr     _LVOReplyMsg(a6)        reply the message
                move.l  (a7)+,d0
1$              rts

*****************************************************************
*                                                               *
*       FadeScreen - Fades screen colours to/from black         *
*                                                               *
*    Input:  d7.b : fade intensity value                        *
*                                                               *
*****************************************************************

FadeScreen      movem.l d0-d3/a0-a1/a6,-(a7)

                movea.l grbase(pc),a6
                clr.w   d2
ScreenDelay     movea.l scrViewPort(pc),a0
                jsr     _LVOWaitBOVP(a6)

                bsr     FadeOnOff       adjust screen

                movem.l (a7)+,d0-d3/a0-a1/a6
                rts

FadeOnOff       move.w  NoColours(pc),d3
                subq.w  #1,d3           setup for dbf loop
                movea.l ColourTab(pc),a0
                movea.l BlankColourTab(pc),a1

                btst.b  #WB_3.0,Run_Mode
                beq.s   FadeOnOff4

                addq.w  #1,d3
                mulu.w  #3,d3           d3 = NoColours*3
                subq.w  #1,d3           'cos of dbf
                addq    #4,a0           skip count + startindex
                addq    #4,a1

FadeOnOff32     move.l  (a0)+,d0        get component value
                bsr     adjustRGB32     adjust colour component
                move.l  d0,(a1)+
                dbf     d3,FadeOnOff32

                movea.l scrViewPort(pc),a0
                movea.l BlankColourTab(pc),a1
                jsr     _LVOLoadRGB32(a6)
                rts

adjustRGB32     rol.l   #8,d0           convert $xx000000 -> $000000xx
                mulu    d7,d0           colour * count
                lsr.w   #8,d0           (colour * count)/256
                andi.l  #$000000ff,d0
                ror.l   #8,d0           convert $000000yy -> $yy000000
                rts

FadeOnOff4      move.w  (a0)+,d0        get colour value

                move.b  d0,d1
                bsr     adjustRGB4      adjust blue component
                move.w  d1,d2

                move.b  d0,d1
                lsr.b   #4,d1
                bsr     adjustRGB4      adjust green component
                lsl.w   #4,d1
                or.w    d1,d2

                move.w  d0,d1
                lsr.w   #8,d1
                bsr     adjustRGB4      adjust red component
                lsl.w   #8,d1
                or.w    d1,d2
                move.w  d2,(a1)+
        
                dbf     d3,FadeOnOff4

                movea.l scrViewPort(pc),a0
                movea.l BlankColourTab(pc),a1
                move.w  NoColours(pc),d0
                jsr     _LVOLoadRGB4(a6)
                rts

adjustRGB4      andi.w  #$000f,d1
                mulu    d7,d1           colour * count
                lsr.w   #8,d1           (colour * count)/256
                rts

*****************************************************************
*                                                               *
* Pause - Debugging routines.                                   *
*                                                               *
*****************************************************************

;Pause_White    movem.l d0-d7/a0-a6,-(a7)
;               move.w  #$fff,d0
;               bra.s   Pause
;
;Pause_Red      movem.l d0-d7/a0-a6,-(a7)
;               move.w  #$f00,d0
;               bra.s   Pause
;
;Pause_Green    movem.l d0-d7/a0-a6,-(a7)
;               move.w  #$0f0,d0
;               bra.s   Pause
;
;Pause_Blue     movem.l d0-d7/a0-a6,-(a7)
;               move.w  #$00f,d0
;
;Pause
;1$             btst.b  #7,$bfe001
;               beq.s   1$
;
;2$             move.w  d0,$dff180
;               btst.b  #7,$bfe001
;               bne.s   2$
;               btst.b  #7,$bfe001
;               bne.s   2$
;
;               movem.l (a7)+,d0-d7/a0-a6
;               rts

*****************************************************************
*                                                               *
* PatchDOS - Patches MegaView into the following DOS vectors:   *
*                Open(), Write() and Close().                   *
*                                                               *
*****************************************************************

SetDOS          macro
                move.w  _LVO\1(a1),Old\1        save old library contents
                move.l  _LVO\1+2(a1),Old\1+2
                move.w  New\1(pc),_LVO\1(a1)
                move.l  New\1+2(pc),_LVO\1+2(a1)        store new library contents
                endm

PatchDOS        movea.l (execbase).w,a6

                ;jsr    _LVOForbid(a6)  disable task switching
                
                movea.l dosbase(pc),a1
                bset    #LIBB_CHANGED,LIB_FLAGS(a1)     Indicate DOS changed
                SetDOS  Open
                SetDOS  Close
                SetDOS  Write

                jsr     _LVOSumLibrary(a6)      a1 = DOS library

                ;jsr    _LVOPermit(a6)  enable task switching
                rts

*****************************************************************
*                                                               *
* UnpatchDOS - Releses patches from the following DOS vectors:  *
*                Open(), Write() and Close().                   *
*                                                               *
* ERRORS: DOS_CHANGED.                                          *
*                                                               *
*****************************************************************

Test            macro
                move.l  New\1+2(pc),d0  get old address of function
                cmp.l   _LVO\1+2(a2),d0 check to see if altered
                bne.s   DOSchanged      exit if altered
                endm

Restore         macro
                move.w  Old\1(pc),_LVO\1(a2)    restore library vector
                move.l  Old\1+2(pc),_LVO\1+2(a2)
                endm

UnpatchDOS      movea.l (execbase).w,a6
                movea.l dosbase(pc),a2
                Test    Open            check old vectors
                Test    Close
                Test    Write

                ;jsr    _LVOForbid(a6)  disable task switching

                bset    #LIBB_CHANGED,LIB_FLAGS(a2)     indicate DOS changed
                Restore Open
                Restore Close
                Restore Write
                
                movea.l a2,a1
                jsr     _LVOSumLibrary(a6)

                ;jsr    _LVOPermit(a6)  enable task switching
                clr.w   d0
                rts

DOSchanged      move.w  #DOS_CHANGED,d0
                rts

*****************************************************************
*                                                               *
* DOS-call macro and function                                   *
*                                                               *
*****************************************************************

OldDOS          macro                   for calling the saved DOS vectors
                movem.l a2-a6/d2-d7,-(a7)
                lea     Old\1(pc),a0    get pointer to old vector
                move.w  #_LVO\1,d0      get function offset
                bsr     CallDos
                movem.l (a7)+,a2-a6/d2-d7
                endm

CallDos         movem.l d1-d3/d6/d7/a6,-(a7)
                movea.l dosbase(pc),a6

                move.w  (a0),d6         get previous instruction
                cmp.w   #$4ef9,d6       check for JMP
                bne.s   dos_exec
                move.l  2(a0),a0        call 2.0-style function
                
                jsr     (a0)            call old Dos function
                bra.s   callexit

dos_exec        move.w  (a0),d6         get MOVEQ instruction
                ext.w   d6
                ext.l   d6              sign-extend to longword
                exg.l   d0,d6
                move.w  4(a0),d7        get offset of DOS routine
                add.w   d6,d7           calculate offset value
                jsr     4(a6,d7.w)      call DOS function dispatcher

callexit        movem.l (a7)+,d1-d3/d6/d7/a6
                rts

*  this code gets moved directly into the dos library vectors

NewOpen         jmp     DoOpen
NewClose        jmp     DoClose
NewWrite        jmp     DoWrite

DoOpen          move.l  d1,-(a7)        save ptr to filename
                OldDOS  Open            perform normal open() function
                tst.l   DL_Handle       test for DL already in progress
                beq.s   2$
                btst.b  #DL_IN_PROGRESS,Run_Mode
                bne.s   1$
2$              cmpi.l  #MODE_NEWFILE,d2        new file being created?
                bne.s   1$
                move.l  d0,DL_Handle

                move.l  a0,-4(a7)
                move.l  (a7),a0         get filename pointer
                bsr     CopyFilename
                clr.l   filename
                move.l  -4(a7),a0

1$              addq    #4,a7   fix stack
                tst.l   d0              update flags based on d0
                rts

DoClose         cmp.l   DL_Handle(pc),d1        is DL file being closed?
                bne.s   1$
                bclr.b  #DL_IN_PROGRESS,Run_Mode
2$              tst.l   DL_buffer
                bne.s   2$              exit if file finished with

                movem.l d0-d1/a0-a1/a6,-(a7)

                clr.l   buffer_size     set buffer size to zero

                movea.l TaskCB(pc),a1
                clr.l   d0
                move.b  Signal_3(pc),d1
                bset    d1,d0           set signal mask
                movea.l (execbase).w,a6
                jsr     _LVOSignal(a6)  inform program of the close
                
                movem.l (a7)+,d0-d1/a0-a1/a6

1$              OldDOS  Close
                rts

DoWrite         cmp.l   DL_Handle(pc),d1        test for DL file
                beq.s   ScanWrite
                OldDOS  Write
                rts

ScanWrite       bset.b  #DL_IN_PROGRESS,Run_Mode
                OldDOS  Write
                movem.l d0-d7/a0-a6,-(a7)

                movea.l (execbase).w,a6
                tst.l   DL_buffer
                bne.s   TooSlow         abort if old buffer not yet processed

                move.l  d0,buffer_size  # chars written
                beq.s   SignalBuffer    skip if eof
                bpl.s   WriteOK
                clr.l   buffer_size     if write error, skip to signal code
                bra.s   SignalBuffer
                
WriteOK         move.l  d0,d7           copy buffer size
                moveq.l #MEMF_PUBLIC,d1 allocation requirements
                jsr     _LVOAllocMem(a6)
                move.l  d0,DL_buffer
                bne.s   BufAllocOK      if memory wasn't allocated then
                clr.l   buffer_size     ; let DL_Buffer stay 0 to fake an EOF
                bra.s   SignalBuffer

BufAllocOK      movea.l d2,a0           a0 = source buffer
                movea.l d0,a1           a1 = new (copy) buffer
1$              move.b  (a0)+,(a1)+     copy buffer
                subq.l  #1,d7           repeat for rest of buffer
                bne.s   1$

SignalBuffer    move.b  Signal_3(pc),d1
                bra.s   SendSignal

TooSlow         move.b  Signal_2(pc),d1
SendSignal      clr.l   d0
                bset    d1,d0           set signal mask
                movea.l TaskCB(pc),a1   task pointer
                jsr     _LVOSignal(a6)  send false mouseclick signal

5$              movem.l (a7)+,d0-d7/a0-a6

1$              tst.l   d0
                rts

*****************************************************************
*                                                               *
* Initialised data area                                         *
*                                                               *
*****************************************************************

NewWindow1
window_xpos     dc.w    0               LeftEdge
window_ypos     dc.w    0               TopEdge
                dc.w    WINDOW_WIDTH,WINDOW_HEIGHT      Width,Height
                dc.b    1,2             DetailPen,BlockPen
                dc.l    CLOSEWINDOW     IDCMPFlags
                dc.l    ACTIVATE|RMBTRAP|DRAGBAR|DEPTHGADGET|CLOSEGADGET
                dc.l    0,0,ProgTitle,0,0
                dc.w    0,0,0,0         Min/max width/height
                dc.w    WBENCHSCREEN    Parent screen type

ProgTitle       dc.b    'MegaView V2.40b                   ',0
                even

TextAttrStruct  dc.l    FontName1
                dc.w    8               size
                dc.b    NORMAL          style
                dc.b    ROMFONT         flags

FontName1       dc.b    'topaz.font',0
                even

IntuiTextStruct
FrontPen        dc.b    0,0,JAM1,0
                dc.w    0,10
                dc.l    0
IText           dc.l    0,0

Message1        dc.b    'MEGAVIEW VERSION 2.40b',0
                even
Message2        dc.b    'BY TONY MICELI 21/5/93',0
                even
Message3        dc.b    'FILENAME:',0
                even
Message4        dc.b    'FORMAT  :',0
                even
Message5        dc.b    'MODE    :',0
                even
SUPERHIRES_msg  dc.b    'SUPER'
HIRES_msg       dc.b    'HIRES',0
                even
LORES_msg       dc.b    'LORES',0
                even
HAM_msg         dc.b    'HAM',0
                even
HAM8_msg        dc.b    'HAM8',0
                even
HALFBRITE_msg   dc.b    'HALFBRITE',0
                even
LACE_msg        dc.b    'INTERLACED',0
                even
_x_             dc.b    ' x ',0
                even
HAM8_cols       dc.b    '262144',0
                even
Colours         dc.b    ' COLOURS',0
                even

FileError       dc.b    0
                even

ERROR_NUM       set     0

ERROR           macro                   error definition macro
\1              equ     ERROR_NUM|$8000 format = -1*error_no
ERROR_NUM       set     ERROR_NUM+1
                endm

Error_Table     
*** first declare general messages: ****

                dc.l    General_msg0    reading IFF...
                ERROR   READING_IFF
                dc.l    General_msg1    waiting for download...
                ERROR   WAITING_FOR_DL  
                dc.l    General_msg2    scanning IFF download...
                ERROR   SCANNING_IFF
                dc.l    General_msg3    reading GIF...
                ERROR   READING_GIF
                dc.l    General_msg4    scanning GIF download...
                ERROR   SCANNING_GIF

*** Now comes fatal errors: ***

FATAL_LEVEL     equ     ERROR_NUM
                dc.l    Error_msg0      read error
                ERROR   READ_ERROR
                dc.l    Error_msg1      not enough RAM for image
                ERROR   ALLOC_ERROR
                dc.l    Error_msg2      screen error
                ERROR   SCREEN_ERROR
                dc.l    Error_msg3      unknown format
                ERROR   UNKNOWN_TYPE
                dc.l    Error_msg4      dos vectors changed
                ERROR   DOS_CHANGED
                dc.l    Error_msg5      file not found
                ERROR   FILE_NOT_FOUND
                dc.l    Error_msg6      BMHD missing
                ERROR   BMHD_MISSING
                dc.l    Error_msg7      CMAP missing
                ERROR   CMAP_MISSING
                dc.l    Error_msg8      BODY misssing
                ERROR   BODY_MISSING
                dc.l    Error_msg9      buffer RAM allocation error
                ERROR   BUFFER_RAM
                dc.l    Error_msg10     IFF not ILBM type
                ERROR   IFF_NOT_ILBM
                dc.l    Error_msg11     Can't allocate string table
                ERROR   ALLOC_TABLE_ERR
                dc.l    Error_msg12     bad_min_code_size for LZW
                ERROR   BAD_MIN_CODE_SZ
                dc.l    Error_msg13
                ERROR   MODENOTSUPPORTED

*** And finally, the non-printable errors: ***

HIDDEN_LEVEL    equ     ERROR_NUM
                ERROR   END_OF_FILE
                ERROR   TERMINATE_NOW

General_msg0    dc.b    'Reading IFF ILBM 85 file...       ',0
                even
General_msg1    dc.b    'Waiting for download...           ',0
                even
General_msg2    dc.b    'Scanning IFF ILBM 85 download...  ',0
                even
General_msg3    dc.b    'Reading GIF '
Gifversion      dc.b    0,0,0,' file...           ',0
                even
General_msg4    dc.b    'Scanning GIF '
Gifversion2     dc.b    0,0,0,' file...          ',0
                even
Error_msg0      dc.b    'Read error occurred !!!           ',0
                even
Error_msg1      dc.b    'Could not allocate RAM for image. ',0
                even
Error_msg2      dc.b    'Could not open screen for display.',0
                even
Error_msg3      dc.b    'File is of unknown format.        ',0
                even
Error_msg4      dc.b    'Cannot exit: DOS vectors changed !',0
                even
Error_msg5      dc.b    'File not found error.             ',0
                even
Error_msg6      dc.b    'Cannot display: BMHD chunk missing',0
                even
Error_msg7      dc.b    'Cannot display: CMAP chunk missing',0
                even
Error_msg8      dc.b    'Cannot display: BODY chunk missing',0
                even
Error_msg9      dc.b    'Could not allocate RAM for buffer.',0
                even
Error_msg10     dc.b    'IFF is not of type ILBM.          ',0
                even
Error_msg11     dc.b    'Couldn''t allocate LZW string table',0
                even
Error_msg12     dc.b    'Bad min_code_size in LZW data.    ',0
                even
Error_msg13     dc.b    'Cannot display on this gfx chipset',0
                even

dosname         dc.b    'dos.library',0
                even
grname          dc.b    'graphics.library',0
                even
intuition       dc.b    'intuition.library',0
                even
aslname         dc.b    'asl.library',0
                even
reqtoolsname    dc.b    'reqtools.library',0
                even
iconname        dc.b    'icon.library',0
                even
                
*****************************************************************
*                                                               *
* BitMap System Structure                                       *
*                                                               *
*****************************************************************

BitMap1
bm_BytesPerRow1 dc.w    0
bm_Rows1        dc.w    0
                dc.b    0
bm_Depth1       dc.b    0
                dc.w    0
bm_Planes1      dc.l    0,0,0,0,0,0,0,0

*****************************************************************
*                                                               *
* NewScreen Structure                                           *
*                                                               *
*****************************************************************

NewScreen1
ns_LeftEdge1    dc.w    0               x-position
ns_TopEdge1     dc.w    0               y-position
ns_Width1       dc.w    0
ns_Height1      dc.w    0
ns_Depth1       dc.w    0
                dc.b    0,0
ns_ViewModes1   dc.w    0
                dc.w    CUSTOMSCREEN|CUSTOMBITMAP|SCREENBEHIND|SCREENQUIET
                dc.l    0,0,0
                dc.l    BitMap1         custom bitmap

*****************************************************************
*                                                               *
* Window Structure for IDCMP Events in the NewScreen            *
*                                                               *
*****************************************************************

IDCMP_Window    
nw_LeftEdge1    dc.w    0               Xpos
nw_TopEdge1     dc.w    0               Ypos
nw_Width1       dc.w    0               Width
nw_Height1      dc.w    0               Height
                dc.b    0,0             DetailPen,BlockPen
                dc.l    MOUSEBUTTONS    IDCMPFlags
                dc.l    ACTIVATE|RMBTRAP|BORDERLESS|BACKDROP|NOCAREREFRESH
                dc.l    0,0,0
screenptr       dc.l    0,0
                dc.w    0,0,0,0         Min/max width/height
                dc.w    CUSTOMSCREEN    Parent screen type

*****************************************************************
*                                                               *
* Uninitialised data area                                       *
*                                                               *
*****************************************************************

dosbase         dc.l    0
grbase          dc.l    0
intuitionbase   dc.l    0
AslBase         dc.l    0
ReqToolsBase    dc.l    0
iconbase        dc.l    0
ReqPtr          dc.l    0
DirLock         dc.l    0
DiskObjectptr   dc.l    0
windowptr       dc.l    0
windowptr2      dc.l    0
RastPort1       dc.l    0
scrViewPort     dc.l    0
scrRastPort     dc.l    0
TextFont1       dc.l    0
Initial_SP      dc.l    0
WBmessage       dc.l    0
filehandle      dc.l    0
DL_Handle       dc.l    0
buffer          dc.l    0
DL_buffer       dc.l    0
foundChunks     dc.b    0
                even
currentpos      dc.l    0
ColourTabSize   dc.l    0
ColourTab       dc.l    0
BlankColourTab  dc.l    0
NoColours       dc.w    0
iWidth          dc.w    0
iHeight         dc.w    0
iCompr          dc.b    0
Signal_1        dc.b    0
Signal_2        dc.b    0
Signal_3        dc.b    0
Pens
Pen0            dc.b    0
Pen1            dc.b    0
Pen2            dc.b    0
Pen3            dc.b    0
bufferptr       dc.l    0
buffersize      dc.l    0
buffer_size     dc.l    0
MouseXmax       dc.w    0
MouseYmax       dc.w    0
MaxX            dc.w    0
MaxY            dc.w    0
filename        dc.l    0
filename_buf    dcb.b   32,0
OldOpen         dc.w    0,0,0
OldClose        dc.w    0,0,0
OldWrite        dc.w    0,0,0
SignalMask      dc.l    0
UserPort1       dc.l    0
UserPort2       dc.l    0
TaskCB          dc.l    0
NumArgs         dc.l    0
Run_Mode        dc.b    0
GifMode         dc.b    0
X_Pos           dc.w    0
Y_Pos           dc.w    0
;DisplayProperty        dc.l    0
PaletteRange    dc.w    0
MaxDepth        dc.w    0

* Vars used for LZW decompression

code_table      dc.l    0
bits_per_pixel  dc.b    0
bytes_unread    dc.b    0
Pass            dc.b    0
                even
bit_offset      dc.w    0
code_size       dc.w    0
clear_code      dc.w    0
eof_code        dc.w    0
first_free      dc.w    0
free_code       dc.w    0
max_code        dc.w    0
min_code_size   dc.w    0
input_buffer    dc.l    0
Planeptrs       dcb.l   8,0     current bitplane pointers
old_code        dc.w    0
suffix_char     dc.w    0
final_char      dc.w    0
input_code      dc.w    0

* Screen taglist for workbench 2.0+

ScreenTagList   dc.l    SA_DisplayID
ExtViewModes    dc.l    0
;               dc.l    SA_Type
;ExtScreenFlags dc.l    CUSTOMSCREEN|CUSTOMBITMAP|SCREENBEHIND|SCREENQUIET|AUTOSCROLL
                dc.l    TAG_DONE

* TagList for ASL file requester

ASLTagList      dc.l    ASL_FuncFlags
                dc.l    $00000009       use pattern gadget/use multiselect
                dc.l    TAG_DONE

ASLRequestTags  dc.l    ASL_LeftEdge
AslReqLeftEdge  dc.l    0
                dc.l    ASL_TopEdge
                dc.l    10
                dc.l    ASL_Width
                dc.l    318
                dc.l    ASL_Height
AslReqHeight    dc.l    $000000b2
                dc.l    ASL_Hail
                dc.l    ReqTitle
                dc.l    TAG_DONE

ReqToolsTags    dc.l    RTFI_HEIGHT
ReqReqHeight    dc.l    0
                dc.l    RTFI_FLAGS
                dc.l    FREQF_PATGAD|FREQF_MULTISELECT
                dc.l    RT_REQPOS
                dc.l    REQPOS_CENTERWIN
                dc.l    TAG_DONE

ReqTitle        dc.b    'Select file(s) to MegaVIEW!',0
                even

AutoRequest     dc.b    '-*',0
                even

Help_Msg        dc.b    $0a
                dc.b    27,'[1m',27,'[33mMEGAVIEW 2.40b',27,'[22m'
                dc.b    ' -- IFF/GIF file/download viewer.',$0a
                dc.b    27,'[31m        by Tony Miceli 21/5/93',$0a,$0a
                dc.b    'Template: MegaView -[options] [filenames] -[options] [filenames] ...',$0a
                dc.b    'Where options are:',$0a,$0a
                dc.b    '       -* = Request file(s).',$0a
                dc.b    '       -c = Toggle screen centering.',$0a
                dc.b    '       -d = Invoke download viewing mode.',$0a
                dc.b    '       -f = Toggle screen fading.',$0a
                dc.b    '       -p = Toggle PAL-only mode.',$0a
;               dc.b    '       -q = Quiet mode.',$0a
;               dc.b    '       -s = Toggle scrolling mode (see docs).',$0a
                dc.b    '       -v = Toggle vertical centering type (see docs).',$0a
                dc.b    $0a
Help_Len        equ     *-Help_Msg
                even

BadArg_msg      dc.b    $0a,'Bad argument selected -> '
Bad_Arg_Pos     dc.b    0,'.       ',$0a,0
BadArg_len      equ     *-BadArg_msg
                even

*****************************************************************
*                                                               *
* ToolArgs structure definition:                                *
*                                                               *
*       ToolArgs:                                               *
*       0       dc.l    Toolname        ;name of tool           *
*       4       dc.w    BitNo           ;PreferenceModes bit #  *
*       6       dc.l    On_Text         ;Tool value for 'ON'    *
*       10      dc.l    Off_Text        ;Tool value for 'OFF'   *
*                   ....                                        *
*               dc.l    0               ;end of list            *
*                                                               *
*       EXCEPTION:      Takes place if BitNo = -1               *
*                       Used for tools that require no '=VALUE' *
*       ToolArgs:                                               *
*       0       dc.l    Toolname        ;ditto                  *
*       4       dc.w    -1                                      *
*       6       dc.l    On_Subroutine   ;ptr to 'ON' subroutine *
*       10      dc.l    Off_Subroutine  ;ptr to 'OFF' routine   *
*                                                               *
*****************************************************************

ToolArgs        dc.l    Centering_Tool  screen centering tooltype
                dc.w    Centering
                dc.l    On_Text
                dc.l    Off_Text

                dc.l    Download_Tool   download viewing tooltype
                dc.w    -1
                dc.l    SetDL_Mode
                dc.l    NoDL_Mode

                dc.l    Fading_Tool     screen fading tooltype
                dc.w    Fading
                dc.l    On_Text
                dc.l    Off_Text

                dc.l    AutoPAL_Tool    auto PAL tooltype
                dc.w    -1
                dc.l    SetAuto_PAL
                dc.l    NoAuto_PAL

                dc.l    VertCenter_Tool vert centering tooltype
                dc.w    VertCentType
                dc.l    On_Text
                dc.l    Up_Text

                dc.l    Requester_Tool  file requester tooltype
                dc.w    -1              see specs
                dc.l    SetAutoRequest
                dc.l    NoAutoRequest

                dc.l    0               end of ToolArgs list

Centering_Tool  dc.b    'CENTERING',0
                even
Download_Tool   dc.b    'DL_MODE',0
                even
Fading_Tool     dc.b    'FADING',0
                even
AutoPAL_Tool    dc.b    'AUTO_PAL',0
                even
VertCenter_Tool dc.b    'VERT_CENTERING',0
                even
Requester_Tool  dc.b    'AUTOREQUEST',0
                even
On_Text         dc.b    'ON',0
                even
Off_Text        dc.b    'OFF',0
                even
Up_Text         dc.b    'UP',0
                even

* Preference values

PreferenceModes dc.b    %00100101
                even

Centering       equ     0       default = on
VertCentType    equ     1       default = only up
Fading          equ     2       default = on
PAL_Mode        equ     3       default = off (ie. use both NTSC & PAL)
Scroll_Mode     equ     4       default = off (ie. use my custom scroller)
Quiet_Mode      equ     5       default = open status window
DL_Flag         equ     6       flag download mode

;horizresolution        dc.b    0       0 = default, 1 = 320, 2 = 640, 3 = 1280
;vertresolution dc.b    0       0 = default, 1 = 256, 2 = 512, 3 = 1024
