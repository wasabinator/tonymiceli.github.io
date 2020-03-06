****************************************************
*                                                  *
*      ArcToolv1.5 by Anthony Miceli 1991-93       *
*      -------------------------------------       *
*                                                  *
****************************************************

;               opt     i+,c+,e+        case dependent + even checks on

** registered user flag: used to disable certain features **

REGISTERED_USER set     1

** constants ** 

BACKGRND        equ     0
LT_GREY         equ     1
MD_GREY         equ     2
DK_GREY         equ     3
YELLOW          equ     4
LT_BLUE         equ     5
MD_BLUE         equ     6
DK_BLUE         equ     7

ARC_REQ_LEFT    equ     48
ARC_REQ_RIGHT   equ     ARC_REQ_LEFT+239
FILE_REQ_LEFT   equ     351
FILE_REQ_RIGHT  equ     FILE_REQ_LEFT+239
REQ_TOP         equ     73
REQ_WIDTH       equ     ARC_REQ_RIGHT-ARC_REQ_LEFT

NULL            equ     0
execbase        equ     4
HIRES           equ     $8000
WBENCHSCREEN    equ     $0001
CUSTOMSCREEN    equ     $000f
MEMF_CHIP       equ     2
MEMF_PUBLIC     equ     1
JAM1            equ     0
JAM2            equ     1
WindowRastPort  equ     $32
WindowUserPort  equ     $56
ScreenViewPort  equ     44
ScreenRastPort  equ     84
MODE_OLD        equ     1005
MODE_READ       equ     -2
MODE_NEW        equ     1006
NodeSize        equ     118
Class           equ     20
Code            equ     24
IAddress        equ     28
GadgetUserData  equ     40
GadgetID        equ     38
pr_CLI          equ     $ac
pr_MsgPort      equ     $5c
SELECTDOWN      equ     $68
MENUDOWN        equ     $69
TD_CHANGESTATE  equ     14
IO_COMMAND      equ     28
IO_ACTUAL       equ     32
IO_LENGTH       equ     36
IO_DATA         equ     40

** gadget flags **

GADGHCOMP       equ     0
GADGHIMAGE      equ     2
GADGHNONE       equ     3
GADGIMAGE       equ     4
RELBOTTOM       equ     $0008
SELECTED        equ     $0080
GADGDISABLED    equ     $0100

RELVERIFY       equ     1
GADGIMMEDIATE   equ     2
TOGGLESELECT    equ     $0100

BOOLGADGET      equ     1
PROPGADGET      equ     3
STRGADGET       equ     4

AUTOKNOB        equ     1
FREEHORIZ       equ     2
FREEVERT        equ     4
PROPBORDERLESS  equ     8

** window refresh modes **

BORDERLESS      equ     $0800

** IDCMP Classes **

MOUSEBUTTONS    equ     $00000008
GADGETDOWN      equ     $00000020
GADGETUP        equ     $00000040
DISKINSERTED    equ     $00008000
DISKREMOVED     equ     $00010000
INTUITICKS      equ     $00400000

** window flags **

ACTIVATE        equ     $01000
RMBTRAP         equ     $10000

** exec library offsets **
        
VBlankFreq      equ     530
OpenLibrary     equ     -552
CloseLibrary    equ     -414
AllocMem        equ     -198    
FreeMem         equ     -210
GetMSG          equ     -372
ReplyMSG        equ     -378
WaitPort        equ     -384
AddTask         equ     -282
FindTask        equ     -294
AddPort         equ     -354
RemPort         equ     -360
OpenDevice      equ     -444
CloseDevice     equ     -450
DoIO            equ     -456
OpenResource    equ     -498

** intuition library offsets **

OpenScreen      equ     -198
OpenWindow      equ     -204
CloseScreen     equ     -66
CloseWindow     equ     -72
DrawBorder      equ     -108
PrintIText      equ     -216
AddGadget       equ     -42
RefreshGadgets  equ     -222
AutoRequest     equ     -348
OffGadget       equ     -174
OnGadget        equ     -186
ModifyProp      equ     -156
DoubleClick     equ     -102
CurrentTime     equ     -84
DisplayBeep     equ     -96
DrawImage       equ     -114
SetWindowTitles equ     -276
SetPointer      equ     -270
ClearPointer    equ     -60
ViewPortAddress equ     -300

** graphics library offsets **

LoadRGB4        equ     -192
SetRGB4         equ     -288
RectFill        equ     -306
SetAPen         equ     -342
ScrollRaster    equ     -396
AddFont         equ     -480
RemFont         equ     -486

** dos library offsets **

open            equ     -30
close           equ     -36
Execute         equ     -222
Read            equ     -42
Write           equ     -48
DeleteFile      equ     -72
Lock            equ     -84
UnLock          equ     -90
Examine         equ     -102
ExNext          equ     -108
Info            equ     -114
IOErr           equ     -132
SetProtection   equ     -186
Delay           equ     -198

** start of code **

                section ArcTool,code

startup         move.l  sp,InitialSP
                move.l  execbase,a6
                suba.l  a1,a1
                jsr     FindTask(a6)            find this tasks address
                move.l  d0,a4
                tst.l   pr_CLI(a4)              launched from CLI or workbench
                bne     fromCLI
                lea     pr_MsgPort(a4),a0
                jsr     WaitPort(a6)            wait for message from WB
                lea     pr_MsgPort(a4),a0       
                jsr     GetMSG(a6)              now get the message
                move.l  d0,WBmessage
                bsr     main
                move.l  WBmessage(pc),a1        reply message from WB
                jsr     ReplyMSG(a6)
                rts
                
fromCLI         
main            move.l  execbase,a6
                
; set up a reply port for communication with trackdisk device

                suba.l  a1,a1
                jsr     FindTask(a6)            this task
                move.l  d0,readreply+$10        sigtask = this task
                
                lea     readreply(pc),a1
                jsr     AddPort(a6)             add reply port

                lea     dos(pc),a1
                clr.l   d0
                jsr     OpenLibrary(a6)         open DOS library
                move.l  d0,dosbase
                beq     derror
                
                lea     intuition(pc),a1
                clr.l   d0
                jsr     OpenLibrary(a6)         open intuition library
                move.l  d0,intuitionbase
                beq     ierror
                
                lea     graphics(pc),a1
                clr.l   d0
                jsr     OpenLibrary(a6)         open graphics library
                move.l  d0,graphicsbase
                beq     gerror
                
                movea.l d0,a0
                cmpi.b  #60,VBlankFreq(a0)      test for NTSC
                bne.s   PAL
                st.b    NTSC
                bsr     PAL_to_NTSC             convert to NTSC
                
PAL             lea     ArcTool_font(pc),a1
                movea.l graphicsbase(pc),a6
                jsr     AddFont(a6)             add ram font to system

                move.l  intuitionbase,a6
                lea     NewScreen(pc),a0
                jsr     OpenScreen(a6)          open custom screen
                move.l  d0,screenptr
                move.l  d0,screenptr2
                ;move.l d0,screenptr3
                move.l  d0,screenptr4
                move.l  d0,screenptr5
                beq     serror

                move.l  screenptr(pc),a0
                adda.l  #ScreenViewPort,a0
                lea     ColorMap(pc),a1
                move.l  graphicsbase(pc),a6
                moveq   #8,d0
                jsr     LoadRGB4(a6)

                lea     ConfigWindow(pc),a0
                move.l  intuitionbase(pc),a6
                jsr     OpenWindow(a6)
                move.l  d0,windowptr
                beq     werror

                move.l  d0,a0
                move.l  WindowRastPort(a0),WRastPort
                
                moveq   #2,d0           X1
                moveq   #1,d1           Y1
                move.l  #397,d2         X2
                move.l  #58,d3          Y2
                move.b  #MD_GREY,d4     pen number
                movea.l WRastPort(pc),a1
                bsr     DrawRect

                clr.l   d0              X1
                clr.l   d1              Y1
                move.w  #399,d2         X2
                moveq   #59,d3          Y2
                move.b  #LT_GREY,d4     Pen1
                move.b  #DK_GREY,d5     Pen2
                                        ;a1 is unchanged
                bsr     DrawBord        Draw 3D Border
                                        ;a6 now is intuitionbase
                move.l  WRastPort(pc),a0
                movea.l #Disk,a1
                moveq   #12,d0
                moveq   #5,d1
                jsr     DrawImage(a6)           draw disk image

                move.l  WRastPort(pc),a0
                lea     ConfigItext(pc),a1
                clr.l   d0
                clr.l   d1
                jsr     PrintIText(a6)

                movea.l windowptr(pc),a0
                bsr     SleepPointer            set new mouse pointer

                bsr     GetConfig               read in config file
                ;return outcome in d7

                move.l  intuitionbase(pc),a6    close config window
                move.l  windowptr(pc),a0
                jsr     CloseWindow(a6)         

                tst.l   d7
                bne     werror

                move.l  intuitionbase,a6
                lea     NewWindow(pc),a0
                jsr     OpenWindow(a6)          open new window
                move.l  d0,windowptr
                beq     werror

                move.l  d0,a0                   windowptr
                move.l  WindowRastPort(a0),WRastPort
                
                movea.l windowptr(pc),a0
                bsr     NormalPointer           set new mouse pointer

                movea.l WRastPort(pc),a1
                lea     PAL_rectangles(pc),a2
                bsr     DrawRects
                                        ;a1 is unchanged
                lea     PAL_borders(pc),a2
                bsr     DrawBords

                movea.l WRastPort(pc),a0
                lea     Intuitext1(pc),a1
                clr.l   d0
                clr.l   d1
                jsr     PrintIText(a6)

                bsr     AddGadgets
                lea     ToolCyclegad(pc),a0
                bsr     Refresh_Gadgets
                bsr     ResetNameText

                lea     ArcRequester(pc),a5
                bsr     Dir
                lea     FileRequester(pc),a5
                bsr     Dir

waitloop        move.l  windowptr(pc),a0
                move.l  WindowUserPort(a0),a0
                bsr     WaitForMSG              wait for a system message

                cmpi.l  #GADGETDOWN,d1          custom gadget selected?
                bne.s   1$
                bsr     gadgethit
                bra     waitloop

1$              cmpi.l  #GADGETUP,d1            custom gadget released?
                bne.s   2$
                bsr     gadgethit
                bra     waitloop

2$              cmpi.l  #MOUSEBUTTONS,d1
                bne.s   3$
                bsr     mouseclick
                bra     waitloop

3$              cmpi.l  #DISKINSERTED,d1        new disk inserted?
                bne.s   4$
                bsr     diskinsert
                bra     waitloop

4$              cmpi.l  #DISKREMOVED,d1         old disk removed?
                bne.s   5$
                bsr     diskremove
                bra     waitloop

5$              cmpi.l  #INTUITICKS,d1
                bne.s   6$
                btst.b  #7,13+Helpgad(pc)       check if in help mode
                bne.s   6$
                bsr     ScrollUpArc             check for Arc UpArrow
                bsr     ScrollDnArc             check for Arc DnArrow
                bsr     ScrollUpFile            check for File UpArrow
                bsr     ScrollDnFile            check for File DnArrow

6$              movea.l message(pc),a1
                movea.l execbase,a6
                jsr     ReplyMSG(a6)            reply unwanted message
                bra     waitloop
                
gadgethit       move.l  IAddress(a1),a0         handle a gadget hit
                clr.l   d2
                move.w  GadgetID(a0),d2
                jsr     ReplyMSG(a6)
                asl.l   #2,d2                   d2 * 4
                lea     JumpTable(pc),a0
                btst.b  #7,13+Helpgad(pc)       check SELECTED of flags+1
                beq.s   1$
                lea     HelpTable(pc),a0
1$              move.l  0(a0,d2.l),a0           get address of subroutine
                jsr     (a0)                    call the subroutine
NIL             rts
                
JumpTable       dc.l    NameCycle,ModeCycle,Terminate
                dc.l    About,Help,NIL; change NIL to Archive
                dc.l    NewArcPath,NewFnamePath
                dc.l    Prop1Loop,Prop2Loop,NewArcName
                dc.l    DoArcPath,ArcParent             change path->makedir
                dc.l    ArcDelete,NIL                           arc copy/delete
                dc.l    DoFilesPath,FilesParent
                dc.l    NIL,NIL                         file copy/delete
                dc.l    NIL,NIL Arc Req up/dn arrows -- done with INTUITICKS
                dc.l    NIL,NIL FileReq up/dn arrows -- done with INTUITICKS
                
HelpTable       dc.l    ToolCycle_Help,OptionCycle_Hlp,Exit_Help
                dc.l    Help_on_About,Help,Archive_Help
                dc.l    ArcPathStr_Help,FilePathStr_Hlp
                dc.l    Prop1_Help,Prop2_Help,ArcNameStr_Help
                dc.l    ArcMakeDir_Help,ArcParent_Help
                dc.l    ArcDelete_Help,ArcCopy_Help
                dc.l    FileMakeDir_Hlp,FileParent_Help
                dc.l    FileDelete_Help,FileCopy_Help
                dc.l    NIL,NIL
                dc.l    NIL,NIL

************************* Help routines *************************

ToolCycle_Help  lea     ToolCycleHelp(pc),a2
                bra.s   show_help
OptionCycle_Hlp lea     OptionCycleHelp(pc),a2
                bra.s   show_help
ArcReq_Help     lea     ArcReqHelp(pc),a2
                bra.s   show_help
FileReq_Help    lea     FileReqHelp(pc),a2
                bra.s   show_help
ArcCopy_Help    lea     ArcCopyHelp(pc),a2
                bra.s   show_help
ArcDelete_Help  lea     ArcDeleteHelp(pc),a2
                bra.s   show_help
ArcMakeDir_Help lea     ArcMakeDirHelp(pc),a2
                bra.s   show_help
ArcParent_Help  lea     ArcParentHelp(pc),a2
                bra.s   show_help
FileCopy_Help   lea     FileCopyHelp(pc),a2
                bra.s   show_help
FileDelete_Help lea     FileDeleteHelp(pc),a2
                bra.s   show_help
FileMakeDir_Hlp lea     FileMakeDirHelp(pc),a2
                bra.s   show_help
FileParent_Help lea     FileParentHelp(pc),a2
                bra.s   show_help
Archive_Help    lea     ArchiveHelp(pc),a2      help on archiving tool
                bra.s   show_help
Help_on_About   lea     HelpAbout(pc),a2        display help on about
                bra.s   show_help
About           lea     AboutArcTool(pc),a2
                bra.s   show_help
Exit_Help       lea     ExitHelp(pc),a2         help on exit gadget
show_help       clr.w   d0                      OK-type gadget
                bsr     ProgRequest
                rts

Terminate       move.l  InitialSP(pc),sp        remove return addresses
                bra     Exit

NewArcPath      lea     ArcPathStrgad(pc),a0
                btst.b  #7,13(a0)               gadget still stelected?
                bne.s   NoGo                    skip if GADGIMMEDIATE event
                ;clr.b  File                    remove archive filename
                lea     ArcRequester(pc),a5
DoReqPath       ;lea    FileGadget(pc),a0
                ;bsr    Refresh_Gadgets
                bsr     Dir
NoGo            rts

ArcPathStr_Help lea     ArcPathStrgad(pc),a0
                btst.b  #7,13(a0)               gadget still selected?
                beq.s   1$                      if not, ignore
                
                lea     ArcPath(pc),a0
                lea     CopyBuffer(pc),a1
                move.w  #255-1,d0
                bsr     copydat                 copy str gadget contents

                lea     ArcPathStrHelp(pc),a2
                clr.w   d0                      OKAY only requester
                bsr     ProgRequest             display help topic

                lea     CopyBuffer(pc),a0
                lea     ArcPath(pc),a1
                move.w  #255-1,d0
                bsr     copydat                 restore str gadet contents

                lea     ArcPathStrgad(pc),a0
                bsr     Refresh_Gadgets
1$              rts

NewFnamePath    lea     FileRequester(pc),a5
                lea     FilesPathStrgad(pc),a0
                btst.b  #7,13(a0)
                beq.s   DoReqPath
                rts

FilePathStr_Hlp lea     FilesPathStrgad(pc),a0
                btst.b  #7,13(a0)               gadget still selected?
                beq.s   1$                      if not, ignore

                lea     FilePath(pc),a0
                lea     CopyBuffer(pc),a1
                move.w  #255-1,d0
                bsr     copydat                 copy str gadget contents

                lea     FilePathStrHelp(pc),a2
                clr.w   d0                      OKAY only requester
                bsr     ProgRequest             display help topic

                lea     CopyBuffer(pc),a0
                lea     FilePath(pc),a1
                move.w  #255-1,d0
                bsr     copydat                 restore str gadet contents

                lea     FilesPathStrgad(pc),a0
                bsr     Refresh_Gadgets
1$              rts

;up arrow gadget

ScrollUpArc     btst.b  #7,13+ArcArrowUpgad(pc)         selected?
                beq.s   1$
                lea     ArcRequester(pc),a5
                bsr     CalcPotPos
                tst.w   d2
                beq.s   1$
                bsr     ScrollReqUp
1$              rts

ScrollUpFile    btst.b  #7,13+FileArrowUpgad(pc)        selected?
                beq.s   1$
                lea     FileRequester(pc),a5
                bsr     CalcPotPos
                tst.w   d2
                beq.s   1$
                bsr     ScrollReqUp
1$              rts

;down arrow gadget

ScrollDnArc     btst.b  #7,13+ArcArrowDngad(pc)         selected?
                beq.s   1$
                lea     ArcRequester(pc),a5
                bsr     CalcPotPos
                add.w   ReqSize(pc),d2
                cmp.w   (a5),d2                         d2 = #entries?
                bge.s   1$
                bsr     ScrollReqDn
1$              rts

ScrollDnFile    btst.b  #7,13+FileArrowDngad(pc)        selected?
                beq.s   1$
                lea     FileRequester(pc),a5
                bsr     CalcPotPos
                add.w   ReqSize(pc),d2
                cmp.w   (a5),d2
                bge.s   1$
                bsr     ScrollReqDn
1$              rts

Prop1Loop       lea     ArcRequester(pc),a5
                bra.s   PropLoop
Prop2Loop       lea     FileRequester(pc),a5

PropLoop        move.l  6(a5),a1                prop gadget ptr
                move.l  34(a1),a0               prop info ptr

                move.w  4(a0),14(a5)            old Ypot
                bsr     ListFnames

CheckProp1      btst.b  #7,13(a1)
                bne.s   1$
                rts

1$              move.w  4(a0),d0
                cmp.w   14(a5),d0               ypot changed?
                beq.s   CheckProp1
                bra.s   PropLoop

Prop1_Help      lea     Prop1Help(pc),a2
                clr.w   d0                      OKAY only requester
                bsr     ProgRequest             display arc req prop help
                lea     Prop1Gadget(pc),a0
                lea     PropInfo1(pc),a1
                move.w  (a1),d0                 get old flags
                move.w  2(a1),d1                get old horizpot
                move.w  OldArcYPot(pc),d2       get old vertpot off
                move.w  6(a1),d3                get old horizbody
                move.w  8(a1),d4                get old vertbody
                movea.l windowptr(pc),a1        ptr to window
                suba.l  a2,a2                   requester = NULL
                movea.l intuitionbase(pc),a6
                jsr     ModifyProp(a6)          reposition prop gadget
                rts

Prop2_Help      lea     Prop2Help(pc),a2
                clr.w   d0                      OKAY only requester
                bsr     ProgRequest             display files req prop help
                lea     Prop2Gadget(pc),a0
                lea     PropInfo2(pc),a1
                move.w  (a1),d0                 get old flags
                move.w  2(a1),d1                get old horizpot
                move.w  OldFileYPot(pc),d2      get old vertpot off
                move.w  6(a1),d3                get old horizbody
                move.w  8(a1),d4                get old vertbody
                movea.l windowptr(pc),a1        ptr to window
                suba.l  a2,a2                   requester = NULL
                movea.l intuitionbase(pc),a6
                jsr     ModifyProp(a6)          reposition prop gadget
                rts

;left requester box?

LeftReq         lea     ArcRequester(pc),a5
                bsr.s   Requester
                rts

;right requester box?

RightReq        lea     FileRequester(pc),a5
                bsr.s   Requester
                rts

*****************************************************************
*                                                               *
* Requester - Requester management routine.                     *
*                                                               *
* INPUTS: a5 = ptr to requester structure                       *
*                                                               *
*****************************************************************

Requester       move.l  6(a5),a0                prop gadget ptr
                move.w  (a5),d0                 #entries
                lea     2(a5),a2                list base

                move.l  windowptr(pc),a1
                move.w  12(a1),d7               mouse Ypos in window
                sub.w   #REQ_TOP,d7             offset into window
                ext.l   d7                      sign extend d0 to longword
                divu    #10,d7

                bsr     CalcPotPos
                move.w  d2,d0                   d0  = top entry on display
                add.w   d7,d0                   now = entry within display
                bsr     GotoEntry               locate entry
                tst.l   112(a2)                 entry type
                bpl.s   GoChdir                 a directory?
                bchg.b  #0,116(a2)              toggle select status    
ShowHigh        bsr     ListFnames
                rts

GoChdir         tst.b   20(a5)                  check for a path
                bne.s   1$
                bchg.b  #0,116(a2)
                bsr     ListFnames
                bsr     Chdir
                rts

1$              movea.l intuitionbase(pc),a6
                bchg.b  #0,116(a2)
                bne.s   CheckDouble
GetTime         lea     Seconds(pc),a0
                lea     Micros(pc),a1
                jsr     CurrentTime(a6)
                move.l  a5,OldReqAddr           save requester number
                move.w  d7,OldFileNo            save file number
                bra.s   ShowHigh

