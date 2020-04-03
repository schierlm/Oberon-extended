MODULE Input; (*NW 5.10.86 / 15.11.90 Ceres-2; PDR 21.4.12 / NW 15.5.2013 Ceres-4 / AP 9.3.20 Extended Oberon*)
  IMPORT SYSTEM;

  CONST msAdr = -40; kbdAdr = -36; timerAdr = -64;
   (*ascii codes*) NUL* = 0X; BS* = 08X; TAB* = 09X; LF* = 0AX; CR* = 0DX; SUB* = 1AX; ESC* = 1BX; SPC* = 20X; DEL* = 7FX;
   (*text control*) CtrlA* = 1X; CtrlC* = 03X; CtrlV* = 16X; CtrlX* = 18X;
   (*cursor keys*) CursorLeft* = 11X; CursorRight* = 12X; CursorUp* = 13X; CursorDown* = 14X;

  VAR kbdCode, MW, MH: INTEGER;
    Recd: BOOLEAN;

  PROCEDURE Peek();
  BEGIN
    IF SYSTEM.BIT(msAdr, 28) THEN
      SYSTEM.GET(kbdAdr, kbdCode);
      kbdCode := kbdCode DIV 1000000H;
      Recd := TRUE
    END;
  END Peek;

  PROCEDURE Available*(): INTEGER;
  BEGIN Peek();
    RETURN ORD(Recd)
  END Available;

  PROCEDURE Read*(VAR ch: CHAR);
  BEGIN
    WHILE ~Recd DO Peek() END ;
    ch := CHR(kbdCode);
    Recd := FALSE
  END Read;

  PROCEDURE Mouse*(VAR keys: SET; VAR x, y: INTEGER);
    VAR w: INTEGER;
  BEGIN SYSTEM.GET(msAdr, w);
    keys := SYSTEM.VAL(SET, w DIV 1000000H MOD 8);
    x := w MOD 1000H; y := (w DIV 1000H) MOD 1000H;
    IF x >= MW THEN x := MW-1 END;
    IF y >= MH THEN y := MH-1 END
  END Mouse;

  PROCEDURE SetMouseLimits*(w, h: INTEGER);
  BEGIN MW := w; MH := h
  END SetMouseLimits;

  PROCEDURE WaitForInput*(untilTimestamp: INTEGER);
  BEGIN
    SYSTEM.PUT(timerAdr, untilTimestamp)
  END WaitForInput;

BEGIN Recd := FALSE
END Input.