CheckDouble     cmp.w   OldFileNo(pc),d7        same file?
                bne.s   GetTime
                cmp.l   OldReqAddr(pc),a5       same requester?
                bne.s   GetTime
                move.l  Seconds(pc),d2
                move.l  Micros(pc),d3
                lea     Seconds(pc),a0
                lea     Micros(pc),a1
                jsr     CurrentTime(a6)
                move.l  Seconds(pc),d0
                move.l  Micros(pc),d1
                exg.l   d0,d2
                exg.l   d1,d3
                jsr     DoubleClick(a6)
                tst.b   d0
                beq.s   ShowHigh
                bsr     Chdir
                rts

*****************************************************************
*                                                               *
* GotoEntry - Locates file node in a given requester            *
*                                                               *
* INPUTS: a5 = ptr to requester structure                       *
*         d0 = entry number to locate (0 = top)                 *
* OUTPUT: a2 = ptr to filenode of entry                         *
*                                                               *
*****************************************************************

GotoEntry       lea     2(a5),a2        listbase address
1$              movea.l (a2),a2         advance to next entry
                dbf     d0,1$           repeat until node reached
                rts

ArcNameStr_Help lea     FileGadget(pc),a0
                btst.b  #7,13(a0)               gadget still selected?
                beq.s   1$                      if not, ignore
                
                lea     File(pc),a0
                lea     CopyBuffer(pc),a1
                moveq   #32,d0
                bsr     copydat                 copy str gadget contents

                lea     ArcNameStrHelp(pc),a2
                clr.w   d0                      OKAY only requester
                bsr     ProgRequest             display help topic

                lea     CopyBuffer(pc),a0
                lea     File(pc),a1
                moveq   #32,d0
                bsr     copydat                 restore str gadet contents

                lea     FileGadget(pc),a0
                bsr     Refresh_Gadgets
1$              rts

;archive name put in string gadget

NewArcName      lea     FileGadget(pc),a0
                btst.b  #7,13(a0)               check if still selected
                beq.s   1$
                tst.b   ArcPath                 check if arc path chosen
                bne.s   2$

                lea     ArcNameError(pc),a2
                clr.w   d0                      OKAY only requester
                bsr     ProgRequest             display error if no arc path
2$              rts

1$              tst.b   ArcPath
                bne.s   3$
                clr.b   File
                bra.s   end_of_dehigh2

3$              lea     ArcBase(pc),a2
dehighlight     tst.l   (a2)
                beq     dehigh2
                move.l  (a2),a3
                lea     File(pc),a0
                lea     4(a3),a1
                bsr     comparenames
                beq.s   IsFile
                move.l  a3,a2
                bra     dehighlight

IsFile          clr.b   File
                bset    #0,116(a3)              set select

dehigh2         tst.b   ArcPath                 check for source path
                bne.s   1$
                clr.b   File
1$              tst.w   ArcDiskIn               check for disk inserted
                bne.s   2$
                clr.b   File

2$              lea     ArcRequester(pc),a5
                bsr     ListFnames
end_of_dehigh2  lea     FileGadget(pc),a0
                bsr     Refresh_Gadgets
                rts

;path gadget for archive

DoArcPath       tst.b   ArcPath
                beq     1$
                clr.b   ArcPath
                clr.b   File
                lea     ArcRequester(pc),a5
                bsr     Dir
1$              rts

;archive parent gadget

ArcParent       lea     ArcRequester(pc),a5
                bsr     ParentDir
                rts
                
;path gadget for filename

DoFilesPath     tst.b   FilePath
                beq     1$
                clr.b   FilePath
                lea     FileRequester(pc),a5
                bsr     Dir
1$              rts

;files parent gadget

FilesParent     lea     FileRequester(pc),a5
                bsr     ParentDir
1$              rts

mouseclick      move.w  Code(a1),d2
                jsr     ReplyMSG(a6)

1$              cmpi.w  #MENUDOWN,d2
                bne.s   leftbutton

rightbutton     bsr.s   CheckReqs
                beq.s   1$
                bmi.s   2$
                
                btst.b  #7,13+Helpgad(pc)       check SELECTED of flags+1
                bne     ArcReq_Help
                bsr     DoArcPath
                rts

2$              btst.b  #7,13+Helpgad(pc)       check SELECTED of flags+1
                bne     FileReq_Help
                bsr     DoFilesPath
1$              rts

leftbutton      cmpi.w  #SELECTDOWN,d2
                bne.s   1$
                bsr.s   CheckReqs
                beq.s   1$
                bmi.s   2$

                btst.b  #7,13+Helpgad(pc)
                bne     ArcReq_Help
                bsr     LeftReq
                rts

2$              btst.b  #7,13+Helpgad(pc)
                bne     FileReq_Help
                bsr     RightReq
1$              rts

*****************************************************************
*                                                               *
* CheckReqs - Checks to see if mousepointer is within requesters*
*                                                               *
* INPUTS: None.                                                 *
* OUTPUT: d0 = 0 if mouse in neither requester.                 *
*              1 if mouse in archive requester.                 *
*             -1 if mouse in filename requester.                *
*         ZF reflects value in d0 on exit.                      *
*                                                               *
*****************************************************************

CheckReqs       movea.l windowptr(pc),a0
                move.w  12(a0),d0               get mouseY pos
                cmpi.w  #REQ_TOP+2,d0           mouse above requesters?
                blt.s   1$
                move.w  Req_Bottom(pc),d1
                subq.w  #1,d1
                cmp.w   d1,d0                   mouse below requesters?
                bge.s   1$
                move.w  14(a0),d0               get mouseX pos
                cmpi.w  #ARC_REQ_LEFT,d0        mouse left of arc requester?
                blt.s   1$
                cmpi.w  #ARC_REQ_RIGHT,d0       mouse right of arc requester?
                bgt.s   2$
                moveq   #1,d0                   mouse in arc-requester
                rts
2$              cmpi.w  #FILE_REQ_LEFT,d0       mouse left of file requester?
                blt.s   1$
                cmpi.w  #FILE_REQ_RIGHT,d0      mouse right of file req?
                bgt.s   1$
                moveq   #-1,d0                  mouse in file req
                rts
1$              clr.l   d0                      mouse not in either req
                rts

diskremove      jsr     ReplyMSG(a6)
                lea     ArcRequester(pc),a5
                bsr     DiskCheck
                lea     FileRequester(pc),a5
                bsr     DiskCheck
                rts
                
DiskCheck       tst.b   20(a5)                  check for path
                bne.s   1$
                bsr     Dir                     refresh volume list
                rts

1$              tst.w   10(a5)                  check diskin flag
                beq     DiskOK
                move.l  16(a5),d0               unit no.
                bsr     TestUnit
                bmi     DiskOK
                beq     DiskOK
                clr.w   10(a5)                  clear diskin flag

                cmpa.l  #ArcRequester,a5        check for arcrequester
                bne.s   2$
                clr.b   File                    remove archive filename
                
2$              move.l  16(a5),d0               unit no.
                bsr     GetUnitName
                clr.b   20(a5)                  clear path
                cmpa.l  #0,a0
                beq.s   Noname
                clr.w   d0
                move.b  (a0)+,d0                get length
                subq    #1,d0
                lea     20(a5),a1               path
3$              move.b  (a0)+,(a1)+             copy name
                dbf     d0,3$
                move.b  #':',(a1)+              put ':',0
                clr.b   (a1)
                
Noname          lea     ArcPathStrgad(pc),a0
                bsr     Refresh_Gadgets

                bsr     ClearList
                bsr     ClearRequester

                move.l  intuitionbase(pc),a6
                move.l  WRastPort(pc),a0
                movea.l #Disk,a1
                move.w  12(a5),d0               xpos for disk
                addi.w  #89,d0                  pos for centre
                move.w  DiskYPos(pc),d1
                jsr     DrawImage(a6)
                
                move.l  WRastPort(pc),a0
                lea     DiskText(pc),a1
                move.w  12(a5),d0               xpos for disk
                addi.w  #70,d0                  pos for centre
                move.w  DiskYPos(pc),d1
                addi.w  #39,d1
                jsr     PrintIText(a6)
                
DiskOK          rts

diskinsert      jsr     ReplyMSG(a6)
                lea     ArcRequester(pc),a5
                bsr.s   CheckDiskInsert
                lea     FileRequester(pc),a5
                bsr.s   CheckDiskInsert
                rts

CheckDiskInsert tst.b   20(a5)          check path
                beq     1$

                tst.w   10(a5)          was there an arc disk inserted?
                bne.s   InsertOK
                move.l  16(a5),d0       unit no.
                bsr     TestUnit
                bne.s   InsertOK
                move.w  #$ffff,10(a5)   set diskin flag
1$              bsr     Dir

InsertOK        rts

*** delete function for archive directory ***

                IFND REGISTERED_USER    ;check for registration

ArcDelete       rts

                ENDC    ;arcdelete

                IFD     REGISTERED_USER ;check for registration

ArcDelete       tst.b   ArcPath
                bne.s   1$
                lea     NoDelPath(pc),a2
                clr.l   d0
                bsr     ProgRequest
                rts
1$              lea     ArcRequester(pc),a5
                bsr.s   Delete
                rts

                ENDC    ;arcdelete

*****************************************************************
*                                                               *
* Delete - Deletes selected file/dirs                           *
*                                                               *
* INPUTS: a5 = pointer to requester                             *
*                                                               *
*****************************************************************

                IFD     REGISTERED_USER ;check for registration

Delete          clr.b   CopyBuffer      clear name for 1st redraw
                lea     20(a5),a0       path ptr
                lea     SourcePath(pc),a1
                bsr     copyname
                clr.b   (a1)            add null terminator

                lea     2(a5),a2        list base
                clr.b   d7              fname flag
DelLoop         tst.l   (a2)
                beq.s   DelEnd
                move.l  (a2),a3
                btst    #0,116(a3)      select flag on?
                beq.s   NextNode

                movem.l a2-a3,-(a7)
                lea     4(a3),a0        ptr to fname
                lea     SourcePath(pc),a1
                bsr     AddPathDir      add filename to path
                bsr.s   Delete_File
                movem.l (a7)+,a2-a3
                st.b    d7              set fname flag

                tst.l   d0
                beq.s   1$
                bmi.s   DelEnd          error occurred
                cmpi.l  #1,d0           user aborted?
                beq.s   End_Del
                bclr.b  #0,116(a3)      (d0 = 2) file not removed
                bra.s   2$

        ;else, remove node from linked list:

1$              move.l  (a3),(a2)
                
                movea.l a3,a1
                moveq.l #NodeSize,d1
                move.l  execbase,a6
                jsr     FreeMem(a6)
                subq.w  #1,(a5)         #entries = #entries-1
                movea.l a2,a3
2$              movem.l a2-a3/d7,-(a7)
                bsr     ListFnames
                movem.l (a7)+,a2-a3/d7

                lea     SourcePath(pc),a0
                bsr     RemPathDir      remove filename from path
NextNode        move.l  a3,a2
                bra.s   DelLoop

DelEnd          tst.b   d7              check that any files were selected
                bne.s   1$              yes, then skip following code
                clr.l   d0
                lea     NoDelNames(pc),a2
                bsr     ProgRequest     display error screen
                rts

1$              bsr     EndRequest
End_Del         bsr     ModProp
                rts

*****************************************************************
*                                                               *
* Delete_File - Removes a file/directory                        *
*                                                               *
* OUTPUT: d0 = 0 if deleted OK                                  *
*              1 if user aborted                                *
*              2 if file not deleted                            *
*             -1 if error occurred                              *
*                                                               *
*****************************************************************

Delete_File     tst.b   d7              requester opened yet?
                bne.s   DeleteIt

                lea     DeleteScreen(pc),a2
                move.w  #$8001,d0       immediate return/cancel only request
                bsr     ProgRequest

DeleteIt        lea     CopyBuffer(pc),a0
                lea     SourcePath(pc),a1
                moveq.w #30,d1
                bsr     DisplayName

                bsr     WaitForResponse
                tst.w   d0
                beq     User_Abort      user selected cancel
                
                move.l  #SourcePath,d1
                movea.l dosbase(pc),a6
                jsr     DeleteFile(a6)  attempt to delete file/dir
                tst.l   d0
                beq.s   1$
                clr.l   d0
                rts                     delete = ok
1$              jsr     IOErr(a6)       get DOS status
                cmpi.l  #222,d0         file protected from deletion?
                bne.s   2$
                bsr     DOS_Error
                bra     FileNotDeleted

2$              cmpi.l  #216,d0         directory not empty?
                bne     Delete_Error    no, exit with error
DeleteDir       bsr     Dir_Query       check if user wants dir cleared
                tst.l   d0              user selected cancel?
                beq     FileNotDeleted  yep

                clr.b   DeletePath      signal no previous path yet
                bsr     FindFirst       lock the dir
                movem.l d1-d2,-(a7)     save d1/d2
                beq.s   DeleteDir_2     OK?
                movem.l (a7)+,d1-d2     get regs back off stack
                bsr     DOS_Error       no!
                rts

DeleteDir_2     bsr     WaitForResponse         check for user abort
                tst.w   d0
                beq     DirUser_Abort           user selected abort

1$              movem.l (a7)+,d1-d2
                bsr     FindNext
                movem.l d1-d2,-(a7)
                tst.b   DirEntered              flag set by FindNext
                bne.s   1$                      skip 1st occurrence of dir

                move.l  d0,-(a7)
                lea     CopyBuffer(pc),a0
                lea     DeletePath(pc),a1
                moveq.w #30,d1
                bsr     DisplayName
                move.l  (a7)+,d3                save value from FindNext

Delete_Dir      tst.b   DeletePath
                beq.s   DeleteDir_3

                move.l  #DeletePath,d1          ptr to name
                movea.l dosbase(pc),a6
                jsr     DeleteFile(a6)          attempt to delete file
                tst.l   d0
                bne.s   DeleteDir_3             delete = ok

                jsr     IOErr(a6)               get DOS status
                cmpi.l  #222,d0                 protected?
                bne.s   CheckDirError2
                st.b    NotDeleted              signal that file still in dir
                bsr     DOS_Error

DeleteDir_3     lea     SourcePath(pc),a0
                lea     DeletePath(pc),a1
                move.w  #255-1,d0
                bsr     copydat                 copy to previous path buffer

                tst.l   d3                      check if end of entries
                beq.s   DeleteDir_2             end not reached
                bpl.s   DirDeleteError2         an error occurred

                lea     8(a7),a7                remove d1,d2 off stack as
                                                ;they don't contain values
                tst.b   NotDeleted              were files left in dir?
                bne.s   FileNotDeleted

                move.l  #SourcePath,d1          ptr to name
                movea.l dosbase(pc),a6
                jsr     DeleteFile(a6)          now finally, remove the dir!!
                tst.l   d0
                bne.s   1$                      delete = ok?
                bsr     DOS_Error
                rts
1$              clr.l   d0                      delete okay
                rts             

CheckDirError2  cmpi.l  #216,d0                 dir_not_empty?
                bne.s   DirDeleteError2
                tst.l   d3                      end of entries?
                bmi.s   DirNotDeleted
                beq     DeleteDir_2             ignore dir_not_empty
DirDeleteError2 bsr     DOS_Error
                bsr     CleanupStack            remove params off stack
                moveq   #-1,d0
                rts

;DirDelete_Error        bsr     CleanupStack
Delete_Error    moveq   #-1,d0
                rts

DirNotDeleted   lea     8(a7),a7
FileNotDeleted  moveq   #2,d0                   signal file not deleted
                rts

DirUser_Abort   bsr     CleanupStack
User_Abort      moveq   #1,d0
                rts

*****************************************************************
*                                                               *
* DisplayName - Displays centred path:filename in requester     *
*                                                               *
* INPUTS: a0 = Ptr to copy buffer                               *
*         a1 = Ptr to path string                               *
*         d1 = Ypos of string                                   *
*                                                               *
*****************************************************************

DisplayName     movem.l a0-a1/d1,-(a7)

                movea.l Stdwindptr(pc),a1
                moveq   #MD_BLUE,d2
                bsr     Centre          redraw path:filename to remove

                moveq   #77,d0
                movem.l (a7),a0-a1/d1
                exg.l   a0,a1
                bsr     copydat
                clr.b   (a1)

                movem.l (a7)+,a0-a1/d1
                movea.l a1,a0

ReDisplayName   movea.l Stdwindptr(pc),a1
                moveq   #LT_BLUE,d2
                bsr     Centre          display path:filename
                rts

*****************************************************************
*                                                               *
* Dir_Query - deprotects a file/dir                             *
*                                                               *
* OUTPUT: d0 = 0 if user selected cancel                        *
*              1 if protection removal successful               *
*                                                               *
*****************************************************************

Dir_Query       bsr     EndRequest
                move.w  #$8002,d0               ok/cancel requester
                lea     DirQuery(pc),a2         ptr to text
                bsr     ProgRequest             setup window
                lea     CopyBuffer(pc),a0
                moveq.w #30,d1
                bsr     ReDisplayName           display path:file
                bclr.b  #7,ReqMode
                bsr     WaitForResponse
                move.l  d0,-(a7)
                lea     DeleteScreen(pc),a2
                move.w  #$8001,d0       immediate return/cancel only request
                bsr     ProgRequest             put back old requester
                lea     CopyBuffer(pc),a0
                moveq.w #30,d1
                bsr     ReDisplayName
                move.l  (a7)+,d0
                rts

*****************************************************************
*                                                               *
* FindFirst - Locks a directory and examines the lock           *
*                                                               *
* INPUTS: None.                                                 *
* OUTPUT: d0 = DOS error status (0 if OK)                       *
*         d1 = pointer to directory lock                        *
*         d2 = pointer to fileinfo block                        *
*                                                               *
* NOTE> This version DOES NOT yet check for allocation errors!  *
*                                                               *
*****************************************************************

FindFirst       st.b    DirEntered
                clr.b   NotDeleted
                clr.w   DirLevel
                moveq.l #0,d2
                move.l  #260,d0
                moveq.l #MEMF_PUBLIC,d1
                movea.l execbase,a6
                jsr     AllocMem(a6)    allocate filinfo block

;               tst.l   d0
;               beq.s   FindError3

                move.l  d0,-(a7)
                move.l  #SourcePath,d1  ptr to path name
                moveq.l #-1,d2          exclusive (write access) lock
                movea.l dosbase(pc),a6
                jsr     Lock(a6)        lock the dir
                move.l  (a7)+,d2
                tst.l   d0
                beq.s   FindError2
                move.l  d0,-(a7)        save the lock
                move.l  d0,d1
                jsr     Examine(a6)     read in file info
                move.l  (a7)+,d1
                tst.l   d0
                beq.s   FindError1
                moveq.l #0,d0
                rts

FindError1      jsr     UnLock(a6)      remove lock
FindError2      move.l  d2,a1
                move.l  #260,d0
                movea.l execbase,a6
                jsr     FreeMem(a6)     deallocate fileinfo block
                movea.l dosbase(pc),a6
                jsr     IOErr(a6)       get DOS error state into d0
FindError0      rts
;FindError3     moveq.l #10,d0          signal allocation error
;FindError0     rts

*****************************************************************
*                                                               *
* FindNext - Finds next entry in currently locked directory     *
*                                                               *
* INPUTS: d1 = lock to dir                                      *
*         d2 = ptr to fileinfo block                            *
* OUTPUT: d0 = DOS status OR -1 if end of dir was reached       *
*         d1 = new lock to dir                                  *
*         d2 = ptr to new fileinfo block                        *
*                                                               *
*****************************************************************

FindNext        tst.b   DirEntered      was a directory just entered
                bne.s   1$
                lea     SourcePath(pc),a0
                bsr     RemPathDir      remove old filename

1$              clr.b   DirEntered
                move.l  d1,-(a7)
                movea.l dosbase(pc),a6
                jsr     ExNext(a6)      examine next entry
                move.l  (a7)+,d1
                tst.l   d0
                beq.s   FileError

                movea.l d2,a0
                lea     8(a0),a0        ptr to fname
                lea     SourcePath(pc),a1
                bsr     AddPathDir

                movea.l d2,a0           a0 = fileinfo block
                tst.l   4(a0)           entry type (+=dir, -=file)
                bmi     NextFile

NextDir         movea.l (a7),a0         get return address
                move.l  d1,(a7)         save lock on stack
                move.l  d2,-(a7)        save fileinfo address
                move.l  a0,-(a7)        replace return address
                addq.w  #1,DirLevel     increment dir nest level
                bsr     FindFirst       enter directory
                rts

NextFile        clr.l   d0              no errors
ExitFile        rts

FileError       move.l  d1,-(a7)
                jsr     IOErr(a6)       get DOS status
                move.l  (a7)+,d1
                cmpi.l  #232,d0         NO_MORE_FILES?
                bne.s   ExitFile        yes, then go to parent

                movea.l dosbase(pc),a6
                jsr     UnLock(a6)      remove old lock

                movea.l execbase,a6
                movea.l d2,a1           old fileinfo block
                move.l  #260,d0         block length
                jsr     FreeMem(a6)     free fileinfo block

                subq.w  #1,DirLevel     decrement dir nesting level
                bmi.s   no_more_dirs

                move.l  (a7)+,a0        get return address
                move.l  (a7)+,d2        get old fileinfo block
                move.l  (a7),d1         get old lock
                move.l  a0,(a7)         replace return address
                clr.l   d0
                rts

no_more_dirs    moveq   #-1,d0
                rts

CleanupStack    ;tst.w  DirLevel        no dirs locked?
                ;beq.s  3$
                movea.l (a7)+,a2        get return address
1$              movea.l dosbase(pc),a6
                move.l  (a7)+,d1        old lock
                jsr     UnLock(a6)      remove old lock
                movea.l execbase,a6
                movea.l (a7)+,a1        old memblock
                move.l  #260,d0         block length
                jsr     FreeMem(a6)     free fileinfo block
                subq.w  #1,DirLevel
                bpl.s   1$
2$              move.l  a2,-(a7)        replace return address
3$              rts

                ENDC    ;delete

*****************************************************************
*                                                               *
* Program cleanup code                                          *
*                                                               *
*****************************************************************

Exit            move.l  intuitionbase(pc),a6
                move.l  windowptr(pc),a0
                jsr     CloseWindow(a6)

                bsr     ClearArcList

werror          move.l  screenptr(pc),a0
                move.l  intuitionbase(pc),a6
                jsr     CloseScreen(a6)

                lea     ArcTool_font(pc),a1
                movea.l graphicsbase(pc),a6
                jsr     RemFont(a6)             remove font from system

serror          move.l  graphicsbase(pc),a1
                move.l  4,a6
                move.l  execbase,a6
                jsr     CloseLibrary(a6)

gerror          move.l  intuitionbase(pc),a1
                jsr     CloseLibrary(a6)

ierror          move.l  dosbase(pc),a1
                jsr     CloseLibrary(a6)

derror          lea     ArcRequester(pc),a5
                bsr     ClearList       remove source linked-list
                lea     FileRequester(pc),a5
                bsr     ClearList       remove destination linked-list

                move.l  execbase,a6
                lea     readreply(pc),a1
                jsr     RemPort(a6)     remove reply port

                clr.l   d0
                rts

*****************************************************************
*                                                               *
* SleepPointer - Activates hourglass pointer                    *
*                                                               *
* INPUTS: a0 = window pointer.                                  *
*                                                               *
*****************************************************************

SleepPointer    movea.l #Sleep_Pointer,a2
                bsr.s   MakePointer
                rts

*****************************************************************
*                                                               *
* NormalPointer - Activates standard/help pointer               *
*                                                               *
* INPUTS: a0 = window pointer                                   *
*                                                               *
*****************************************************************

NormalPointer   movea.l #GeneralPointer,a2      default pointer
                btst.b  #7,13+Helpgad(pc)       check SELECTED of flags+1
                beq.s   1$
                movea.l #HelpPointer,a2         set help pointer
1$              bsr.s   MakePointer
                rts

*****************************************************************
*                                                               *
* MakePointer - Sets up a new mouse pointer definition          *
*                                                               *
* INPUTS: a0 = window pointer                                   *
*         a2 = address of pointer definition data               *
*                                                               *
*****************************************************************

MakePointer     movea.l intuitionbase(pc),a6
                movea.l a0,a3                   save windowptr
                jsr     ViewPortAddress(a6)     find screen viewport
                movea.l d0,a4                   save viewportaddress
                movea.l graphicsbase(pc),a6
                moveq   #17,d4
1$              move.w  (a2),d1
                andi.w  #$0f00,d1
                lsr.w   #8,d1                   RED component
                move.w  (a2),d2
                andi.w  #$00f0,d2
                lsr.w   #4,d2                   BLUE component
                move.w  (a2)+,d3
                andi.w  #$000f,d3               GREEN component
                move.w  d4,d0                   colour index
                movea.l a4,a0                   a0 = viewport
                jsr     SetRGB4(a6)
                addq.w  #1,d4
                cmpi.w  #20,d4
                bne.s   1$                      repeat for remaining colours

                movea.l intuitionbase(pc),a6
                movea.l a3,a0                   windowptr
                jsr     ClearPointer(a6)        remove previous pointer

                move.w  (a2)+,d1                width
                move.w  (a2)+,d0                height
                move.w  (a2)+,d2                xoffset
                move.w  (a2)+,d3                yoffset
                movea.l a2,a1                   a1=pointer address
                movea.l a3,a0                   windowptr
                jsr     SetPointer(a6)
                rts

*****************************************************************
*                                                               *
* PAL_to_NTSC - Converts all PAL-dependent display coordinates  *
*               NTSC compatible coordinates.                    *
*                                                               *
* INPUTS: None.                                                 *
* OUTPUT: None.                                                 *
*                                                               *
*****************************************************************

PAL_to_NTSC     subi.w  #56,ns_height           screen height
                subi.w  #50,nw_height           window height
                subi.w  #50,10+Prop1Gadget      prop1 height
                subi.w  #50,10+Prop2Gadget      prop2 height
                subi.w  #50,Req_Bottom          for requester clearing
                subi.w  #25,DiskYPos            for disk insert/removal
                move.w  #7,ReqSize              requester height
                lea     PAL_rectangles(pc),a0   adjust rectangles
                lea     NTSC_rect_fix(pc),a1
                move.w  #(NTSC_fix_len/2)-1,d0
                bsr     Coord_fix

                lea     PAL_borders(pc),a0      adjust borders
                lea     NTSC_border_fix(pc),a1
                move.w  #(NTSC_bfix_len/2)-1,d0

Coord_fix       move.w  (a1)+,d1                get index
                subi.w  #50,0(a0,d1.w)          adjust coord
                dbf     d0,Coord_fix
                rts

*****************************************************************
*                                                               *
* drawrects - draws a table of rectangles                       *
*                                                               *
* INPUT:  a1 = pointer to window rastport                       *
*         a2 = pointer to rectangle table                       *
*                                                               *
*****************************************************************

DrawRects       move.w  (a2)+,d7        d7 = number of rectangles
                subq.w  #1,d7           d7=d7-1 because of dbf below
1$              movem.w (a2)+,d0-d4
                bsr.s   DrawRect
                dbf     d7,1$
                rts

*****************************************************************
*                                                               *
* drawrect - draws solid rectangle                              *
*                                                               *
* INPUTS: d0 = x1 position of rectangle                         *
*         d1 = y1 position of rectangle                         *
*         d2 = x2 position of rectangle                         *
*         d3 = y2 position of rectangle                         *
*         d4 = pen number                                       *
*         a1 = pointer to window rastport                       *
* OUTPUT: a1 is unchanged                                       *
*                                                               *
*****************************************************************

DrawRect        movem.l d0-d3/a1,-(a7)
                movea.l graphicsbase(pc),a6
                move.l  a1,-(a7)
                move.b  d4,d0           pen number
                jsr     SetAPen(a6)
                movea.l (a7)+,a1
                movem.l (a7)+,d0-d3
                jsr     RectFill(a6)
                movea.l (a7)+,a1
                rts

*****************************************************************
*                                                               *
* drawbords - draws a table of borders                          *
*                                                               *
* INPUT: a1 = pointer to window rastport                        *
*        a2 = pointer to border table                           *
*                                                               *
*****************************************************************

DrawBords       move.w  (a2)+,d7        d7 = number of borders
                subq.w  #1,d7           d7=d7-1 because of dbf below
1$              movem.w (a2)+,d0-d5
                bsr.s   DrawBord
                dbf     d7,1$
                rts

*****************************************************************
*                                                               *
* drawbord - draws 3D style bas-relief border                   *
*                                                               *
* INPUTS: d0 = x position of border                             *
*         d1 = y position of border                             *
*         d2 = width of border                                  *
*         d3 = height of border                                 *
*         d4 = pen for left & top of border                     *
*         d5 = pen for bottom & right of border                 *
*         a1 = pointer to window rastport                       *
* OUTPUT: a1 is unchanged                                       *
*                                                               *
*****************************************************************

X               equr    d2      width of border register
Y               equr    d3      height of border register

DrawBord        move.l  a1,-(a7)                save rastport onto stack
                lea     Bas_Vectors1(pc),a0
                lea     Bas_Vectors2(pc),a1
                move.w  Y,6(a0)                 (0,Y)
                move.w  Y,2(a1)                 (1,Y)
                movem.w X/Y,4(a1)               (X,Y)
                move.w  X,8(a1)                 (X,0)
                subq.w  #1,X                    X = X - 1
                subq.w  #1,Y                    Y = Y - 1
                move.w  Y,10(a0)                (1,Y-1)
                move.w  X,16(a0)                (X-1,0)
                move.w  X,12(a1)                (X-1,1)
                movem.w X/Y,16(a1)              (X-1,Y-1)
                addq.w  #1,X                    X = X + 1
                addq.w  #1,Y                    Y = Y + 1
                move.b  d4,Bas_Pen1
                move.b  d5,Bas_Pen2

                movea.l intuitionbase(pc),a6
                movea.l (a7),a0                 get rastport from stack
                lea     Bas_Border(pc),a1
                jsr     DrawBorder(a6)          draw 3D border
                movea.l (a7)+,a1                restore a1's contents
                rts

Bas_Border      dc.w    0,0                     LeftEdge,TopEdge
Bas_Pen1        dc.b    0,0                     FrontPen,BackPen
                dc.b    JAM1,5                  DrawMode,#points
                dc.l    Bas_Vectors1            pointer to vector coords
                dc.l    Bas_Border2             pointer to next border structure
Bas_Vectors1    dc.w    0,0,0,0,1,0,1,0,0,0

Bas_Border2     dc.w    0,0
Bas_Pen2        dc.b    0,0
                dc.b    JAM1,5
                dc.l    Bas_Vectors2,NULL
Bas_Vectors2    dc.w    1,0,0,0,0,0,0,1,0,0

*****************************************************************
*                                                               *
* copydat - high speed data copying routine                     *
*                                                               *
* INPUTS: a0 = source memory pointer.                           *
*         a1 = destination memory pointer.                      *
*         d0 = number of bytes-1 to copy.                       *
*                                                               *
*****************************************************************

copydat         move.b  (a0)+,(a1)+
                dbf     d0,copydat
                rts

copyname        clr.l   d0
copynameloop    tst.b   (a0)
                beq.s   copyend
                move.b  (a0)+,(a1)+
                addq.w  #1,d0
                bra.s   copynameloop
copyend         rts

*****************************************************************
*                                                               *
* comparenames - compares 2 null-terminated strings             *
*                                                               *
* INPUTS : a0 = ptr to 1st string                               *
*          a1 = ptr to 2nd string                               *
* OUTPUTS: d0 =  0 if strings are identical (case independent)  *
*             =  1 if string1 < string2                         *
*             = -1 if string1 > string2                         *
*                                                               *
*****************************************************************

comparenames    move.b  (a0)+,d0        get char from 1st string
                bsr     ConvCase
                move.b  d0,d1
                move.b  (a1)+,d0        get char from 2nd string
                bsr     ConvCase
                
                cmp.b   d0,d1           chars same?
                bne     notsame         * change these 2 lines for a better loop *

                tst.b   -1(a0)          end reached for both names?
                bne     comparenames
strsame         clr.l   d0              d0 = 0 for strings identical
                rts

notsame         tst.b   d1
                beq     str1end
                cmp.b   d0,d1
                bcc     str2_LT_str1
                bra     str1_LT_str2
                
str1end         suba.l  #1,a1
1$              cmpi.b  #32,(a1)+
                beq     1$
                tst.b   -1(a1)
                beq     strsame

str1_LT_str2    moveq   #1,d0           string2 > string1
                rts

str2_LT_str1    moveq   #-1,d0          string1 > string2
                rts

ConvCase        cmpi.b  #97,d0
                blt     1$
                sub.b   #32,d0
1$              rts

Refresh_Gadgets movea.l intuitionbase(pc),a6
                move.l  windowptr(pc),a1        ptr to window
                movea.l #NULL,a2                ptr to sys requester
                jmp     RefreshGadgets(a6)

*****************************************************************
*                                                               *
* WaitForMSG - Waits for a message on a given port              *
*                                                               *
* INPUTS: a0 = pointer to a message port                        *
* OUTPUT: a1 = pointer to message                               *
*         d1 = message class                                    *
*                                                               *
*****************************************************************

WaitForMSG      move.l  a0,-(a7)                save MessagePort
                move.l  execbase,a6
                jsr     WaitPort(a6)            wait for a message

                movea.l (a7)+,a0                get messageport
                jsr     GetMSG(a6)              receive the message

                movea.l d0,a1
                move.l  a1,message
                move.l  Class(a1),d1            find message type
                cmpi.l  #INTUITICKS,d1          timertick msg?
                bne.s   2$

1$              tst.w   Tickdelay
                beq.s   2$
                subq.w  #1,Tickdelay
                bne.s   2$

                movem.l d1/a1/a6,-(a7)
                move.l  windowptr(pc),a0
                move.l  #-1,a1
                lea     ScrTitle(pc),a2
                movea.l intuitionbase(pc),a6
                jsr     SetWindowTitles(a6)     reset screen title
                movem.l (a7)+,d1/a1/a6
                moveq   #-1,d0

2$              rts

;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
;o                                                              o
;o         ArcTool Configuration Module v1.0 27/7/92            o
;o         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~            o
;o                                                              o
;o OUPUTS: d7 =  0 config file ok                               o
;o             >1 error in config file                          o
;o                                                              o
;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

ARCNODE_SIZE    equ     28
COMMNODE_SIZE   equ     18
MEMF_CLEAR      equ     $10000
OFFSET_CURRENT  equ     0
NAMELENGTH      equ     27
EOLN            equ     10
HTAB            equ     9

** library offsets **

seek            equ     -66
addtail         equ     -246

GetConfig       move.l  sp,initialSP
                move.l  dosbase(pc),a6
                
                move.l  #ConfigFile,d1
                move.l  #MODE_OLD,d2
                jsr     open(a6)                open config file
                move.l  d0,filehandle
                beq     openerror

                lea     ArcList(pc),a0
                bsr     InitList
                
GetArchiveTool  bsr     GetName
                cmpa.l  #0,a3
                beq     Config_Finished

                bsr     AddArcNode
GetA            bsr     readchar
                beq     formaterror
                cmpi.b  #'{',d1
                bne     GetA
ArcLoop         bsr     GetName                 get command name
                move.l  a3,a4                   ptr to string
                bsr     GetCommandLine
                bsr     AddCommNode
ArcEndCheck     bsr     readchar
                beq     formaterror
                cmpi.b  #'}',d1
                beq     GetArchiveTool          get next ArcNode
                cmpi.b  #EOLN,d1
                beq     ArcEndCheck
                cmpi.b  #HTAB,d1
                beq     ArcEndCheck
                cmpi.b  #'*',d1
                beq     ScanComment
                bsr     SeekBack1               go back to previous char
                bra     ArcLoop                 get next command

ScanComment     bsr     readchar
                beq     formaterror
                bmi     ReadError
                cmpi.b  #EOLN,d1
                bne     ScanComment
                bra     ArcLoop

formaterror     lea     errortext8(pc),a0       unexpected EOF
                bra     configerror     

openerror       lea     errortext7(pc),a0
configerror     move.l  a0,ConfigErrorPtr
                moveq   #4,d0
                moveq   #42,d1
                move.l  WRastPort(pc),a0
                lea     ConfigIError(pc),a1
                move.l  intuitionbase(pc),a6
                jsr     PrintIText(a6)
                
                move.l  dosbase(pc),a6
                move.l  #300,d1                 d1 = 300/16 second delay
                jsr     Delay(a6)

AllocError      
ReadError       moveq   #1,d7
                bra     Bad_Config

Config_Finished clr.l   d7
Bad_Config      move.l  filehandle(pc),d1       close the configfile
                move.l  dosbase(pc),a6
                jsr     close(a6)

                move.l  initialSP(pc),sp
                rts

;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
;o                                                              o
;o readchar - reads 1 char from open file                       o
;o                                                              o
;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

readchar        move.l  filehandle(pc),d1
                move.l  #CharBuffer,d2
                moveq   #1,d3                   length = 1 char
                move.l  dosbase(pc),a6
                jsr     Read(a6)
                move.b  CharBuffer(pc),d1
                tst.l   d0
                rts

;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
;o                                                              o
;o SeekBack1 - moves file pointer back 1 character              o
;o                                                              o
;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

SeekBack1       move.l  #-1,d2
                move.l  filehandle(pc),d1
                moveq   #OFFSET_CURRENT,d3
                move.l  dosbase(pc),a6
                jsr     seek(a6)
                rts

;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
;o                                                              o
;o GetName - reads a line of text from a file and stores        o
;o          it as a null-terminated string in RAM               o
;o                                                              o
;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

GetName         moveq   #NAMELENGTH+1,d0
                move.l  d0,d7
                move.l  #MEMF_PUBLIC|MEMF_CLEAR,d1
                move.l  execbase,a6
                jsr     AllocMem(a6)
                beq     AllocError
                move.l  d0,a2
                move.l  a2,a3                   address of string
                subq    #2,d7                   max no of chars to read
ReadNameLoop    bsr     readchar
                beq     GN_EndReached
                bmi     ReadError
                cmpi.b  #EOLN,d1
                beq     ReadNameLoop            skip blank lines
                cmpi.b  #HTAB,d1
                beq     ReadNameLoop            skip tabs
                cmpi.b  #'*',d1                 check for a comment line
                bne     NameLoop2
ReadComment     bsr     readchar
                beq     GN_EndReached
                bmi     ReadError
                cmpi.b  #EOLN,d1
                bne     ReadComment
                bra     ReadNameLoop

NameLoop2       cmpi.b  #EOLN,d1
                beq     GN_ShortLine
                move.b  d1,(a2)+                store char in string
                bsr     readchar
                beq     GN_EndReached
                bmi     ReadError
                dbf     d7,NameLoop2

GN_SkipRest     bsr     readchar                skip rest of line
                beq     GN_EndReached
                bmi     ReadError
                cmpi.b  #EOLN,d1
                bne     GN_SkipRest
                rts

GN_ShortLine    move.b  #32,(a2)+
                dbf     d7,GN_ShortLine
                rts

GN_EndReached   move.l  execbase,a6
                move.l  a3,a1
                moveq   #NAMELENGTH+1,d0
                jsr     FreeMem(a6)             de-allocate RAM for string
                movea.l #0,a3                   signal that no name was read
                rts

;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
;o                                                              o
;o GetCommandLine - reads command line for archive option       o
;o                                                              o
;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

GetCommandLine  move.l  dosbase(pc),a6
                clr.l   d7
InitCheck       bsr     readchar
                cmpi.b  #EOLN,d1
                beq     InitCheck
CountLength     cmpi.b  #';',d1
                beq     endcount
                addq    #1,d7
                bsr     readchar
                beq     GCL_EndReached
                bmi     ReadError
                bra     CountLength
                
endcount        move.l  d7,d2
                neg.l   d2              d2 = -length
                sub.l   #1,d2           d2 = d2 - 1
                move.l  filehandle(pc),d1
                moveq   #OFFSET_CURRENT,d3
                jsr     seek(a6)
                move.l  d7,d0
                addq    #1,d0
                move.l  #MEMF_PUBLIC|MEMF_CLEAR,d1
                move.l  execbase,a6
                jsr     AllocMem(a6)    allocate RAM for text
                beq     AllocError
                move.l  d0,a2
                move.l  a2,a3           ptr to string
                subq    #1,d7
ReadCommLoop    bsr     readchar
                bmi     ReadError
                move.b  d1,(a2)+
                dbf     d7,ReadCommLoop
                bsr     readchar        scan past ';'
                rts

GCL_EndReached  lea     errortext8(pc),a0
                bra     configerror

;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
;o                                                              o
;o AddArcNode - Adds node for archive tool to list              o
;o                                                              o
;o INPUTS : a3 = ptr to arcname                                 o
;o OUTPUTS: a2 = ptr to arcnode                                 o
;o                                                              o
;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

AddArcNode      moveq   #ARCNODE_SIZE,d0
                move.l  #MEMF_PUBLIC|MEMF_CLEAR,d1
                move.l  execbase,a6
                jsr     AllocMem(a6)
                beq     AllocError
                move.l  d0,a2           ptr to node
                move.l  a3,10(a2)       set ln_name (7 gives address error!)
                move.l  a2,a3
                lea     14(a3),a3       point to CommList
                move.l  a3,TempArcBase
                move.l  a3,a0
                bsr     InitList        initialise CommList
                lea     ArcList(pc),a0
                move.l  a2,a1
                jsr     addtail(a6)
                rts

;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
;o                                                              o
;o AddCommNode - Adds node for archive command to parent        o
;o              archive list                                    o
;o                                                              o
;o INPUTS : a3 = ptr to command line                            o
;o         a4 = ptr to command name                             o
;o OUTPUTS: None                                                o
;o                                                              o
;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

AddCommNode     moveq   #COMMNODE_SIZE,d0
                move.l  #MEMF_PUBLIC|MEMF_CLEAR,d1
                move.l  execbase,a6
                jsr     AllocMem(a6)
                tst.l   d0
                beq     AllocError
                move.l  d0,a1
                move.l  a4,10(a1)       set ln_name
                move.l  a3,14(a1)       set ln_name2
                move.l  TempArcBase(pc),a0
                jsr     addtail(a6)
                rts

;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
;o                                                              o
;o InitList - Initializes the head of a list                    o
;o                                                              o
;o INPUTS : a0 = ptr to head of list                            o
;o OUTPUTS: None                                                o
;o                                                              o
;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

InitList        move.l  a0,(a0)
                addq.l  #4,(a0)         lh_head = &lh_tail
                clr.l   4(a0)           lh_tail = 0
                move.l  a0,8(a0)        lh_tailpred = &lh_head
                rts

;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
;o                                                              o
;o ClearArcList - Deallocates ram used by ArcList structure     o
;o               which was generated from configuration file    o
;o                                                              o
;o INPUTS : None                                                o
;o OUTPUTS: None                                                o
;o                                                              o
;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

ClearArcList    lea     ArcList(pc),a2          list base
                move.l  a6,-(a7)
                move.l  execbase,a6
                move.l  (a2),a2                 locate 1st node
ClearArcList2   tst.l   (a2)
                beq     ClearArcEnd
                move.l  (a2),a3                 a2=list base address

ClearArcNode    move.l  14(a2),a4               a4=CommNode
                moveq   #NAMELENGTH+1,d0        deallocate arcname string
                move.l  10(a2),a1               ptr to string
                jsr     FreeMem(a6)
                
ClearCommNode   tst.l   (a4)                    end of commlist?
                beq.s   EndClearArc

                moveq   #NAMELENGTH+1,d0        deallocate comm name
                move.l  10(a4),a1
                jsr     FreeMem(a6)

                moveq   #1,d0
                move.l  14(a4),a1
GetCommLineLen  tst.b   -1(a1,d0.w)
                beq     1$
                addq    #1,d0
                bra.s   GetCommLineLen
1$              jsr     FreeMem(a6)             deallocate comm name2

                moveq   #COMMNODE_SIZE,d0
                move.l  a4,a1
                move.l  (a4),a4
                jsr     FreeMem(a6)             deallocate commnode

                bra.s   ClearCommNode

EndClearArc     move.l  a2,a1
                move.l  #ARCNODE_SIZE,d0
                jsr     FreeMem(a6)

                move.l  a3,a2
                bra.s   ClearArcList2           
ClearArcEnd     movem.l (a7)+,a6
                rts

*
* DATA SECTION
*

initialSP       dc.l    0
CharBuffer      dc.b    0
                even
TempArcBase     dc.l    0
ArcList         dc.l    0,0,0
                dc.b    0,0

;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
;o                                                              o
;o                END OF CONFIGURATION MODULE                   o
;o                                                              o
;oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo

*****************************************************************
*                                                               *
* TestUnit - Checks the diskstate of a given floppy unit        *
*                                                               *
* INPUTS : d0 = Unit number (0 - 3)                             *
* OUTPUTS: d0 =  0 if no disk present                           *
*               >1 if disk is present                           *
*               -1 if unit is not a floppy unit                 *
*                                                               *
*****************************************************************

TestUnit        move.l  d0,d1
                andi.l  #3,d0
                cmp.l   d0,d1
                bne     BadUnit

                move.l  execbase,a6
                lea     diskio(pc),a1
                clr.l   d1                      no flags
                lea     trackdisk(pc),a0        device name
                jsr     OpenDevice(a6)          open trackdisk.device
                tst.l   d0
                bne     BadUnit
                
                lea     diskio(pc),a1
                move.l  #readreply,14(a1)       set reply port
                move.w  #TD_CHANGESTATE,IO_COMMAND(a1)
                move.l  #diskbuff,IO_DATA(a1)
                move.l  #1,IO_LENGTH(a1)
                
                jsr     DoIO(a6)
                move.l  diskio+IO_ACTUAL,d2
                
                lea     diskio(pc),a1
                jsr     CloseDevice(a6)         close trackdisk.device

                move.l  d2,d0
                rts
                
BadUnit         moveq   #-1,d0
                rts

*****************************************************************
*                                                               *
* ScrollReqUp - Scrolls contents of requester up by one row.    *
*                                                               *
* INPUTS: a5 = ptr to requester structure                       *
*                                                               *
*****************************************************************

ScrollReqUp     bsr     ScrollPotUp
                moveq   #-10,d1                 dy
                bsr.s   ScrollReq
                bsr     CalcPotPos
                move.w  d2,d0
                bsr     GotoEntry               locate bottom entry
                move.w  12(a5),FnameXpos        xpos
                moveq   #REQ_TOP+2,d5           ypos
                bsr     PrFname
                rts

*****************************************************************
*                                                               *
* ScrollReqDn - Scrolls contents of requester down by one row   *
*                                                               *
* INPUTS: a5 = ptr to requester structure                       *
*                                                               *
*****************************************************************

ScrollReqDn     moveq   #10,d1                  dy
                bsr.s   ScrollReq
                bsr     CalcPotPos
                move.w  d2,d0
                add.w   ReqSize(pc),d0
                bsr     GotoEntry               locate top entry
                move.w  12(a5),FnameXpos        xpos
                move.w  Req_Bottom(pc),d5       ypos
                subi.w  #9,d5
                bsr     PrFname
                bsr     ScrollPotDn
                rts

ScrollReq       moveq   #0,d0                   dx
                move.w  12(a5),d2               xmin
                move.w  d2,d4
                add.w   #REQ_WIDTH,d4           xmax
                moveq   #REQ_TOP+2,d3           ymin
                move.w  Req_Bottom(pc),d5       ymax
                movea.l WRastPort(pc),a1        rastport address
                movea.l graphicsbase(pc),a6
                jsr     ScrollRaster(a6)        scroll requester box
                rts

*****************************************************************
*                                                               *
* ScrollPotUp - Moves prop gadget up so that the directory list *
*               in the file requester scrolls up by one name.   *
*                                                               *
* INPUTS: a1 = address of the gadget                            *
*         d0 = number of entries in the directory list          *
*                                                               *
*****************************************************************

ScrollPotUp     moveq.w #-1,d1
                bsr.s   SetPotPos
                rts

*****************************************************************
*                                                               *
* ScrollPotDn - Moves prop gadget down so that the directory    *
*               in the file requester scrolls down by one name. *
*                                                               *
* INPUTS: a1 = address of the gadget                            *
*         d0 = number of entries in the directory list          *
*                                                               *
*****************************************************************

ScrollPotDn     moveq.w #1,d1
                bsr.s   SetPotPos
                rts
                
*****************************************************************
*                                                               *
* SetPotPos - sets vertical pot position so it lies at a given  *
*             entry number.                                     *
* INPUTS: a5 = address of requester                             *
*         d1 = line displacement to give entry number           *
*                                                               *
*****************************************************************

SetPotPos       bsr     CalcPotPos
                
                add.w   d1,d2           calc new row
                bvc.s   1$
                neg.w   d2
1$              cmp.w   #0,d2           topentry <= 0?
                bgt.s   2$
                clr.w   d2
                bra.s   4$

2$              cmp.w   d0,d2           topentry >= (#entries-reqsize)?
                blt.s   3$
                moveq   #-1,d2          d2 = ffff
                bra.s   4$

3$              mulu    #$ffff,d2       entry# * $FFFF
                divu    d0,d2           vertpot=d2/(#entries-reqsize)
                lsr.w   #1,d0
                swap    d2
                tst.w   d2
                beq.s   5$
                addi.l  #$00010000,d2
5$              swap    d2

4$              move.w  (a0),d0         flags
                move.w  2(a0),d1        horizpot
                cmp.w   4(a0),d2        no change in vpot?
                beq.s   6$
                move.w  6(a0),d3        horizbody
                move.w  8(a0),d4        vertbody
                movea.l a1,a0           gadgetptr
                movea.l windowptr(pc),a1
                suba.l  a2,a2           requester = NULL
                movea.l intuitionbase(pc),a6
                jsr     ModifyProp(a6)  reposition prop gadget
6$              rts

*****************************************************************
*   CalcPotPos - calculates file pos from proportional gadget   *
*                                                               *
*       INPUTS: a5 = address of the requester                   *
*       OUTPUT: d0 = #entries - reqsize                         *
*               d2 = file position within file requester        *
*               a0 = propinfo ptr for requester's propgadget    *
*               a1 = gadgetptr for requester                    *
*                                                               *
*****************************************************************

CalcPotPos      move.w  (a5),d0         #entries
                movea.l 6(a5),a1        gadget ptr
                movea.l 34(a1),a0       propinfo ptr
                clr.l   d2
                sub.w   ReqSize(pc),d0  numentries - total display lines
                bmi.s   EndCalcPos
                beq.s   EndCalcPos
                move.w  4(a0),d2        vertpot
                mulu    d0,d2           vertpot * (numentries-lines)
                divu    #$ffff,d2       /MAXBODY
EndCalcPos      rts                     d2 = file pos

*****************************************************************
*          Chdir - loads in the selected directory              *
*                                                               *
*       INPUTS: a5 = address of requester                       *
*               a2 = ptr to node containing directory name      *
*       OUTPUT: d7 = #entries in new dir                        *
*****************************************************************

Chdir           lea     4(a2),a0        dir name
                lea     20(a5),a1       path name ptr
                bsr.s   AddPathDir
;               lea     ArcPathStrgad(pc),a0
;               bsr     Refresh_Gadgets
                bsr     Dir
                rts

AddPathDir      moveq   #-1,d0
SearchZero      addq.w  #1,d0
                tst.b   0(a1,d0.w)      check for terminating null
                bne.s   SearchZero
                tst.w   d0
                beq.s   1$
                cmpi.b  #':',-1(a1,d0.w)
                beq.s   2$
                move.b  #'/',0(a1,d0.w)
                addq.w  #1,d0
2$              lea     0(a1,d0.w),a1   a1 = address for dir name to go
1$              bsr     copyname
SearchEnd       cmpi.b  #32,-(a1)       remove trailing spaces
                beq.s   SearchEnd
                lea     1(a1),a1
                clr.b   (a1)
                rts

*****************************************************************
*          ParentDir - loads in the parent directory            *
*                                                               *
*       INPUTS: a5 = ptr to requester                           *
*       OUTPUT: d7 = #entries in new directory                  *
*****************************************************************

ParentDir       lea     20(a5),a0       path name ptr
                tst.b   (a0)
                beq.s   1$
                bsr     RemPathDir
                bsr     Dir
1$              rts

RemPathDir      moveq   #-1,d0
FindZero        addq.w  #1,d0
                tst.b   0(a0,d0.w)              check for terminating null
                bne.s   FindZero
                cmpi.b  #':',-1(a0,d0.w)        only a volume name given?
                bne.s   FindMark
                clr.b   (a0)                    clear string
                rts
FindMark        subq.w  #1,d0
                beq.s   FoundMarker
                cmpi.b  #'/',0(a0,d0.w)
                beq.s   FoundMarker
                cmpi.b  #':',0(a0,d0.w)
                bne.s   FindMark
                add.w   #1,d0
FoundMarker     clr.b   0(a0,d0.w)
                rts

*****************************************************************
*                                                               *
* NameCycle - Cycles through available archiving tools          *
*                                                               *
*****************************************************************

NameCycle       move.l  UtilityName(pc),a0
                move.l  (a0),a0                 ln_succ
                tst.l   (a0)                    end of list?
                bne.s   NameOK
ResetNameText   lea     ArcList(pc),a0
                move.l  (a0),a0                 lh_head
NameOK          move.l  a0,UtilityName
                move.l  10(a0),a0               ln_name
                move.l  a0,INameptr
                move.l  WRastPort(pc),a0
                move.l  intuitionbase(pc),a6
                moveq   #82,d0
                moveq   #27,d1
                lea     NameIText(pc),a1
                jsr     PrintIText(a6)
                bra.s   ResetMode

NameIText       dc.b    1,2
                dc.b    JAM2
                dc.w    0,0
                dc.l    NULL
INameptr        dc.l    0
                dc.l    NULL

*****************************************************************
*                                                               *
* ModeCycle - Cycles through available archiving options        *
*                                                               *
*****************************************************************

ModeCycle       move.l  UtilityMode(pc),a0
                move.l  (a0),a0                 ln_succ
                tst.l   (a0)                    end of list?
                bne.s   ModeOK
ResetMode       move.l  UtilityName(pc),a0
                move.l  14(a0),a0               CommList->Lh_head
ModeOK          move.l  a0,UtilityMode
                move.l  10(a0),a0               ln_name         
                move.l  a0,INameptr
                move.l  WRastPort(pc),a0
                move.l  intuitionbase(pc),a6
                move.l  #369,d0
                moveq   #27,d1
                lea     NameIText(pc),a1
                jsr     PrintIText(a6)
                rts

*****************************************************************
*                                                               *
* Help - Toggles help mode & pointer definition.                *
*                                                               *
* INPUTS: None                                                  *
* OUTPUT: None                                                  *
*                                                               *
*****************************************************************

Help            movea.l windowptr(pc),a0
                bsr     NormalPointer
                rts
                
*****************************************************************
*                                                               *
* ProgRequest - Displays a program requester window.            *
*                                                               *
* INPUTS: a2 = pointer to table containing text (see below).    *
*         d0 = type of requester                                *
*            = $0000 for OK requester                           *
*            = $0001 for CANCEL requester                       *
*            = $0002 for OK/CANCEL requester                    *
*            = $0000 dont return until gadget message received  *
*            = $1000 return immediately after screen setup      *
* OUTPUT: d0 = 0 for CANCEL condition                           *
*            = 1 for OK condition                               *
*            =-1 if no message received (applicable for $1000)  *
*         The flags reflect the value in d0                     *
*                                                               *
*****************************************************************

ProgRequest     move.w  d0,ReqMode              save requester mode

*** Draw requester and textual contents ***

                move.l  #StdOKgadget,stdgadlist
                lea     Stdgadboxes1(pc),a1
                move.w  #266,StdOKgadxpos
                move.l  #OKItext,OK_CANCEL_Itext
                move.w  #1,OK_CANCEL_ID
                btst    #0,d0
                beq.s   1$
                move.l  #CANCELItext,OK_CANCEL_Itext
                clr.w   OK_CANCEL_ID
                bra.s   2$
1$              btst    #1,d0                   ok/cancel requester?
                beq.s   2$
                move.l  #StdCANCELgadget,stdgadlist
                lea     Stdgadboxes2(pc),a1
                move.w  #150,StdOKgadxpos
2$              move.w  (a2)+,d0        d0 = no. lines
                move.w  d0,d6
                subq.w  #1,d6           because of dbf loop construct
                mulu    #10,d0          calc height of window
                addi.w  #21,d0
                move.w  d0,StdWindY1    ypos of horizontal bar
                addq.w  #4,d0
                move.w  d0,StdWindY2    ypos of box around gadget
                move.w  d0,Std2WindY2   same for grey req OK
                move.w  d0,Std2WindY3   same for grey req CANCEL
                addi.w  #19,d0
                move.w  d0,StdWindY4    height of window border
                addq.w  #1,d0
                move.w  d0,stdwind_height       height of window
                move.w  d0,StdRectY
                move.w  (a2)+,d1                get window ypos
                bne.s   3$                      if zero, then y-centre window
                move.w  ns_height(pc),d1
                sub.w   d0,d1                   vertically centre help window
                lsr.w   #1,d1                   d1/2
3$              move.w  d1,stdwind_ypos
                
                movem.l a1-a2,-(a7)             save pointers

                lea     StdWindow(pc),a0
                movea.l intuitionbase(pc),a6
                jsr     OpenWindow(a6)          open help window
                move.l  d0,Stdwindptr
                beq     stdwindowerror          abort with d0 = 0(CANCEL)
                movea.l d0,a0

                bsr     NormalPointer           new mouse pointer
                bsr     GadgetsOnOff

                movea.l Stdwindptr(pc),a1
                movea.l WindowRastPort(a1),a1
                lea     Stdwindrects(pc),a2
                bsr     DrawRects               colour window
                                                ;a1 is unchanged
                lea     Stdwindbords(pc),a2
                bsr     DrawBords               draw window borders

                movea.l (a7)+,a2
                bsr     DrawBords               draw gadget boxes
                movea.l stdgadlist(pc),a0
                movea.l Stdwindptr(pc),a1
                suba.l  a2,a2                   a2 = ptr to requester (NULL)
                movea.l intuitionbase(pc),a6
                jsr     RefreshGadgets(a6)

                movea.l (a7)+,a0        get textptr back off stack into a0
                moveq   #4,d1           ypos
                moveq   #YELLOW,d2      pen number for text
                movea.l Stdwindptr(pc),a1
                bsr.s   Centre          print centred title
                moveq   #20,d1          starting ypos
                moveq   #LT_GREY,d2
Lineloop        tst.b   (a0)+           scan past end of line
                bne.s   Lineloop
                move.l  a0,d0           ensure a0 is at even address
                addq.l  #1,d0
                bclr    #0,d0
                movea.l d0,a0
                move.w  (a0)+,d0        xpos for current line
                bne.s   1$              if xpos = 0, then centre text
                bsr.s   Centre          print the line centred
                bra.s   2$
1$              bsr.s   Print           print the line
2$              addi.w  #10,d1          move to next print row
                dbf     d6,Lineloop     repeat for remaining lines
3$              btst.b  #7,ReqMode      immediate return?
                beq.s   WaitForResponse
                rts

*** Interpret gadget selection response ***

WaitForResponse movea.l Stdwindptr(pc),a0
                movea.l WindowUserPort(a0),a0
                bsr     WaitForMSG      wait for OK gadget to be clicked
                movea.l IAddress(a1),a0
                move.w  GadgetID(a0),d3
                move.l  d1,d2
                jsr     ReplyMSG(a6)
                cmpi.l  #GADGETUP,d2
                beq.s   EndRequest
                btst.b  #7,ReqMode      immediate return?
                beq.s   WaitForResponse no
                moveq   #-1,d0          set flag for no gadget hit
                rts
EndRequest      movea.l intuitionbase(pc),a6
                movea.l Stdwindptr(pc),a0
                jsr     CloseWindow(a6)
                bsr     GadgetsOnOff    re-enable program gadgets
                move.w  d3,d0           d0 = exit condition (OK/CANCEL)
stdwindowerror  rts
                
*****************************************************************
*                                                               *
* Centre - Prints a centred text string into a given window.    *
*                                                               *
* INPUTS: a0 = pointer to null terminated text.                 *
*         a1 = pointer to window.                               *
*         d1 = Ypos of text.                                    *
*         d2 = Foreground pen colour.                           *
*                                                               *
*****************************************************************

Centre          moveq   #-1,d3
1$              addq.w  #1,d3
                tst.b   0(a0,d3.w)      calculate length of string
                bne.s   1$
                asl.w   #3,d3           d3 * 8 = pixel length of string
                move.w  stdwind_width(pc),d0    window width
                sub.w   d3,d0
                lsr.w   #1,d0           d0 = centre x-position
                bsr.s   Print
                rts

*****************************************************************
*                                                               *
* Print - Prints a line of text into a given window.            *
*                                                               *
* INPUTS: a0 = pointer to null terminated text.                 *
*         a1 = pointer to window.                               *
*         d0 = Xpos of text.                                    *
*         d1 = Ypos of text.                                    *
*         d2 = Foreground pen colour.                           *
*                                                               *
*****************************************************************

Print           movem.l d0-d1/a0-a1/a6,-(a7)
                movea.l intuitionbase(pc),a6
                move.b  d2,FrontPen
                move.l  a0,ITextPtr

                movea.l WindowRastPort(a1),a0
                lea     ITextStruct(pc),a1
                jsr     PrintIText(a6)
                movem.l (a7)+,d0-d1/a0-a1/a6
                rts

ITextStruct
FrontPen        dc.b    0,0,JAM1,0
                dc.w    0,0
                dc.l    0
ITextPtr        dc.l    0,0

*****************************************************************
*                                                               *
* Archive - Performs the archiving function by building a       *
*           temporary script file on the ram drive              *
* INPUTS : None                                                 *
* OUTPUTS: None                                                 *
*                                                               *
*****************************************************************

Archive         move.l  dosbase(pc),a6

                move.l  #TempFile,d1
                move.l  #MODE_NEW,d2
                jsr     open(a6)                open text script file
                move.l  d0,filehandle
                beq     fileError

                move.l  UtilityMode(pc),a5
                move.l  14(a5),a5               a2->commline    
MakeCommLine    move.b  (a5)+,d0
                beq     MakeCommFinish
                cmpi.b  #'|',d0
                bne     NoCommand
                move.b  (a5)+,d0

;               cmpi.b  #'a',d0         MAY NOT NEED THIS!!!
;               bne     1$
;               clr.l   d0              signal that no path is to be printed
;               bsr     WriteArc
;               bra     CommContinue

1$              cmpi.b  #'A',d0
                bne     CommCheck2
                tst.w   ArcPathlen
                bne     ArcPathOK
                lea     errortext4(pc),a0
                lea     QDiskGadget(pc),a1      disk with questionmark
                bsr     DisplayError
                bra     generalArcError

ArcPathOK       tst.w   Filelen
                bne     ArcNameOK
                lea     errortext1(pc),a0
                lea     skullgadget(pc),a1
                bsr     DisplayError
                bra     generalArcError

ArcNameOK       bsr     WriteArc
                bra     CommContinue

CommCheck2      cmpi.b  #'f',d0
                bne     3$
                clr.l   d4              signal no paths are to be printed
                bsr     writefnames
                beq     selecterror
                bra     CommContinue

3$              cmpi.b  #'F',d0
                bne     CommCheck4
                move.b  d0,d4           signal for paths to be included
                bsr     writefnames
                bne     CommContinue

selecterror     lea     errortext2(pc),a0
                lea     skullgadget(pc),a1      ptr to error gadget
                bsr     DisplayError
                bra     generalArcError

CommCheck4      cmpi.b  #'U',d0
                bne     5$
                bsr     WriteUnit
                beq     generalArcError
                bra     CommContinue

5$              cmpi.b  #'D',d0
                bne     6$
                bsr     WriteVolDev
                ;
                bra     CommContinue

6$              cmpi.b  #'P',d0
                beq     CommOK

lineError       lea     errortext5(pc),a0
                lea     skullgadget(pc),a1
                bsr     DisplayError            bad command
                bra     generalArcError

generalArcError move.l  filehandle(pc),d1
                move.l  dosbase(pc),a6
                jsr     close(a6)
                bra     conerror                error! - bad option chosen

CommOK          tst.w   FilePathlen
                bne     DevOK
                lea     errortext3(pc),a0       error! no dev selected
                lea     QDiskGadget(pc),a1
                bsr     DisplayError
                bra     generalArcError

DevOK           bsr     WriteDev

CommContinue    move.b  (a5)+,d0
                cmpi.b  #'|',d0
                bne     lineError
                bra     MakeCommLine

NoCommand       bsr     WriteChar
                bra     MakeCommLine

MakeCommFinish  bsr     WriteChar

                move.l  filehandle(pc),d1       close the textfile
                move.l  dosbase(pc),a6
                jsr     close(a6)

                bsr     GadgetsOnOff

                move.l  #conname,d1
                move.l  #MODE_OLD,d2
                jsr     open(a6)                open a console window
                move.l  d0,conhandle
                beq     conerror

                move.l  #CLIcommand,d1          d1 = address of command
                clr.l   d3                      input = null
                move.l  conhandle(pc),d2        output = console device
                jsr     Execute(a6)

                move.l  conhandle(pc),d1
                move.l  #WaitForPress,d2
                moveq   #WAITLENGTH,d3
                jsr     Write(a6)
                move.l  conhandle(pc),d1
                move.l  #CharBuff,d2
                moveq   #1,d3
                jsr     Read(a6)

                bsr     GadgetsOnOff
                
                move.l  conhandle(pc),d1
                jsr     close(a6)

conerror        move.l  #TempFile,d1
                jsr     DeleteFile(a6)

fileError       rts

*****************************************************************
* writefnames - writes the selected paths and/or filenames      *
*                                                               *
* INPUTS : d4 =  0 ... Don't include paths                      *
*               >0 ... Do include paths                         *
* OUTPUTS: ZF =  1 if no filenames were listed                  *
*                0 if 1 or more filenames were listed           *
*          d7,a0,a2,a3,d2 corrupted                             *
*                                                               *
*****************************************************************

writefnames     lea     FileBase(pc),a2
                clr.b   d7                      fname flag

WriteLoop       tst.l   (a2)
                beq     WriteEnd
                move.l  (a2),a3
                btst    #0,116(a3)              select flag on?
                beq     1$
                bsr     WriteName
                moveq   #1,d7                   set fname flag
1$              move.l  a3,a2
                bra     WriteLoop
WriteEnd        tst.b   d7                      test for fname output
                rts

WriteName       bsr     WriteSpace
                bsr     WriteQuote
                tst.l   d4                      omit dev:
                beq     1$
                bsr     WriteDev
1$              move.l  a3,d2
                addq    #4,d2                   ptr to fname
                lea     34(a3),a0               ptr to fname end
                moveq   #30,d3                  length
StripSpaces     cmpi.b  #32,-(a0)
                bne     1$
                dbra    d3,StripSpaces
1$              bsr     WriteIt
                tst.l   112(a3)                 test for directory
                bmi.s   A_File
                bsr     WriteSlash              Add /#?
                move.l  #Wildcard,d2
                moveq   #WILDCARDLENGTH,d3
                bsr     WriteIt 
A_File          bsr     WriteQuote
                rts

*****************************************************************
*                                                               *
* WriteDev - Writes the destination path                        *
*                                                               *
*****************************************************************

WriteDev        move.l  #FilePath,d2            write dest path
                move.w  FilePathlen,d3
                ext.l   d3
                bsr     WriteIt
                lea     FilePath(pc),a0
                cmpi.b  #':',-1(a0,d3)
                beq     NoSlash
WriteSlash      move.l  #Slash,d2               write '/'
                moveq   #1,d3
                bsr     WriteIt
NoSlash         rts

WriteQuote      move.l  #Quote,d2               write "
                moveq   #1,d3
                bra     WriteIt

*****************************************************************
*                                                               *
* WriteArc - Writes selected archive paths and/or archive name  *
*                                                               *
* INPUTS : d0 =  0 ... Don't include archive path               *
*               >0 ... Include archive path                     * 
* OUTPUTS: d1, d2, d3 corrupted                                 *
*                                                               *
*****************************************************************

WriteArc        bsr     WriteQuote

                ;tst.l  d0              ONLY USE IF a OPTION IS INCLUDED!!!
                ;beq    NoArcPath       

                move.l  #ArcPath,d2             write archive path
                move.w  ArcPathlen(pc),d3
                ext.l   d3
                bsr     WriteIt
                lea     ArcPath(pc),a0
                cmpi.b  #':',-1(a0,d3)
                beq     NoArcPath
                move.l  #Slash,d2               write '/'
                moveq   #1,d3
                bsr     WriteIt

NoArcPath       move.l  #File,d2                write archive name
                move.w  Filelen(pc),d3
                ext.l   d3
                bsr     WriteIt
                bra     WriteQuote

*****************************************************************
*                                                               *
* WriteUnit - lists files requester floppy unit number          *
*                                                               *
* INPUTS : None                                                 *
* OUTPUTS: ZF =  1 ... Error ocurred                            *
*                0 ... No error ocurred                         *
*          a0, d0, d1, d2, d3 corrupted                         *
*                                                               *
*****************************************************************

WriteUnit       move.l  FileUnitNo,d0
                move.l  d0,d1
                andi.l  #%00000011,d0
                cmp.l   d0,d1
                bne     UnitError
                add.b   #'0',d0                 convert to ASCII
                bsr     WriteChar
WriteSpace      move.l  #SpcChar,d2             print a space
                moveq   #1,d3                   length = 1 char
                bsr     WriteIt                 insert a space
                moveq   #1,d0
                rts

UnitError       lea     errortext6(pc),a0
                lea     EDiskGadget(pc),a1      disk with exclemationmark
                bsr     DisplayError
                clr.l   d0
                rts

*****************************************************************
*                                                               *
* WriteVolDev - displays volume device name                     *
*                                                               *
*****************************************************************

WriteVolDev     move.l  FileUnitNo(pc),d0
                bsr     GetUnitName
                cmpa.l  #0,a0
                beq     3$
                clr.l   d3
                move.b  (a0)+,d3                get length of BCPL string
                move.l  a0,d2                   ptr to string
                bsr     WriteIt                 output dev
                move.b  #':',d0                 output ':'
                bsr     WriteChar
3$              rts

WriteChar       move.b  d0,CharBuff
                move.l  #CharBuff,d2
                moveq   #1,d3                   length = 1 char
WriteIt         move.l  filehandle(pc),d1
                move.l  dosbase(pc),a6
                jsr     Write(a6)
                rts

*****************************************************************
*                                                               *
* DisplayError - Opens a window & displays given error message  *
*                                                               *
* INPUTS : a0 = ptr to error message text string                *
*          a1 = ptr to gadget imagery to be displayed in window *
* OUTPUTS: None                                                 *
*                                                               *
*****************************************************************

DisplayError    move.l  a0,errortextptr
                move.l  a1,ErrorGadgetptr
                
                bsr     GadgetsOnOff

                move.l  intuitionbase(pc),a6
                lea     ErrorWindow(pc),a0
                jsr     OpenWindow(a6)          open new window
                move.l  d0,windowptr2
                beq     werror2

                move.l  windowptr2(pc),a0
                move.l  WindowRastPort(a0),a0
                lea     errorItext(pc),a1
                clr.l   d0
                clr.l   d1
                jsr     PrintIText(a6)

waitloop2       move.l  windowptr2(pc),a0
                move.l  WindowUserPort(a0),a0

                bsr     WaitForMSG

                cmpi.l  #GADGETUP,d1            custom gadget?
                beq     gadgethit2
                jsr     ReplyMSG(a6)
                bra     waitloop2
                
gadgethit2      move.l  IAddress(a1),a1         handle a gadget hit
                move.w  GadgetID(a1),d2
                move.l  message(pc),a1
                jsr     ReplyMSG(a6)
                tst.b   d2
                bne     waitloop2

                move.l  intuitionbase,a6
                move.l  windowptr2(pc),a0
                jsr     CloseWindow(a6)         
                
werror2         bsr     GadgetsOnOff
                rts

GadgetsOnOff    move.l  #0,d2
                move.l  d2,a2
                lea     Gadgnames(pc),a3
OffLoop         move.l  windowptr(pc),a1
                move.l  0(a3,d2.l),a0           a0=GadgetX.flags
                eori.w  #GADGDISABLED,12(a0)
                addq    #4,d2
                cmpi.l  #Gadgnames_len,d2
                bne.s   OffLoop
                rts

AddGadgets      move.l  intuitionbase(pc),a6
                clr.l   d2
                lea     Gadgnames(pc),a2
                
AddLoop         move.l  windowptr(pc),a0
                move.l  0(a2,d2.l),a1           a1=GadgetX
                move.l  d2,d0
                lsr.l   #2,d0                   d0=GadgID=d2/4
                jsr     AddGadget(a6)
                addq    #4,d2
                cmpi.l  #Gadgnames_len,d2
                bne     AddLoop
                rts

Gadgnames       dc.l    ToolCyclegad,OptionCyclegad
                dc.l    Exitgad,Aboutgad,Helpgad,Archivegad
                dc.l    ArcMakedirgad,ArcParentgad,ArcDeletegad,ArcCopygad
                dc.l    FilesMakedirgad,FilesParentgad,FilesDeletegad
                dc.l    FilesCopygad,ArcArrowUpgad,ArcArrowDngad
                dc.l    FileArrowUpgad,FileArrowDngad
                dc.l    Prop1Gadget,Prop2Gadget
                dc.l    ArcPathStrgad,FilesPathStrgad,FileGadget
Gadgnames_len   equ     *-Gadgnames

*****************************************************************
*                                                               *
* Dir - Reads in directory for given path                       *
*                                                               *
* INPUTS: a5 = ptr to requester                                 *
*                                                               *
*****************************************************************

Dir             bsr     ClearList               clear dir list
                bsr     DiskDir
                bsr     ModProp                 set prop gad size
                clr.w   14(a5)                  old Ypot position
                move.w  #$ffff,10(a5)           set disk-in flag
                tst.b   20(a5)                  check for path
                bne.s   1$
                clr.w   10(a5)                  clear disk-in flag
                rts
1$              bsr     DOS_Error
                beq.s   2$
                clr.b   20(a5)                  remove path name
                bra.s   Dir                     load in path listing
2$              rts

*****************************************************************
*                                                               *
* DOS_Error - Tests for DOS error condition                     *
*                                                               *
* INPUTS: None.                                                 *
* OUTPUT: d0 =  0 if no error occurred                          *
*              -1 if an error was detected                      *
*         Flags reflect output in d0                            *
*                                                               *
*****************************************************************

DOS_Error       movea.l dosbase(pc),a6
                jsr     IOErr(a6)               get status

                lea     ErrorTable(pc),a0
                lea     ErrorTitle(pc),a1
                clr.w   d1
1$              cmp.l   0(a0,d1.w),d0
                beq.s   2$
                addq.w  #4,d1
                cmpi.w  #ErrorTabSize,d1
                bne.s   1$
                clr.l   d0                      signal no error
                rts

2$              movea.l 0(a1,d1),a2             a2 = ptr to title
                move.l  intuitionbase(pc),a6
                move.l  #-1,a1                  no new window title
                move.l  windowptr(pc),a0
                jsr     SetWindowTitles(a6)
                move.l  screenptr(pc),a0
                jsr     DisplayBeep(a6)
                move.w  #60,Tickdelay           set delay for title redraw
                moveq   #-1,d0                  signal error
                rts

ErrorTable      dc.l    202,203,204,205,210,211,212,213
                dc.l    214,216,218,221,222,223,225,226
ErrorTabSize    equ     *-ErrorTable

ErrorTitle      dc.l    DosError202,DosError203,DosError204
                dc.l    DosError205,DosError210,DosError211
                dc.l    DosError212,DosError213,DosError214
                dc.l    DosError216,DosError218,DosError221
                dc.l    DosError222,DosError223,DosError225
                dc.l    DosError226

*****************************************************************
* DiskDir - loads the selected directory into a singly linked   *
*           list                                                *
*                                                               *
* INPUTS: a5 = address of requester requester                   *
*                                                               *
*****************************************************************

DiskDir         move.l  intuitionbase(pc),a6
                move.l  6(a5),a0                prop gadget ptr
                move.l  windowptr(pc),a1        
                suba.l  a2,a2                   
                move.l  #AUTOKNOB|FREEVERT,d0   
                clr.l   d1                      
                clr.l   d2                      
                move.l  #$ffff,d3               
                move.l  d3,d4
                jsr     ModifyProp(a6)          reset scroll bar
                lea     20(a5),a1               addr of path
                tst.b   (a1)                    is a path given?
                beq     FindDrives
                
                bsr     GadgetsOnOff
                movea.l windowptr(pc),a0
                bsr     SleepPointer
                
                move.l  execbase,a6
                moveq   #MEMF_PUBLIC,d1
                move.l  #260,d0
                jsr     AllocMem(a6)
                move.l  d0,FileInfo             allocate FileInfo structure
                beq     DirError2
                
                move.l  dosbase(pc),a6
                move.l  a5,d1
                addi.l  #20,d1                  path ptr
                move.l  #MODE_READ,d2
                jsr     Lock(a6)                find file
                move.l  d0,locksave
                beq.s   DirError                if not found

                move.l  d0,d1
                move.l  FileInfo(pc),d2         temporarily use the allocated
                move.l  d2,a2
                jsr     Info(a6)                RAM for InfoData structure

                move.l  4(a2),16(a5)            set unit number

                move.l  locksave(pc),d1
                move.l  FileInfo,d2
                jsr     Examine(a6)
                tst.l   d0
                beq.s   DirError1
                clr.w   (a5)                    reset entry count
DirLoop         move.l  locksave(pc),d1
                move.l  FileInfo(pc),d2
                jsr     ExNext(a6)              find next file
                tst.l   d0
                beq.s   DirError1
                
                addq.w  #1,(a5)                 increment #entries
                move.l  FileInfo(pc),a0
                move.l  4(a0),d1                DirEntryType
                lea     8(a0),a0                fname
                lea     2(a5),a2                list base
                bsr     InsertNode
                bsr     ListFnames
                bra.s   DirLoop

DirError1       move.l  locksave(pc),d1
                jsr     UnLock(a6)              remove lock structure

DirError        bsr     GadgetsOnOff
                bsr     ListFnames

                movea.l windowptr(pc),a0
                bsr     NormalPointer           re-enable normal pointer

DirError2       move.l  execbase,a6
                move.l  #260,d0
                move.l  FileInfo(pc),a1
                jsr     FreeMem(a6)

DirEnd          rts

*****************************************************************
*                                                               *
*   ListFnames - displays the contents of the given dir list    *
*                                                               *
* INPUTS: a5 = ptr to requester                                 *
*                                                               *
*****************************************************************

ListFnames      move.l  6(a5),a0        prop ptr
                move.w  12(a5),FnameXpos

ListFnames2     movem.l d4/a0-a6,-(a7)

                bsr     CalcPotPos
                move.l  d2,d0           top entry
                bsr     GotoEntry       locate entry (a2 = node)
                move.w  ReqSize(pc),d4  no. of rows in requester
                move.l  #REQ_TOP+2,d5
ListFloop       cmpa.l  #0,a2
                beq     ListFEnd_1
                bsr.s   PrFname
                add.l   #10,d5
                subq.w  #1,d4           check for requester filled
                beq.s   ListFEnd_2
ListContinue    move.l  (a2),a2         advance to next node
                bra.s   ListFloop       repeat for rest of directory entries

ListFEnd_1      movea.l graphicsbase(pc),a6
                move.l  WRastPort(pc),a1
                moveq   #BACKGRND,d0
                jsr     SetAPen(a6)     pen=background

                move.l  WRastPort(pc),a1
                move.w  12(a5),d0       x1 pos of rectangle
                move.w  d5,d1           y1 pos of rectangle
                move.w  d0,d2
                add.w   #REQ_WIDTH,d2   add width to form x2 pos
                move.w  Req_Bottom(pc),d3       y2 pos of rectangle
                jsr     RectFill(a6)    clear vacant positions

ListFEnd_2      movem.l (a7)+,d4/a0-a6
                rts

*****************************************************************
*                                                               *
* PrFname - Prints filename in directory list                   *
*                                                               *
* INPUTS: a2 = ptr to directory entry                           *
*         d5 = Ypos of filename entry                           *
*                                                               *
*****************************************************************

PrFname         move.b  116(a2),d0      select status
                ext.w   d0
                mulu    #5,d0
                move.b  d0,FnameBCol

                move.l  114(a2),d0      entry type
                rol.l   #1,d0           calc entry colour
                and.l   #1,d0
                mulu    #3,d0
                moveq   #4,d1
                sub.b   d0,d1
                move.b  d1,FnameIText           source colour
                move.w  d5,FnameYpos
                
                move.l  a2,d0
                addi.l  #4,d0           ptr to fname
                move.l  d0,FnamePtr

                move.l  WRastPort(pc),a0
                lea     FnameIText(pc),a1
                clr.l   d0
                clr.l   d1
                movea.l intuitionbase(pc),a6
                jsr     PrintIText(a6)
                rts     

*********************************************************
* ModProp                                               *
*                                                       *
* INPUTS: a5 = ptr to requester                         *
*                                                       *
*********************************************************

ModProp         movem.l d2-d4/a6,-(a7)
                move.l  intuitionbase(pc),a6
                move.l  6(a5),a0                ptr to gadget
                move.l  windowptr(pc),a1        ptr to window
                move.l  #0,a2                   no system requester
                move.l  #AUTOKNOB|FREEVERT,d0   flags
                clr.l   d1                      horizpot
                clr.l   d2                      vertpot
                move.l  #$ffff,d3               horizpot
                move.l  d3,d4
                move.w  (a5),d7                 #entries
                cmp.w   ReqSize(pc),d7
                ble.s   GoProp
                mulu.w  ReqSize(pc),d4  vertbody = (MAXBODYxReqSize)/no. entries
                divu    d7,d4
GoProp          jsr     ModifyProp(a6)
                movem.l (a7)+,d2-4/a6
                rts
                
FnameIText      dc.b    4
FnameBCol       dc.b    0,JAM2          
FnameXpos       dc.w    0
FnameYpos       dc.w    0
                dc.l    NULL
FnamePtr        dc.l    NULL,NULL

*****************************************************************
*       FindDrives -  Locate drives/mounted volumes             *
*                                                               *
* INPUTS: a5 = ptr to requester                                 *
*                                                               *
*****************************************************************
                
FindDrives      move.l  dosbase(pc),a0
                move.l  $22(a0),a0
                moveq   #$18,d0
                bsr     CalcBPTR
                moveq   #$04,d0
                bsr     CalcBPTR
                clr.w   (a5)            entry count
FDLoop          move.l  4(a0),d0        type (0 for DOS device)
                bne     FDLoop2         
                move.l  28(a0),d0       
                cmpi.l  #21,d0          dn_startup > 21 ?
                blt     FDCheck2
                bra     FDOutput
FDCheck2        move.l  a0,a1           check for RAM drive
                move.l  #40,d0
                bsr     CalcBPTR
                exg.l   a1,a0
                cmpi.l  #$0352414d,(a1) 'RAM' ?
                bne     FDContinue
                bra     FDOutput
FDLoop2         cmpi.l  #$02,d0         volume?
                bne     FDContinue
                tst.l   8(a0)           dl_task = 0? (ie.disk not mounted)
                beq     FDContinue
FDOutput        addq.w  #1,(a5)         increase total
                clr.l   d1              set entry type as a directory
                move.l  #40,d0          
                move.l  a0,-(a7)        push a0 onto stack
                bsr     CalcBPTR        a0 = ptr to filename
                lea     2(a5),a2
                bsr     InsertNode
                move.l  (a7)+,a0        pop a0 off stack
                
FDContinue      moveq   #0,d0
                bsr     CalcBPTR
                bne     FDLoop
                bsr     ListFnames
                rts

CalcBPTR        move.l  0(a0,d0.l),d0
                lsl.l   #2,d0
                move.l  d0,a0
                rts

CreateNode      movem.l d1/a0/a6,-(a7)  a0=ptr to fname, d1=EntryType
                move.l  #MEMF_PUBLIC,d1
                moveq   #NodeSize,d0
                move.l  execbase,a6
                jsr     AllocMem(a6)
                move.l  d0,a1
                adda.l  #4,a1 
                move.l  d0,a3
                movem.l (a7)+,d1/a0/a6
                clr.w   d0
                move.b  (a0),d0
                cmpi.w  #32,d0          check for BCPL string
                bge     normalstring    1st char ASCII (>32)?
                lea     1(a0),a0
                ext.w   d0
                move.w  d0,d2
                subq.w  #1,d0
                addq.w  #1,d2
                bsr     copydat
                move.b  #':',(a1)+
                move.w  d2,d0
                bra     fillname
normalstring    bsr     copyname
fillname        sub.w   #107,d0
                neg.w   d0
padname         move.b  #32,(a1)+
                dbf     d0,padname
                clr.b   34(a3)          set end of fname
                move.l  d1,(a1)+
                clr.w   (a1)            clear select flag
                rts

*****************************************************************
*                                                               *
* ClearList - Deallocates directory linked list                 *
*                                                               *
* INPUTS: a5 = address of requester                             *
*                                                               *
*****************************************************************

ClearList       lea     2(a5),a2
                movem.l a2/a6,-(a7)
                move.l  execbase,a6
                move.l  (a2),a2         locate 1st node
ClearList2      cmp.l   #0,a2
                beq     ClearEnd
                move.l  (a2),a3         a2=list base address

                move.l  a2,a1
                move.l  #NodeSize,d0
                jsr     FreeMem(a6)

                move.l  a3,a2
                bra     ClearList2              
ClearEnd        movem.l (a7)+,a2/a6
                clr.l   (a2)
                rts

InsertNode      bsr     CreateNode
InLoop          movea.l a2,a4           a4 = old node ptr
                movea.l (a2),a2
                cmpa.l  #0,a2
                beq     add_tail
                lea     4(a2),a0        current node name
                lea     4(a3),a1        new node name
                bsr     comparenames
                bmi     greater         str2>str1

                tst.l   112(a2)         current entry type
                bpl     InLoop
                tst.l   112(a3)         new node entry type
                bpl     InsNode
                bra     InLoop

greater         tst.l   112(a3)         new node entry type
                bpl     InsNode
                tst.l   112(a2)         current entry type
                bpl     InLoop

InsNode         move.l  a2,(a3)
                move.l  a3,(a4)
                rts
                
add_tail        move.l  a3,(a4)         set next node pointer
                clr.l   (a3)
                rts

*****************************************************************
*                                                               *
* ClearRequester - Clears the requester box                     *
*                                                               *
* INPUTS: a5 = address of requester                             *
*                                                               *
*****************************************************************

ClearRequester  move.l  a6,-(a7)
                move.l  graphicsbase(pc),a6
                move.l  WRastPort(pc),a1
                moveq   #0,d0                   pen=background
                jsr     SetAPen(a6)
                        
                move.l  WRastPort(pc),a1
                move.w  12(a5),d0               left xpos of req
                moveq   #REQ_TOP,d1             top ypos of req
                move.w  d0,d2
                add.w   #REQ_WIDTH,d2           add width
                move.w  Req_Bottom(pc),d3               
                jsr     RectFill(a6)
                move.l  (a7)+,a6
                rts

*****************************************************************
*                                                               *
* GetUnitName - This routine finds the associated unit name for *
*               a given unit number.  This routine is called    *
*               each time a disk is ejected, so that when a new *
*               disk is inserted, it is not referred to by the  *
*               previous disk's volume name.                    *
* INPUTS : d0 = unit number                                     *
* OUTPUTS: a0 = ptr to unit name BCPL string                    *
*                                                               *
*****************************************************************

GetUnitName     move.l  d0,d7           save unit number
                move.l  dosbase(pc),a0
                move.l  $22(a0),a0
                moveq   #$18,d0
                bsr     CalcBPTR
                moveq   #$04,d0
                bsr     CalcBPTR
                
GULoop          move.l  a0,a1
                tst.l   4(a0)           type (0 for DOS device)
                bne     GUContinue
                move.l  28(a0),d0       
                cmpi.l  #21,d0          dn_startup > 21 ?
                blt     GUContinue
                moveq   #28,d0
                bsr     CalcBPTR        point to startup_msg
                cmp.l   (a0),d7         fssm_unit
                bne     GUContinue

UnitFound       move.l  a1,a0
                moveq   #40,d0
                bsr     CalcBPTR        a0 = ptr to filename
                rts

GUContinue      move.l  a1,a0
                moveq   #0,d0
                bsr     CalcBPTR
                bne     GULoop
                suba.l  a0,a0           a0 = 0
                rts
                
locksave        dc.l    0
FileInfo        dc.l    0

*****************************************************************
*                                                               *
*                    Initialised data section                   *
*                                                               *
*****************************************************************

dos             dc.b    'dos.library',0
                even
dosbase         dc.l    0
intuition       dc.b    'intuition.library',0
                even
intuitionbase   dc.l    0
graphics        dc.b    'graphics.library',0
                even
graphicsbase    dc.l    0
trackdisk       dc.b    'trackdisk.device',0
                even
conname         dc.b    'con:0/20/640/170/*** Output Console ***',0
                even
conhandle       dc.l    0
EndCLI          dc.b    10,'endcli',0
WaitForPress    dc.b    10,'*** PRESS RETURN TO CONTINUE ***',10
WAITLENGTH      equ     *-WaitForPress
TempFile        dc.b    'ram:ArcTool.tmp',0
                even
ConfigFile      dc.b    's:ArcTool.config',0
                even
CharBuff        dc.b    0
                even
SpcChar         dc.b    32
Quote           dc.b    '"'
Slash           dc.b    '/'
                even
Wildcard        dc.b    '#?'
WILDCARDLENGTH  equ     *-Wildcard
                even
filehandle      dc.l    0       
UtilityName     dc.l    0
UtilityMode     dc.l    0
WBmessage       dc.l    0

****************** Macros for data generation *******************

ITEXT           macro                   intuitext macro
                dc.b    \1,\2,JAM1      frontpen,backpen,drawmode
                dc.w    \3,\4           xpos,ypos
                dc.l    NULL,\5,\6      textattr,textptr,nextitextptr
                endm

*****************************************************************

NewScreen       dc.w    0,0             x,y
                dc.w    640             width
ns_height       dc.w    256             height
                dc.w    3               depth
                dc.b    4,6             pen colours
                dc.w    HIRES           viewmode
                dc.w    CUSTOMSCREEN    type
                dc.l    ArcFont_attr    textattr for custom font
                dc.l    ScrTitle        screentitle
                dc.l    NULL            pointer to gadgets
                dc.l    NULL            bitmap pointer

ColorMap        dc.w    $045,$aaa,$777,$555,$fb0,$37b,$059,$028

ScrTitle        dc.b    '                    ArcTool V1.5 © by Tony Miceli 29/1/93 ',0
                even

NewWindow       dc.w    0,10                    x,y
                dc.w    640                     width
nw_height       dc.w    239                     height
                dc.b    2,1                     detail pens
                dc.l    GADGETDOWN|GADGETUP|DISKINSERTED|DISKREMOVED|MOUSEBUTTONS|INTUITICKS    IDCMP flags
                dc.l    ACTIVATE|BORDERLESS|RMBTRAP     window flags
                dc.l    NULL                    pointer to gadgets
                dc.l    NULL                    checkmark pointer
                dc.l    NULL                    pointer to window title
screenptr       dc.l    0                       pointer to custom screen
                dc.l    NULL                    bitmap pointer
                dc.w    584,132                 minwidth,minheight
                dc.w    584,132                 maxwidth,maxheight
                dc.w    CUSTOMSCREEN            screen type     

windowptr       dc.l    0
WRastPort       dc.l    0
message         dc.l    0

ErrorWindow     dc.w    120,40
                dc.w    400,100
                dc.b    4,1
                dc.l    GADGETUP
                dc.l    ACTIVATE|RMBTRAP        
ErrorGadgetptr  dc.l    0
                dc.l    NULL    
                dc.l    NULL    
screenptr2      dc.l    0       
                dc.l    NULL    
                dc.w    400,100 
                dc.w    400,100 
                dc.w    CUSTOMSCREEN

windowptr2      dc.l    0

***** General purpose window and accompanying continue gadget. *****

StdWindow       dc.w    20
stdwind_ypos    dc.w    20
stdwind_width   dc.w    600
stdwind_height  dc.w    160
                dc.b    0,0
                dc.l    GADGETUP|INTUITICKS
                dc.l    RMBTRAP|BORDERLESS|ACTIVATE
stdgadlist      dc.l    StdOKgadget
                dc.l    NULL    
                dc.l    NULL    
screenptr4      dc.l    0       
                dc.l    NULL    
                dc.w    600,160 
                dc.w    600,160 
                dc.w    CUSTOMSCREEN

Stdwindptr      dc.l    0

StdOKgadget     dc.l    NULL    
StdOKgadxpos    dc.w    266,-17,65,13
                dc.w    GADGIMAGE|GADGHIMAGE|RELBOTTOM,RELVERIFY,BOOLGADGET
                dc.l    GreyBoxOff,GreyBoxOn
OK_CANCEL_Itext dc.l    OKItext,NULL,NULL
OK_CANCEL_ID    dc.w    1               ;ok_ID = 1
                dc.l    NULL

StdCANCELgadget dc.l    StdOKgadget
                dc.w    385,-17,65,13
                dc.w    GADGIMAGE|GADGHIMAGE|RELBOTTOM,RELVERIFY,BOOLGADGET
                dc.l    GreyBoxOff,GreyBoxOn,CANCELItext,NULL,NULL
                dc.w    0               ;cancel_ID = 0
                dc.l    NULL

OKItext         ITEXT   1,0,16,3,OKtext,NULL
OKtext          dc.b    'OKAY',0
                even

CANCELItext     ITEXT   1,0,8,3,CANCELtext,NULL
CANCELtext      dc.b    'CANCEL',0

*****************************************************************

ConfigWindow    dc.w    120,60
                dc.w    400,60
                dc.b    4,1
                dc.l    0,ACTIVATE|BORDERLESS|RMBTRAP
                dc.l    NULL,NULL,NULL
screenptr5      dc.l    0,NULL
                dc.w    0,0,0,0,CUSTOMSCREEN

*** requester window text data ***

*** FORMAT:     dc.w    number of lines in screen
***             dc.w    ypos of window
***             dc.b    'title',0,[padding for word-alignment]
***             dc.w    xpos of line 'n'                ;repeated for
***             dc.b    'line n message',0,[padding]    ;'n' lines
*** Note: If the xpos or ypos values are given as zero, then the window
***       or text will be centred vertically (ypos=0) / horizontally (xpos=0)

*** Text data about program ***

AboutArcTool    dc.w    12,0
                dc.b    'About ArcTool Version 1.5',0
                even
                dc.w    0
                dc.b    'ArcTool is a graphical interface which makes using the various',0
                even
                dc.w    0
                dc.b    'CLI-driven archiving utilities easier and more efficient.',0
                even
                dc.w    0
                dc.b    'Written by Tony Miceli in 100% assembler and finished on ??/1/1993.',0
                even
                dc.w    0
                dc.b    'This program is SHAREWARE, and the version you are using now is an',0
                even
                dc.w    0
                dc.b    'unregistered version which has some features cut-down/disabled.',0
                even
                dc.w    0
                dc.b    'To register, send $10 Australia/$20 overseas to the following address:',0
                even
                dc.w    0
                dc.b    0
                even
                dc.w    0
                dc.b    'TONY MICELI',0
                even
                dc.w    0
                dc.b    'P.O. BOX 1083',0
                even
                dc.w    0
                dc.b    'CAMPBELLTOWN',0
                even
                dc.w    0
                dc.b    'NSW 2560',0
                even
                dc.w    0
                dc.b    'AUSTRALIA',0
                even

*** General screens ***

DeleteScreen    dc.w    2,0
                dc.b    'Deleting selected files, press CANCEL to abort',0
                even
                dc.w    0
                dc.b    'Deleteing ...',0
                even
                dc.w    0
                dc.b    0
                even

ProtectQuery    dc.w    2,0
                dc.b    'Program Request',0
                even
                dc.w    0
                dc.b    'File protected from deletion, still delete anyway?',0
                even
                dc.w    0
                dc.b    0
                even

DirQuery        dc.w    2,0
                dc.b    'Program Request',0
                even
                dc.w    0
                dc.b    'Directory not empty, still delete anyway?',0
                even
                dc.w    0
                dc.b    0
                even

*** Help window text data ***

ToolCycleHelp   dc.w    5,0
                dc.b    'Help on Archive Tool Cycle Gadget',0
                even
                dc.w    0
                dc.b    'This gadget is used to cycle through the list of',0
                even
                dc.w    0
                dc.b    'available archiving utilities.',0
                even
                dc.w    0
                dc.b    'This list can be altered by changing the program''s configuration',0
                even
                dc.w    0
                dc.b    'file (refer to the accompanying manual for information regarding',0
                even
                dc.w    0
                dc.b    'the format of the configuration file).',0
                even

OptionCycleHelp dc.w    5,0
                dc.b    'Help on Archive Option Cycle Gadget',0
                even
                dc.w    0
                dc.b    'This gadget is used to cycle through all the available',0
                even
                dc.w    0
                dc.b    'archiving functions provided by the currently selected archiving tool.',0
                even
                dc.w    0
                dc.b    'This list can be altered by changing the program''s configuration',0
                even
                dc.w    0
                dc.b    'file (refer to the accompanying manual for information regarding',0
                even
                dc.w    0
                dc.b    'the format of the configuration file).',0
                even

ArcPathStrHelp  dc.w    4,0
                dc.b    'Help on Archive Path Gadget',0
                even
                dc.w    0
                dc.b    'The full path where the archive or set of archives with which you',0
                even
                dc.w    0
                dc.b    'wish to perform a specified archiving operation is given here.',0
                even
                dc.w    0
                dc.b    'A path can be chosen by using the archive file requester, or it can',0
                even
                dc.w    0
                dc.b    'be entered directly here via the keyboard.',0
                even

FilePathStrHelp dc.w    4,0
                dc.b    'Help on Filenames Path Gadget',0
                even
                dc.w    0
                dc.b    'The full path where the set of files with which you wish to archive',0
                even
                dc.w    0
                dc.b    'is given here.',0
                even
                dc.w    0
                dc.b    'A path can be chosen by using the filenames requester, or it can',0
                even
                dc.w    0
                dc.b    'be entered directly here via the keyboard.',0
                even

ArcReqHelp      dc.w    8,0
                dc.b    'Help on Archive Requester box',0
                even
                dc.w    0
                dc.b    'This box intially contains all paths available to the file system.',0
                even
                dc.w    0
                dc.b    'A path can be selected by clicking the left mousebutton on the pathname.',0
                even
                dc.w    0
                dc.b    'Once a path has been chosen, the list of files',0
                even
                dc.w    0
                dc.b    'found in the path are listed in alphabetic order.',0
                even
                dc.w    0
                dc.b    'Files are listed in light-grey, while directories are listed in yellow.',0
                even
                dc.w    0
                dc.b    'A file or directory can be selected by clicking on it''s name, while',0
                even
                dc.w    0
                dc.b    'a directory may be entered by double-clicking on it''s name.',0
                even
                dc.w    0
                dc.b    'Pressing the right mousebutton will go back to path selection mode.',0
                even

FileReqHelp     dc.w    8,0
                dc.b    'Help on Filenames Requester box',0
                even
                dc.w    0
                dc.b    'This box intially contains all paths available to the file system.',0
                even
                dc.w    0
                dc.b    'A path can be selected by clicking the left mousebutton on the pathname.',0
                even
                dc.w    0
                dc.b    'Once a path has been chosen, the list of files',0
                even
                dc.w    0
                dc.b    'found in the path are listed in alphabetic order.',0
                even
                dc.w    0
                dc.b    'Files are listed in light-grey, while directories are listed in yellow.',0
                even
                dc.w    0
                dc.b    'A file or directory can be selected by clicking on it''s name, while',0
                even
                dc.w    0
                dc.b    'a directory may be entered by double-clicking on it''s name.',0
                even
                dc.w    0
                dc.b    'Pressing the right mousebutton will go back to path selection mode.',0
                even

Prop1Help       dc.w    7,0
                dc.b    'Help on Archive Slider Gadget',0
                even
                dc.w    0
                dc.b    'When there are more filenames in the archive path than can fit in the',0
                even
                dc.w    0
                dc.b    'archive requester box, this gadget is used to scroll through the',0
                even
                dc.w    0
                dc.b    'full list of available filenames.',0
                even
                dc.w    0
                dc.b    'To use this gadget, just hold down the left mousebutton and drag the',0
                even
                dc.w    0
                dc.b    'slider up and down.  The archives list will then scroll up or down.',0
                even
                dc.w    0
                dc.b    'Note that this gadget will have no effect if the archive file requester',0
                even
                dc.w    0
                dc.b    'can accommodate all of the files found in the current archive path.',0

Prop2Help       dc.w    7,0
                dc.b    'Help on Filenames Slider Gadget',0
                even
                dc.w    0
                dc.b    'When there are more filenames in the filenames path than can fit in the',0
                even
                dc.w    0
                dc.b    'filenames requester box, this gadget is used to scroll through the',0
                even
                dc.w    0
                dc.b    'full list of available filenames.',0
                even
                dc.w    0
                dc.b    'To use this gadget, just hold down the left mousebutton and drag the',0
                even
                dc.w    0
                dc.b    'slider up and down.  The filenames list will then scroll up or down.',0
                even
                dc.w    0
                dc.b    'Note that this gadget will have no effect if the file requester',0
                even
                dc.w    0
                dc.b    'can accommodate all of the files found in the current filenames path.',0

ArcNameStrHelp  dc.w    4,0
                dc.b    'Help on Archive Name Gadget',0
                even
                dc.w    0
                dc.b    'If you are creating an archive which does not yet exist on disk, then',0
                even
                dc.w    0
                dc.b    'you must enter the archive''s name here.',0
                even
                dc.w    0
                dc.b    'You can also select an archive which appears in the Archive Name',0
                even
                dc.w    0
                dc.b    'file requester by entering its name here.',0
                even

ArcCopyHelp     dc.w    4,0
                dc.b    'Help on Archive Copy Tool',0
                even
                dc.w    0
                dc.b    'The copy tool will copy all selcted files/directories in the archive',0
                even
                dc.w    0
                dc.b    'requester to the filenames requester box.',0
                even
                dc.w    0
                dc.b    'Note that this operation will only be performed if a valid path has',0
                even
                dc.w    0
                dc.b    'been chosen for both the archive and filenames requesters.',0
                even

ArcDeleteHelp   dc.w    4,0
                dc.b    'Help on Archive Delete Tool',0
                even
                dc.w    0
                dc.b    'The delete tool will delete all selected files/directories from',0
                even
                dc.w    0
                dc.b    'the archive requester.',0
                even
                dc.w    0
                dc.b    'A valid path must be selected for the archive requester or this function',0
                even
                dc.w    0
                dc.b    'will not be performed. Also, files that are protected will not be deleted.',0
                even

ArcMakeDirHelp  dc.w    3,0
                dc.b    'Help on Archive MakeDir Tool',0
                even
                dc.w    0
                dc.b    'The makedir tool will create a new directory in the archive requester.',0
                even
                dc.w    0
                dc.b    'The user will be prompted for a name to give the directory.',0
                even
                dc.w    0
                dc.b    'Note that a valid path must be selcted for this operation to be performed.',0
                even

ArcParentHelp   dc.w    5,0
                dc.b    'Help on Archive Parent Gadget',0
                even
                dc.w    0
                dc.b    'The parent tool will move the archive requester to the',0
                even
                dc.w    0
                dc.b    'parent of the current archive path.',0
                even
                dc.w    0
                dc.b    'If the requester is currently at a root directory, then it',0
                even
                dc.w    0
                dc.b    'will change back to path selection mode.',0
                even
                dc.w    0
                dc.b    'Note that a path must already be chosen for this gadget to have an effect.',0
                even

FileCopyHelp    dc.w    4,0
                dc.b    'Help on Filenames Copy Tool',0
                even
                dc.w    0
                dc.b    'The copy tool will copy all selcted files/directories in the filenames',0
                even
                dc.w    0
                dc.b    'requester to the archive requester box.',0
                even
                dc.w    0
                dc.b    'Note that this operation will only be performed if a valid path has',0
                even
                dc.w    0
                dc.b    'been chosen for both the archive and filenames requesters.',0
                even

FileDeleteHelp  dc.w    4,0
                dc.b    'Help on Filenames Delete Tool',0
                even
                dc.w    0
                dc.b    'The delete tool will delete all selected files/directories from',0
                even
                dc.w    0
                dc.b    'the filenames requester.',0
                even
                dc.w    0
                dc.b    'A valid path must be selected for the filenames requester or this function',0
                even
                dc.w    0
                dc.b    'will not be performed. Also, files that are protected will not be deleted.',0
                even

FileMakeDirHelp dc.w    3,0
                dc.b    'Help on Filenames MakeDir Tool',0
                even
                dc.w    0
                dc.b    'The makedir tool will create a new directory in the filenames requester.',0
                even
                dc.w    0
                dc.b    'The user will be prompted for a name to give the directory.',0
                even
                dc.w    0
                dc.b    'Note that a valid path must be selcted for this operation to be performed.',0
                even

FileParentHelp  dc.w    5,0
                dc.b    'Help on Filnames Parent Gadget',0
                even
                dc.w    0
                dc.b    'The parent tool will move the filenames requester to the',0
                even
                dc.w    0
                dc.b    'parent of the current filenames path.',0
                even
                dc.w    0
                dc.b    'If the requester is currently at a root directory, then it',0
                even
                dc.w    0
                dc.b    'will change back to path selection mode.',0
                even
                dc.w    0
                dc.b    'Note that a path must already be chosen for this gadget to have an effect.',0
                even

ArchiveHelp     dc.w    7,0
                dc.b    'Help on Archive Gadget',0
                even
                dc.w    0
                dc.b    'When the archive gadget is activated, the program will attempt to',0
                even
                dc.w    0
                dc.b    'perform the selected archiving operation by executing the archiving',0
                even
                dc.w    0
                dc.b    'utility shown in the Archive Tool box.',0
                even
                dc.w    0
                dc.b    'If not enough information (eg. Archive/filename paths) has been given,',0
                even
                dc.w    0
                dc.b    'the user will be notified and the operation will not be performed.',0
                even
                dc.w    0
                dc.b    'In order to perform the operation, the program opens a console to',0
                even
                dc.w    0
                dc.b    'display the output given by the executing archiving utility.',0
                even

HelpAbout       dc.w    5,0
                dc.b    'About Help',0
                even
                dc.w    0
                dc.b    'You are currently in HELP mode.',0
                even
                dc.w    0
                dc.b    'To deactivate HELP mode, click once more on the HELP button.',0
                even
                dc.w    0
                dc.b    'If you want information on a particular item on the screen,',0
                even
                dc.w    0
                dc.b    'just click on it (while still in HELP mode, of course).',0
                even
                dc.w    0
                dc.b    'A window like this one will appear with information on the item.',0
                even

ExitHelp        dc.w    1,0
                dc.b    'Help on Exit Gadget',0
                even
                dc.w    0
                dc.b    'The exit gadget is used to terminate execution of the program.',0
                
*** Error window text data ***

ArcNameError    dc.w    3,0
                dc.b    'ERROR: No Archive Path Chosen.',0
                even
                dc.w    0
                dc.b    'An archive path MUST be chosen before an archive name can be selected.',0
                even
                dc.w    0
                dc.b    'Click on the required path in the file requester, then enter the',0
                even
                dc.w    0
                dc.b    'archive name here (if required).',0
                even

NoDelNames      dc.w    2,0
                dc.b    'ERROR: No files chosen for deletion.',0
                even
                dc.w    0
                dc.b    'The delete operation could not be performed as no files were selected.',0
                even
                dc.w    0
                dc.b    'Select the files to delete in the appropriate requester box.',0
                even

NoDelPath       dc.w    2,0
                dc.b    'ERROR: No path specified for delete operation.',0
                even
                dc.w    0
                dc.b    'A path must be specified for the delete operation to be performed.',0
                even
                dc.w    0
                dc.b    'In addition, some files/directories must be marked for deletion.',0
                even

*** rectangles for various displays (PAL mode) ***

*** FORMAT:     dc.w    no. of rectangles
***             dc.w    x1, y1, x2, y2, pen     repeated n times

PAL_rectangles  dc.w    11
                dc.w    29,3,609,188+50,MD_BLUE         ;main window
                dc.w    37,7,314,41,MD_GREY             ;archive tool box
                dc.w    46,11,305,20,MD_BLUE
                dc.w    324,7,601,41,MD_GREY            ;archive option box
                dc.w    333,11,592,20,MD_BLUE
                dc.w    37,44,314,184+50,MD_GREY        ;archive requester
                dc.w    46,48,305,57,MD_BLUE
                dc.w    ARC_REQ_LEFT,REQ_TOP,ARC_REQ_RIGHT,144+50,BACKGRND
                dc.w    324,44,601,184+50,MD_GREY       ;filename requester
                dc.w    333,48,592,57,MD_BLUE
                dc.w    FILE_REQ_LEFT,REQ_TOP,FILE_REQ_RIGHT,144+50,BACKGRND

NTSC_rect_fix   dc.w    8,58,78,88,108
NTSC_fix_len    equ     *-NTSC_rect_fix

Stdwindrects    dc.w    1
                dc.w    0,0,600
StdRectY        dc.w    160,MD_BLUE

*** borders for various displays (PAL mode) ***

*** FORMAT:     dc.w    no. of borders
***             dc.w    xpos, ypos, width, height, pen1, pen2 ;repeat n times

PAL_borders     dc.w    20
                dc.w    29,3,580,185+50,LT_BLUE,DK_BLUE ;main window
                dc.w    37,7,277,34,LT_GREY,DK_GREY     ;archive tool box
                dc.w    46,11,259,9,DK_GREY,LT_GREY
                dc.w    46,23,259,14,DK_GREY,LT_GREY
                dc.w    324,7,277,34,LT_GREY,DK_GREY    ;archive option box
                dc.w    333,11,259,9,DK_GREY,LT_GREY
                dc.w    333,23,259,14,DK_GREY,LT_GREY
                dc.w    38,163+50,276,1,DK_GREY,LT_GREY ;archive requester
                dc.w    37,44,277,140+50,LT_GREY,DK_GREY
                dc.w    46,48,259,9,DK_GREY,LT_GREY
                dc.w    46,60,259,9,DK_GREY,LT_GREY
                dc.w    46,72,243,73+50,DK_GREY,LT_GREY
                dc.w    46,149+50,259,9,DK_GREY,LT_GREY
                dc.w    42,166+50,267,16,DK_GREY,LT_GREY
                dc.w    325,163+50,276,1,DK_GREY,LT_GREY ;filename requester
                dc.w    324,44,277,140+50,LT_GREY,DK_GREY
                dc.w    333,48,259,9,DK_GREY,LT_GREY
                dc.w    333,60,259,9,DK_GREY,LT_GREY
                dc.w    349,72,243,73+50,DK_GREY,LT_GREY
                dc.w    329,166+50,267,16,DK_GREY,LT_GREY

NTSC_border_fix dc.w    8,88,104,140,148,160,172,188,224,232
NTSC_bfix_len   equ     *-NTSC_border_fix

Stdwindbords    dc.w    3
                dc.w    0,15,599,1,DK_BLUE,LT_BLUE      ;upper horizontal bar
                dc.w    0
StdWindY1       dc.w    0,599,1,DK_BLUE,LT_BLUE         ;lower horizontal bar
                dc.w    0,0,599
StdWindY4       dc.w    0,LT_BLUE,DK_BLUE               ;border around window

Stdgadboxes1    dc.w    1
                dc.w    262
StdWindY2       dc.w    0,72,16,DK_BLUE,LT_BLUE         ;box around gadget

Stdgadboxes2    dc.w    2
                dc.w    146
Std2WindY2      dc.w    0,72,16,DK_BLUE,LT_BLUE         ;box around OK gadget
                dc.w    381
Std2WindY3      dc.w    0,72,16,DK_BLUE,LT_BLUE         ;box around CANCEL

*** intuition text structures ***

Intuitext1      ITEXT   4,0,129,12,Text1,Intuitext2
Text1           dc.b    'Archive Tool',0
                even

Intuitext2      ITEXT   4,0,129,49,Text2,Intuitext3
Text2           dc.b    'Archive Name',0
                even

Intuitext3      ITEXT   4,0,407,12,Text3,Intuitext4
Text3           dc.b    'Archive Option',0
                even

Intuitext4      ITEXT   4,0,428,49,Text4,NULL
Text4           dc.b    'Filenames',0
                even

DiskText        dc.b    2,0,JAM1
                dc.w    0,0
                dc.l    NULL,RemIText,NULL
RemIText        dc.b    'Disk Removed.',0
                even

*** change this to a progrequester soon!!! ***

errorItext      dc.b    4,0,JAM1
                dc.w    14,56
                dc.l    NULL
errortextptr    dc.l    0
                dc.l    NULL
ConfigIError    dc.b    4,0,JAM1
                dc.w    0,0
                dc.l    NULL
ConfigErrorPtr  dc.l    0,NULL

errortext1      dc.b    'The selected function requres an archive name.',0
                even
errortext2      dc.b    ' This function requires one or more filenames.',0
                even
errortext3      dc.b    '      No file path has been selected.',0
                even
errortext4      dc.b    '     No archive path has been selected.',0
                even
errortext5      dc.b    ' Illegal command found in configuration file.',0
                even
errortext6      dc.b    '     Filename path must be a floppy unit.',0
                even
errortext7      dc.b    '  Fatal Error: Couldn''t find ''s:ArcTool.config''',0
                even
errortext8      dc.b    '       Fatal Error: Unexpected end of file',0
                even

*** DOS error descriptions ***

DosError202     dc.b    '                     AmigaDOS Error 202: Object in use           ',0
                even
DosError203     dc.b    '                 AmigaDOS Error 203: Object already exists       ',0
                even
DosError204     dc.b    '                  AmigaDOS Error 204: Directory not found        ',0
                even
DosError205     dc.b    '                    AmigaDOS Error 205: Object not found         ',0
                even
DosError210     dc.b    '              AmigaDOS Error 210: Invalid stream component name  ',0
                even
DosError211     dc.b    '                   AmigaDOS Error 211: Invalid object lock       ',0
                even
DosError212     dc.b    '               AmigaDOS Error 212: Object not of required type   ',0
                even
DosError213     dc.b    '                   AmigaDOS Error 213: Disk not validated        ',0
                even
DosError214     dc.b    '                  AmigaDOS Error 214: Disk write-protected       ',0
                even
DosError216     dc.b    '                   AmigaDOS Error 216: Directory not empty       ',0
                even
DosError218     dc.b    '                   AmigaDOS Error 218: Device not mounted        ',0
                even
DosError221     dc.b    '                       AmigaDOS Error 221: Disk full             ',0
                even
DosError222     dc.b    '           AmigaDOS Error 222: File is protectected from deletion',0
                even
DosError223     dc.b    '             AmigaDOS Error 223: File is protected from writing  ',0
                even
DosError225     dc.b    '                     AmigaDOS Error 225: Not a DOS disk          ',0
                even
DosError226     dc.b    '                    AmigaDOS Error 226: No disk in drive         ',0
                even

*************** Gadget Definition Section ***************

GADGET_ID       set     0               gadget ID for intuition events

GADGET          macro                   gadget declaration macro
                
                dc.l    NULL            next gadget in list
                dc.w    \1,\2,\3,\4,\5  x,y,width,height,flags
                dc.w    \6,\7           activation,type
                dc.l    \8,\9,\A        image1,image2,itext
                dc.l    NULL,\B         mutual exclude,special info
                dc.w    GADGET_ID       gadgetID
                dc.l    NULL            user info
                
GADGET_ID       set     GADGET_ID+1     increment gadget ID

                endm

STD_FLAGS       equ     GADGIMAGE|GADGHIMAGE    standard gadget flags

ToolCyclegad    GADGET  48,24,29,13,STD_FLAGS,RELVERIFY,BOOLGADGET,CycleOff,CycleOn,NULL,NULL
OptionCyclegad  GADGET  335,24,29,13,STD_FLAGS,RELVERIFY,BOOLGADGET,CycleOff,CycleOn,NULL,NULL

Exitgad         GADGET  528,-20,65,13,STD_FLAGS|RELBOTTOM,RELVERIFY,BOOLGADGET,BlueBoxOff,BlueBoxOn,Exitgadtext,NULL
Exitgadtext     ITEXT   1,0,17,3,Exitgtext,NULL
Exitgtext       dc.b    'EXIT',0
                even

Aboutgad        GADGET  463,-20,65,13,STD_FLAGS|RELBOTTOM,RELVERIFY,BOOLGADGET,BlueBoxOff,BlueBoxOn,Aboutgadtext,NULL
Aboutgadtext    ITEXT   1,0,13,3,Aboutgtext,NULL
Aboutgtext      dc.b    'ABOUT',0
                even

Helpgad         GADGET  398,-20,65,13,STD_FLAGS|RELBOTTOM,RELVERIFY|TOGGLESELECT,BOOLGADGET,BlueBoxOff,BlueBoxOn,Helpgadtext,NULL
Helpgadtext     ITEXT   1,0,17,3,Helpgtext,NULL
Helpgtext       dc.b    'HELP',0
                even

Archivegad      GADGET  333,-20,65,13,STD_FLAGS|RELBOTTOM,RELVERIFY,BOOLGADGET,BlueBoxOff,BlueBoxOn,gadg4text,NULL
gadg4text       ITEXT   1,0,5,3,g4text,NULL
g4text          dc.b    'ARCHIVE',0
                even

ArcPathStrgad   GADGET  48,61,256,8,NULL,RELVERIFY|GADGIMMEDIATE,STRGADGET,NULL,NULL,NULL,ArcPathStrinfo
ArcPathStrinfo  dc.l    ArcPath         pointer to I/O buffer
                dc.l    UndoBuffer      pointer to undo buffer
                dc.w    0               char pos in buffer
                dc.w    255             max no. of chars
                dc.w    0,0             first char in display & undo buffer
ArcPathlen      dc.w    0               num of chars currently in buffer
                dc.w    0,0,0           calculated by intuition
                dc.l    NULL            no rastport
                dc.l    NULL            not a longint
                dc.l    NULL            use standard keymap

FilesPathStrgad GADGET  335,61,256,8,NULL,RELVERIFY|GADGIMMEDIATE,STRGADGET,NULL,NULL,NULL,FilePathStrinfo
FilePathStrinfo dc.l    FilePath        pointer to I/O buffer
                dc.l    UndoBuffer      pointer to undo buffer
                dc.w    0               char pos in buffer
                dc.w    255             max no. of chars
                dc.w    0,0             first char in display & undo buffer
FilePathlen     dc.w    0               num of chars currently in buffer
                dc.w    0,0,0           calculated by intuition
                dc.l    NULL            no rastport
                dc.l    NULL            not a longint
                dc.l    NULL            use standard keymap

Prop1Gadget     GADGET  293,72,13,59+50,GADGIMAGE,GADGIMMEDIATE,PROPGADGET,prop1,NULL,NULL,PropInfo1
PropInfo1       dc.w    AUTOKNOB|FREEVERT       flags
                dc.w    0,0                     horizpot,vertpot
                dc.w    $ffff,$ffff             horizbody,vertbody
                dc.w    0,0,0,0,0,0             system usage

Prop2Gadget     GADGET  333,72,13,59+50,GADGIMAGE,GADGIMMEDIATE,PROPGADGET,prop2,NULL,NULL,PropInfo2
PropInfo2       dc.w    AUTOKNOB|FREEVERT       flags
                dc.w    0,0                     horizpot,vertpot
                dc.w    $ffff,$ffff             horizbody,vertbody
                dc.w    0,0,0,0,0,0             system usage

FileGadget      GADGET  48,-38,256,8,RELBOTTOM,RELVERIFY|GADGIMMEDIATE,STRGADGET,NULL,NULL,NULL,FileGadgetStr
FileGadgetStr   dc.l    File            pointer to I/O buffer
                dc.l    UndoBuffer      pointer to undo buffer
                dc.w    0               char pos in buffer
                dc.w    33              max no. of chars
                dc.w    0,0             first char in display & undo buffer
Filelen         dc.w    0               num of chars currently in buffer
                dc.w    0,0,0           calculated by intuition
                dc.l    NULL            no rastport
                dc.l    NULL            not a longint
                dc.l    NULL            use standard keymap

ArcMakedirgad   GADGET  176,-20,65,13,STD_FLAGS|RELBOTTOM,RELVERIFY,BOOLGADGET,GreyBoxOff,GreyBoxOn,ArcMdgadtext,NULL
ArcMdgadtext    ITEXT   1,0,5,3,ArcMdgtext,NULL
ArcMdgtext      dc.b    'MAKEDIR',0
                even

ArcParentgad    GADGET  241,-20,65,13,STD_FLAGS|RELBOTTOM,RELVERIFY,BOOLGADGET,GreyBoxOff,GreyBoxOn,ArcParenttext,NULL
ArcParenttext   ITEXT   1,0,9,3,ArcParentgtext,NULL
ArcParentgtext  dc.b    'PARENT',0
                even

ArcDeletegad    GADGET  111,-20,65,13,STD_FLAGS|RELBOTTOM,RELVERIFY,BOOLGADGET,GreyBoxOff,GreyBoxOn,ArcDeletetext,NULL
ArcDeletetext   ITEXT   1,0,9,3,ArcDeletegtext,NULL
ArcDeletegtext  dc.b    'DELETE',0
                even

ArcCopygad      GADGET  46,-20,65,13,STD_FLAGS|RELBOTTOM,RELVERIFY,BOOLGADGET,GreyBoxOff,GreyBoxOn,ArcCopytext,NULL
ArcCopytext     ITEXT   1,0,17,3,ArcCopygtext,NULL
ArcCopygtext    dc.b    'COPY',0
                even

FilesMakedirgad GADGET  463,-40,65,13,STD_FLAGS|RELBOTTOM,RELVERIFY,BOOLGADGET,GreyBoxOff,GreyBoxOn,ArcMdgadtext,NULL
FilesParentgad  GADGET  528,-40,65,13,STD_FLAGS|RELBOTTOM,RELVERIFY,BOOLGADGET,GreyBoxOff,GreyBoxOn,ArcParenttext,NULL
FilesDeletegad  GADGET  398,-40,65,13,STD_FLAGS|RELBOTTOM,RELVERIFY,BOOLGADGET,GreyBoxOff,GreyBoxOn,ArcDeletetext,NULL
FilesCopygad    GADGET  333,-40,65,13,STD_FLAGS|RELBOTTOM,RELVERIFY,BOOLGADGET,GreyBoxOff,GreyBoxOn,ArcCopytext,NULL
ArcArrowUpgad   GADGET  293,-56,13,7,STD_FLAGS|RELBOTTOM,RELVERIFY|GADGIMMEDIATE,BOOLGADGET,UpArrowOff,UpArrowOn,NULL,NULL
ArcArrowDngad   GADGET  293,-49,13,7,STD_FLAGS|RELBOTTOM,RELVERIFY|GADGIMMEDIATE,BOOLGADGET,DnArrowOff,DnArrowOn,NULL,NULL
FileArrowUpgad  GADGET  333,-56,13,7,STD_FLAGS|RELBOTTOM,RELVERIFY|GADGIMMEDIATE,BOOLGADGET,UpArrowOff,UpArrowOn,NULL,NULL
FileArrowDngad  GADGET  333,-49,13,7,STD_FLAGS|RELBOTTOM,RELVERIFY|GADGIMMEDIATE,BOOLGADGET,DnArrowOff,DnArrowOn,NULL,NULL

_MAX_GADGET     equ     GADGET_ID

*** remove this soon !!! ***

skullgadget     dc.l    error1gadget
                dc.w    15,5,85,39
                dc.w    GADGHNONE|GADGIMAGE
                dc.w    RELVERIFY
                dc.w    BOOLGADGET
                dc.l    skull,NULL,skullItext,NULL,NULL
                dc.w    1
                dc.l    NULL

***

QDiskGadget     dc.l    QMarkGadget
                dc.w    15,8,61,29
                dc.w    GADGHNONE|GADGIMAGE
                dc.w    RELVERIFY
                dc.w    BOOLGADGET
                dc.l    Disk,NULL
DiskTextptr     dc.l    skullItext,NULL,NULL
                dc.w    1
                dc.l    NULL

QMarkGadget     dc.l    error1gadget            
                dc.w    85,13,24,19
                dc.w    GADGHNONE|GADGIMAGE,RELVERIFY,BOOLGADGET
                dc.l    QMark,NULL,NULL,NULL,NULL
                dc.w    2
                dc.l    NULL

EDiskGadget     dc.l    EMarkGadget
                dc.w    15,8,61,29
                dc.w    GADGHNONE|GADGIMAGE,RELVERIFY,BOOLGADGET
                dc.l    Disk,NULL,skullItext,NULL,NULL
                dc.w    1
                dc.l    NULL

EMarkGadget     dc.l    error1gadget
                dc.w    85,13,14,19
                dc.w    GADGHNONE|GADGIMAGE,RELVERIFY,BOOLGADGET
                dc.l    EMark,NULL,NULL,NULL,NULL
                dc.w    2
                dc.l    NULL
                
*** remove this stuff soon !!! ***

skullItext      ITEXT   1,0,105,15,skulltext,NULL
skulltext       dc.b    'A user error has occurred!',0
                even

error1gadget    dc.l    NULL    
                dc.w    304,80,65,13
                dc.w    GADGHCOMP|GADGIMAGE|GADGHIMAGE
                dc.w    RELVERIFY
                dc.w    BOOLGADGET
                dc.l    GreyBoxOff,GreyBoxOn,OKItext,NULL,NULL
                dc.w    0
                dc.l    NULL

***

ConfigItext     ITEXT   1,0,83,15,Configtext,NULL
Configtext      dc.b    'Reading configuration, please wait ...',0
                even

*** File requester structures used by the program ***
*** FORMAT:  0  dc.w    No_Entries      ;# entries in dir list
*            2  dc.l    List_Base       ;base addr of dir linked list
*            6  dc.l    PropGadget_ptr  ;ptr to prop gadget for req
*            10 dc.w    Disk_Inserted   ;disk inserted detection flag
*            12 dc.w    Left_Edge       ;left xpos of requester box
*            14 dc.w    Old_YPot        ;old slider y position
*            16 dc.l    Unit_No         ;disk unit number for req
*            20 dc.b    Path_String[255];name of path for requester

ArcRequester    
ArcEntries      dc.w    0
ArcBase         dc.l    0
                dc.l    Prop1Gadget
ArcDiskIn       dc.w    0
                dc.w    ARC_REQ_LEFT
OldArcYPot      dc.w    0
                dc.l    0
ArcPath         dcb.b   255,0
                even

FileRequester   
FileEntries     dc.w    0
FileBase        dc.l    0
                dc.l    Prop2Gadget
FileDiskIn      dc.w    0
                dc.w    FILE_REQ_LEFT
OldFileYPot     dc.w    0
FileUnitNo      dc.l    0
FilePath        dcb.b   255,0
                even

ReqMode         dc.w    0
DirLevel        dc.w    0
OldReqAddr      dc.l    0
OldFileNo       dc.w    0
Seconds         dc.l    0       for left mouse double-click
Micros          dc.l    0
Tickdelay       dc.w    0       for title error message displaying
ReqSize         dc.w    12
Req_Bottom      dc.w    144+50
DiskYPos        dc.w    69+40
InitialSP       dc.l    0
NTSC            dc.b    0
DirEntered      dc.b    0
NotDeleted      dc.b    0
                even

File            dcb.b   33,0
                even
UndoBuffer      dcb.b   255,0
                even
CopyBuffer      dcb.b   255,0
                even
CopyBuffer2     dcb.b   255,0
                even
SourcePath      dcb.b   255,0   used by copy/delete functions
                even
DestPath        dcb.b   255,0   used by copy function
                even
DeletePath      dcb.b   255,0   used by delete function
                even

diskio          dcb.l   20,0
readreply       dcb.l   8,0
diskbuff        dc.l    0
CLIcommand      dc.b    'failat 60000',10,'execute ram:arctool.tmp',10,'endcli',0
                even

*** Font used by program ***

                include 'ArcTool_Code_Disk:Source/ArcToolfont.asm'

*****************************************************************
*                                                               *
* Image structures used for gadgets and other graphics          *
*       NB. This data MUST be loaded to chipRAM!                *
*                                                               *
*****************************************************************

                section GraphicData,data_c

CycleOff        dc.w    0,0,29,13,3
                dc.l    CycleOffdat
                dc.b    7,0
                dc.l    0
CycleOffdat     dc.w    65535,65528,49152,00024,49152,00024,49152,00024
                dc.w    49152,00024,49152,00024,49152,00024,49152,00024
                dc.w    49152,00024,49152,00024,49152,00024,49152,00024
                dc.w    65535,65528
                dc.w    00000,00008,16383,65528,16320,08184,16287,53240
                dc.w    16383,53240,16287,19448,16143,34808,16023,53240
                dc.w    16287,65528,16287,53240,16320,08184,16383,65528
                dc.w    32767,65528
                dc.w    65535,65528,65535,65528,65535,65528,65535,65528
                dc.w    65535,65528,65535,65528,65535,65528,65535,65528
                dc.w    65535,65528,65535,65528,65535,65528,65535,65528
                dc.w    65535,65528
                
CycleOn         dc.w    0,0,29,13,3
                dc.l    CycleOndat
                dc.b    7,0
                dc.l    0
CycleOndat      dc.w    65535,65528,49152,00024,49152,00024,49152,00024
                dc.w    49152,00024,49152,00024,49152,00024,49152,00024
                dc.w    49152,00024,49152,00024,49152,00024,49152,00024
                dc.w    65535,65528
                dc.w    65535,65520,49152,00000,49152,00000,49152,00000
                dc.w    49152,00000,49152,00000,49152,00000,49152,00000
                dc.w    49152,00000,49152,00000,49152,00000,49152,00000
                dc.w    32768,00000
                dc.w    65535,65528,49152,00024,49215,57368,49248,12312
                dc.w    49152,12312,49248,46104,49392,30744,49512,12312
                dc.w    49248,00024,49248,12312,49215,57368,49152,00024
                dc.w    65535,65528

BlueBoxOff      dc.w    0,0,65,13,3
                dc.l    BlueBoxOffdat
                dc.b    7,0
                dc.l    0
BlueBoxOffdat   dc.w    65535,65535,65535,65535,32768,49152,00000,00000
                dc.w    00001,32768,49152,00000,00000,00001,32768,49152
                dc.w    00000,00000,00001,32768,49152,00000,00000,00001
                dc.w    32768,49152,00000,00000,00001,32768,49152,00000
                dc.w    00000,00001,32768,49152,00000,00000,00001,32768
                dc.w    49152,00000,00000,00001,32768,49152,00000,00000
                dc.w    00001,32768,49152,00000,00000,00001,32768,49152
                dc.w    00000,00000,00001,32768,65535,65535,65535,65535
                dc.w    32768
                dc.w    00000,00000,00000,00000,32768,16383,65535,65535
                dc.w    65535,32768,16383,65535,65535,65535,32768,16383
                dc.w    65535,65535,65535,32768,16383,65535,65535,65535
                dc.w    32768,16383,65535,65535,65535,32768,16383,65535
                dc.w    65535,65535,32768,16383,65535,65535,65535,32768
                dc.w    16383,65535,65535,65535,32768,16383,65535,65535
                dc.w    65535,32768,16383,65535,65535,65535,32768,16383
                dc.w    65535,65535,65535,32768,32767,65535,65535,65535
                dc.w    32768
                dc.w    65535,65535,65535,65535,32768,65535,65535,65535
                dc.w    65535,32768,65535,65535,65535,65535,32768,65535
                dc.w    65535,65535,65535,32768,65535,65535,65535,65535
                dc.w    32768,65535,65535,65535,65535,32768,65535,65535
                dc.w    65535,65535,32768,65535,65535,65535,65535,32768
                dc.w    65535,65535,65535,65535,32768,65535,65535,65535
                dc.w    65535,32768,65535,65535,65535,65535,32768,65535
                dc.w    65535,65535,65535,32768,65535,65535,65535,65535
                dc.w    32768

BlueBoxOn       dc.w    0,0,65,13,3
                dc.l    BlueBoxOndat
                dc.b    7,0
                dc.l    0
BlueBoxOndat    dc.w    65535,65535,65535,65535,32768,49152,00000,00000
                dc.w    00001,32768,49152,00000,00000,00001,32768,49152
                dc.w    00000,00000,00001,32768,49152,00000,00000,00001
                dc.w    32768,49152,00000,00000,00001,32768,49152,00000
                dc.w    00000,00001,32768,49152,00000,00000,00001,32768
                dc.w    49152,00000,00000,00001,32768,49152,00000,00000
                dc.w    00001,32768,49152,00000,00000,00001,32768,49152
                dc.w    00000,00000,00001,32768,65535,65535,65535,65535
                dc.w    32768
                dc.w    65535,65535,65535,65535,00000,49152,00000,00000
                dc.w    00000,00000,49152,00000,00000,00000,00000,49152
                dc.w    00000,00000,00000,00000,49152,00000,00000,00000
                dc.w    00000,49152,00000,00000,00000,00000,49152,00000
                dc.w    00000,00000,00000,49152,00000,00000,00000,00000
                dc.w    49152,00000,00000,00000,00000,49152,00000,00000
                dc.w    00000,00000,49152,00000,00000,00000,00000,49152
                dc.w    00000,00000,00000,00000,32768,00000,00000,00000
                dc.w    00000
                dc.w    65535,65535,65535,65535,32768,49152,00000,00000
                dc.w    00001,32768,49152,00000,00000,00001,32768,49152
                dc.w    00000,00000,00001,32768,49152,00000,00000,00001
                dc.w    32768,49152,00000,00000,00001,32768,49152,00000
                dc.w    00000,00001,32768,49152,00000,00000,00001,32768
                dc.w    49152,00000,00000,00001,32768,49152,00000,00000
                dc.w    00001,32768,49152,00000,00000,00001,32768,49152
                dc.w    00000,00000,00001,32768,65535,65535,65535,65535
                dc.w    32768

GreyBoxOff      dc.w    0,0,65,13,3
                dc.l    GreyBoxOffdat
                dc.b    %00000011,0
                dc.l    0
GreyBoxOffdat   dc.w    65535,65535,65535,65535,32768,49152,00000,00000
                dc.w    00001,32768,49152,00000,00000,00001,32768,49152
                dc.w    00000,00000,00001,32768,49152,00000,00000,00001
                dc.w    32768,49152,00000,00000,00001,32768,49152,00000
                dc.w    00000,00001,32768,49152,00000,00000,00001,32768
                dc.w    49152,00000,00000,00001,32768,49152,00000,00000
                dc.w    00001,32768,49152,00000,00000,00001,32768,49152
                dc.w    00000,00000,00001,32768,65535,65535,65535,65535
                dc.w    32768
                dc.w    00000,00000,00000,00000,32768,16383,65535,65535
                dc.w    65535,32768,16383,65535,65535,65535,32768,16383
                dc.w    65535,65535,65535,32768,16383,65535,65535,65535
                dc.w    32768,16383,65535,65535,65535,32768,16383,65535
                dc.w    65535,65535,32768,16383,65535,65535,65535,32768
                dc.w    16383,65535,65535,65535,32768,16383,65535,65535
                dc.w    65535,32768,16383,65535,65535,65535,32768,16383
                dc.w    65535,65535,65535,32768,32767,65535,65535,65535
                dc.w    32768

GreyBoxOn       dc.w    0,0,65,13,3
                dc.l    GreyBoxOndat
                dc.b    %00000011,0
                dc.l    0
GreyBoxOndat    dc.w    65535,65535,65535,65535,32768,49152,00000,00000
                dc.w    00001,32768,49152,00000,00000,00001,32768,49152
                dc.w    00000,00000,00001,32768,49152,00000,00000,00001
                dc.w    32768,49152,00000,00000,00001,32768,49152,00000
                dc.w    00000,00001,32768,49152,00000,00000,00001,32768
                dc.w    49152,00000,00000,00001,32768,49152,00000,00000
                dc.w    00001,32768,49152,00000,00000,00001,32768,49152
                dc.w    00000,00000,00001,32768,65535,65535,65535,65535
                dc.w    32768
                dc.w    65535,65535,65535,65535,00000,49152,00000,00000
                dc.w    00000,00000,49152,00000,00000,00000,00000,49152
                dc.w    00000,00000,00000,00000,49152,00000,00000,00000
                dc.w    00000,49152,00000,00000,00000,00000,49152,00000
                dc.w    00000,00000,00000,49152,00000,00000,00000,00000
                dc.w    49152,00000,00000,00000,00000,49152,00000,00000
                dc.w    00000,00000,49152,00000,00000,00000,00000,49152
                dc.w    00000,00000,00000,00000,32768,00000,00000,00000
                dc.w    00000

UpArrowOff      dc.w    0,0,13,7,3
                dc.l    UpArrowOffdat
                dc.b    7,0
                dc.l    0
UpArrowOffdat   dc.w    65528,49176,49688,50968,53144,49176,65528
                dc.w    00008,16376,16376,16376,16376,16376,32760
                dc.w    00000,00000,00000,00000,00000,00000,00000

UpArrowOn       dc.w    0,0,13,7,3
                dc.l    UpArrowOndat
                dc.b    7,0
                dc.l    0
UpArrowOndat    dc.w    65528,49176,49688,50968,53144,49176,65528
                dc.w    65520,49152,49664,50944,53120,49152,32768
                dc.w    00000,00000,00000,00000,00000,00000,00000

DnArrowOff      dc.w    0,0,13,7,3
                dc.l    DnArrowOffdat
                dc.b    7,0
                dc.l    0
DnArrowOffdat   dc.w    65528,49176,53144,50968,49688,49176,65528
                dc.w    00008,16376,16376,16376,16376,16376,32760
                dc.w    00000,00000,00000,00000,00000,00000,00000

DnArrowOn       dc.w    0,0,13,7,3
                dc.l    DnArrowOndat
                dc.b    7,0
                dc.l    0
DnArrowOndat    dc.w    65528,49176,53144,50968,49688,49176,65528
                dc.w    65520,49152,53120,50944,49664,49152,32768
                dc.w    00000,00000,00000,00000,00000,00000,00000

;;;;;;;;;;;;;;; remove this !!!

skull           dc.w    0,0,85,39,3
                dc.l    skulldat
                dc.b    %00000011,0
                dc.l    0
skulldat        dc.w    00007,64512,00000,00000,00000,00000,00031,65024
                dc.w    32767,32771,63488,00000,00063,65408,32767,32783
                dc.w    65024,00000,00063,65503,65535,64543,65280,00000
                dc.w    00511,65535,65535,65423,65472,00000,16383,65535
                dc.w    65535,65519,65504,00000,65535,65535,65535,65535
                dc.w    65535,00000,65535,65535,65535,65535,65535,49152
                dc.w    65535,65535,65535,65535,65535,57344,65535,65535
                dc.w    65535,65535,65535,63488,65535,65535,65535,65535
                dc.w    65535,63488,16383,65535,65535,65535,65535,63488
                dc.w    08191,65535,65535,65535,65535,63488,02047,65535
                dc.w    65535,65535,65535,63488,00254,16380,01023,00511
                dc.w    65535,57344,00000,16381,50175,50175,63615,00000
                dc.w    00000,08184,02044,02047,49152,00000,00000,08188
                dc.w    16380,16383,49152,00000,00000,08191,65535,65535
                dc.w    32768,00000,00000,02047,65279,65535,32768,00000
                dc.w    00000,02047,65535,65535,32768,00000,00000,00511
                dc.w    65503,65535,00000,00000,00000,00255,65503,65535
                dc.w    00000,00000,00000,01023,65535,65532,00000,00000
                dc.w    00000,04095,65535,65535,08160,00000,00510,16383
                dc.w    65535,65535,65532,00000,04095,65535,65535,65535
                dc.w    65534,00000,08191,65535,63487,65535,65535,32768
                dc.w    08191,65535,62463,65535,65535,49152,16383,65535
                dc.w    65535,65535,65535,49152,08191,65535,65535,65407
                dc.w    65535,57344,04095,65535,65535,65535,65535,57344
                dc.w    01023,65520,32767,64767,65535,32768,00511,65520
                dc.w    32767,64767,65532,00000,00015,65528,02047,49407
                dc.w    64512,00000,00000,65528,00000,00127,64512,00000
                dc.w    00000,16376,00000,00031,61440,00000,00000,08184
                dc.w    00000,00015,57344,00000,00000,02032,00000,00000
                dc.w    00000,00000
                dc.w    00000,00000,00000,00000,00000,00000,00000,00000
                dc.w    00000,00000,00000,00000,00000,00384,00000,00000
                dc.w    00000,00000,00000,00448,00000,00000,00000,00000
                dc.w    00000,00384,00000,00000,00192,00000,00000,00000
                dc.w    00000,00000,00000,00000,00000,00000,00000,00016
                dc.w    00000,00000,00000,00000,00000,00000,00000,00000
                dc.w    00000,00000,00000,00000,00000,08192,00000,00000
                dc.w    00000,00000,00000,14336,00000,00000,00000,00000
                dc.w    00000,14336,00001,32768,00000,00000,00000,14336
                dc.w    06159,49183,63495,64512,00000,63488,02047,49183
                dc.w    63495,64512,15367,63488,00254,00060,00031,00001
                dc.w    65535,57344,00000,00028,00030,00001,63615,00000
                dc.w    00000,00000,00004,00003,49152,00000,00000,00004
                dc.w    14340,14339,49152,00000,00000,00000,00000,00003
                dc.w    32768,00000,00000,00000,00192,00007,32768,00000
                dc.w    00000,00000,00448,00007,32768,00000,00000,00000
                dc.w    00960,00063,00000,00000,00000,00000,00512,00015
                dc.w    00000,00000,00000,00000,00000,00000,00000,00000
                dc.w    00000,00000,00000,00000,00000,00000,00000,00000
                dc.w    16385,32768,00000,00000,00000,00000,24579,32768
                dc.w    00000,00000,00000,00000,14334,00000,00001,32768
                dc.w    00000,00000,13310,01536,00000,49152,00000,00024
                dc.w    00000,01920,00000,49152,00000,00124,00000,07936
                dc.w    00003,57344,00000,00124,00000,07936,00031,57344
                dc.w    00896,00048,16385,64512,08191,32768,00504,00048
                dc.w    32767,64512,08188,00000,00014,00056,02047,49152
                dc.w    31744,00000,00000,00056,00000,00000,64512,00000
                dc.w    00000,00120,00000,00031,61440,00000,00000,08184
                dc.w    00000,00015,57344,00000,00000,02032,00000,00000
                dc.w    00000,00000

Disk            dc.w    0,0,61,29,3
                dc.l    Diskdat
                dc.b    7,0
                dc.l    0
Diskdat         dc.w    00515,65535,65535,32768,00515,65535,32831,32768
                dc.w    00515,65535,32831,32768,00515,65535,32831,32768
                dc.w    00515,65535,32831,32768,00515,65535,32831,32768
                dc.w    00515,65535,32831,32768,00515,65535,32831,32768
                dc.w    00515,65535,32831,32768,00769,65535,65535,32768
                dc.w    00511,65535,65535,00000,00000,00000,00000,00000
                dc.w    00000,00000,00000,00000,00000,00000,00000,00000
                dc.w    00511,65535,65535,64512,00511,65535,65535,64512
                dc.w    00511,65535,65535,64512,00511,65535,65535,64512
                dc.w    00511,65535,65535,64512,00511,65535,65535,64512
                dc.w    00511,65535,65535,64512,00511,65535,65535,64512
                dc.w    00511,65535,65535,64512,00511,65535,65535,64512
                dc.w    00511,65535,65535,64512,00511,65535,65535,64512
                dc.w    00511,65535,65535,64512,00511,65535,65535,64512
                dc.w    00511,65535,65535,64512
                dc.w    65020,00000,00000,32704,65020,00000,32704,32736
                dc.w    65020,00000,32704,32752,65020,00000,32704,32760
                dc.w    65020,00000,32704,32760,65020,00000,32704,32760
                dc.w    65020,00000,32704,32760,65020,00000,32704,32760
                dc.w    65020,00000,32704,32760,64766,00000,00000,32760
                dc.w    65024,00000,00000,65528,65535,65535,65535,65528
                dc.w    65535,65535,65535,65528,65535,65535,65535,65528
                dc.w    65024,00000,00000,01016,65024,00000,00000,01016
                dc.w    65535,65535,65535,65528,65024,00000,00000,01016
                dc.w    65024,00000,00000,01016,65535,65535,65535,65528
                dc.w    65024,00000,00000,01016,65024,00000,00000,01016
                dc.w    65535,65535,65535,65528,65024,00000,00000,01016
                dc.w    65024,00000,00000,01016,33791,65535,65535,65528
                dc.w    33791,65535,65535,65528,65535,65535,65535,65528
                dc.w    65535,65535,65535,65528
                dc.w    65532,00000,00000,65472,65532,00000,32704,65504
                dc.w    65532,00000,32704,65520,65532,00000,32704,65528
                dc.w    65532,00000,32704,65528,65532,00000,32704,65528
                dc.w    65532,00000,32704,65528,65532,00000,32704,65528
                dc.w    65532,00000,32704,65528,65534,00000,00001,65528
                dc.w    65535,65535,65535,65528,65535,65535,65535,65528
                dc.w    65535,65535,65535,65528,65535,65535,65535,65528
                dc.w    65535,65535,65535,65528,65535,65535,65535,65528
                dc.w    65535,65535,65535,65528,65535,65535,65535,65528
                dc.w    65535,65535,65535,65528,65535,65535,65535,65528
                dc.w    65535,65535,65535,65528,65535,65535,65535,65528
                dc.w    65535,65535,65535,65528,65535,65535,65535,65528
                dc.w    65535,65535,65535,65528,33791,65535,65535,65528
                dc.w    33791,65535,65535,65528,65535,65535,65535,65528
                dc.w    65535,65535,65535,65528

;;;;;;;;;;;;;;; remove these 2 !!!

QMark           dc.w    0,0,24,19,3
                dc.l    QMarkdat
                dc.b    %00000100,0
                dc.l    0
QMarkdat        dc.w    00255,00000,04095,61440,16383,64512,32767,65024
                dc.w    65535,65280,65475,65280,32641,65280,16135,65024
                dc.w    00063,63488,00127,49152,00127,32768,00127,32768
                dc.w    00127,32768,00063,00000,00000,00000,00063,00000
                dc.w    00127,32768,00127,32768,00063,00000

EMark           dc.w    0,0,14,19,3
                dc.l    EMarkdat
                dc.b    %00000100,0
                dc.l    0
EMarkdat        dc.w    04032,16368,32760,65532,65532,65532,65532,32760
                dc.w    16368,16368,08160,08160,08160,04032,00000,04032
                dc.w    08160,08160,04032

*** Data for program defined mouse pointers ***

*** FORMAT:     dc.w    col1,col2,col3
;               dc.w    ptr_width,ptr_height,xoffset,yoffset
;               dc.w    pointer data ...

*** General mouse pointer:

GeneralPointer  dc.w    $0f00,$0000,$0f80
                dc.w    16,10,-1,0
                dc.w    $0000,$0000
                dc.w    $8000,$0000,$6000,$0000
                dc.w    $7800,$0000,$3e00,$8000
                dc.w    $3800,$4000,$1400,$6800
                dc.w    $1200,$2800,$0100,$3400 
                dc.w    $0000,$1200,$0000,$1100

HelpPointer     dc.w    $0f00,$0000,$0f80
                dc.w    16,19,-1,0
                dc.w    $0000,$0000
                dc.w    $8000,$0000,$6000,$0000
                dc.w    $7800,$0000,$3e00,$8000
                dc.w    $3800,$4000,$1400,$6800
                dc.w    $1200,$2800,$0138,$3438
                dc.w    $0044,$1244,$0044,$1144
                dc.w    $0004,$003c,$0008,$004c
                dc.w    $0010,$0054,$0010,$0014
                dc.w    $0000,$0008,$0010,$0010
                dc.w    $0000,$0010,$0000,$0000
                dc.w    $0000,$0010

Sleep_Pointer   dc.w    $0f00,$0000,$0999
                dc.w    16,18,-5,0
                dc.w    $0000,$0000
                dc.w    $0000,$7f00,$0000,$8080
                dc.w    $0000,$8080,$0000,$8080
                dc.w    $0000,$8080,$3600,$7700
                dc.w    $3e00,$7f00,$1c00,$3e00
                dc.w    $0800,$1c00,$0000,$1400
                dc.w    $0000,$2200,$0800,$4900
                dc.w    $0000,$4100,$0800,$8880
                dc.w    $1c00,$9c80,$3e00,$be80
                dc.w    $0000,$7f00,$0000,$0000
                dc.w    $ffff,$ffff

prop1           dc.w    0,0,10,8,3
                dc.l    NULL
                dc.b    7,0
                dc.l    0

prop2           dc.w    0,0,10,8,3
                dc.l    NULL
                dc.b    7,0
                dc.l    0

