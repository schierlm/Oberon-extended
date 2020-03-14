MODULE Run; (*AP 13.3.20 Run standalone programs M.rsc or pre-linked binaries M.bin / Extended Oberon*)
  IMPORT SYSTEM, Files, Modules, Texts, Oberon;
  CONST maxCode = 8000; maxBin = 8000; StartAdr = 8; RootAdr = 20;
    U = 20000000H; B = 1; (*modifier bit*)
    MOV = 40000000H; IOR = 40060000H; (*F1 register instructions*)
    BC = 0E7000000H; (*F3 branch instruction*)
    C4 = 10H; C16 = 10000H; C20 = 100000H; C28 = 10000000H;

  VAR code: ARRAY maxCode OF LONGINT;
    bin: ARRAY maxBin OF INTEGER;
    W: Texts.Writer;

  PROCEDURE GetArg(VAR S: Texts.Scanner);
    VAR T: Texts.Text; beg, end, time: LONGINT;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF (S.class = Texts.Char) & (S.c = "^") THEN
      Oberon.GetSelection(T, beg, end, time);
      IF time >= 0 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END
    END
  END GetArg;

  PROCEDURE EndLine;
  BEGIN Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END EndLine;

  PROCEDURE ExtractCode(F: Files.File; VAR code: ARRAY OF LONGINT; VAR codelen, entry, res: INTEGER);
    VAR n, data: INTEGER; ch: CHAR; b: BYTE;               (*codelen in words, entry in bytes*)
      R: Files.Rider;
      name: ARRAY 32 OF CHAR;
  BEGIN Files.Set(R, F, 0); Files.ReadString(R, name); Files.ReadInt(R, data); (*key*)
    Files.ReadByte(R, b); (*version*) Files.ReadInt(R, data); (*size*)
    Files.ReadString(R, name); (*imports*)
    WHILE name[0] # 0X DO Files.ReadInt(R, data); (*key*) Files.ReadString(R, name) END ;
    Files.ReadInt(R, n); (*variable space*)
    Files.ReadInt(R, n); Files.Set(R, F, Files.Pos(R) + n); (*strings*)
    Files.ReadInt(R, n); Files.Set(R, F, Files.Pos(R) + n*4); (*type descriptors*)
    Files.ReadInt(R, codelen);
    IF codelen > LEN(code) THEN res := Modules.nospace
    ELSE n := 0;
      WHILE n < codelen DO Files.ReadInt(R, data); code[n] := data; INC(n) END ; (*code*)
      Files.ReadString(R, name);
      WHILE name[0] # 0X DO Files.ReadInt(R, data); Files.ReadString(R, name) END ; (*commands*)
      Files.ReadInt(R, n); Files.Set(R, F, Files.Pos(R) + n*4); (*entries*)
      Files.ReadInt(R, data);
      WHILE data >= 0 DO Files.ReadInt(R, data) END ; (*pointer references*)
      Files.ReadInt(R, data);
      WHILE data >= 0 DO Files.ReadInt(R, data) END ; (*procedure variable references*)
      Files.ReadInt(R, data); (*fixorgP*) Files.ReadInt(R, data); (*fixorgD*)
      Files.ReadInt(R, data); (*fixorgT*) Files.ReadInt(R, data); (*fixorgM*)
      Files.ReadInt(R, entry);
      Files.Read(R, ch);
      IF ch # "O" THEN res := Modules.badfile ELSE res := Modules.noerr END
    END
  END ExtractCode;

  PROCEDURE RunRsc*;  (*extract, load and execute code section of standalone program  M.rsc*)
    VAR codelen, entry, res: INTEGER;
      body: Modules.Command;
      F: Files.File;
      S: Texts.Scanner;
  BEGIN GetArg(S); Texts.WriteString(W, "Run.RunRsc ");
    IF S.class = Texts.Name THEN (*name of object file*)
      Texts.WriteString(W, S.s); Texts.Append(Oberon.Log, W.buf);
      F := Files.Old(S.s);
      IF F # NIL THEN ExtractCode(F, code, codelen, entry, res);
        IF res = Modules.noerr THEN Texts.WriteString(W, " done");
          body := SYSTEM.VAL(Modules.Command, SYSTEM.ADR(code) + entry); body
        ELSIF res = Modules.badfile THEN Texts.WriteString(W, " input file format error")
        ELSIF res = Modules.nospace THEN Texts.WriteString(W, " program too long")
        END
      ELSE Texts.WriteString(W, " failed")
      END ;
      EndLine
    END
  END RunRsc;

  PROCEDURE RelocateBin(VAR bin: ARRAY OF LONGINT; newStart: INTEGER; VAR res: INTEGER);
    VAR Start, oldStart, p, i, j, x, y, im: INTEGER;
      M: Modules.Module;
  BEGIN Start := SYSTEM.ADR(bin); oldStart := bin[StartAdr DIV 4]; bin[StartAdr DIV 4] := newStart;
    p := bin[RootAdr DIV 4] - oldStart + Start;  (*current root of the links of loaded modules*)
    WHILE p # 0 DO (*fixup*)
      M := SYSTEM.VAL(Modules.Module, p);
      IF M.next # NIL THEN p := SYSTEM.VAL(INTEGER, M.next) - oldStart + Start;
        M.next := SYSTEM.VAL(Modules.Module, SYSTEM.VAL(INTEGER, M.next) - oldStart + newStart)
      ELSE p := 0
      END ;
      M.data := M.data - oldStart + newStart;
      i := M.code;
      WHILE i < M.imp DO j := i - oldStart + Start; SYSTEM.GET(j, x);
        IF (x DIV C28 * C28 = MOV+U) & (x DIV C20 MOD C4 = B) THEN  (*this MOV+U instruction has been fixed up*)
          SYSTEM.GET(j+4, y); im := x MOD C16 * C16 + y MOD C16 - oldStart + newStart;  (*relocate its operand*)
          SYSTEM.PUT(j, x DIV C16 * C16 + im DIV C16);
          SYSTEM.PUT(j+4, y DIV C16 * C16 + im MOD C16); INC(i, 4)
        END ;
        INC(i, 4)
      END ;
      M.code := M.code - oldStart + newStart;
      i := M.imp;
      WHILE i < M.cmd DO j := i - oldStart + Start; SYSTEM.GET(j, x); SYSTEM.PUT(j, x - oldStart + newStart); INC(i, 4) END ;
      M.imp := M.imp - oldStart + newStart;
      M.cmd := M.cmd - oldStart + newStart;
      M.ent := M.ent - oldStart + newStart;
      M.ptr := M.ptr - oldStart + newStart;
      M.pvr := M.pvr - oldStart + newStart
    END ;
    res := Modules.noerr
  END RelocateBin;

  PROCEDURE RunBin*;  (*load and execute pre-linked binary  M.bin*)
    VAR newStart, i, x, res: INTEGER;
      body: Modules.Command;
      F: Files.File; R: Files.Rider;
      S: Texts.Scanner;
  BEGIN GetArg(S); Texts.WriteString(W, "Run.RunBin ");
    IF S.class = Texts.Name THEN (*name of binary file*)
      Texts.WriteString(W, S.s); Texts.Append(Oberon.Log, W.buf);
      F := Files.Old(S.s);
      IF F # NIL THEN
        IF Files.Length(F) < maxBin * 4 THEN
          Files.Set(R, F, 0); Files.ReadInt(R, x); i := 0;
          WHILE ~R.eof DO bin[i] := x; INC(i); Files.ReadInt(R, x) END ; (*read pre-linked binary M.bin from file*)
          newStart := SYSTEM.ADR(bin);
          RelocateBin(bin, newStart, res);
          IF res = Modules.noerr THEN Texts.WriteString(W, " done");
            body := SYSTEM.VAL(Modules.Command, newStart); body (*branch to initialization body of top module*)
          ELSE Texts.WriteString(W, " failed")
          END
        ELSE Texts.WriteString(W, " program too long")
        END
      ELSE Texts.WriteString(W, " failed")
      END ;
      EndLine
    END
  END RunBin;

BEGIN Texts.OpenWriter(W)
END Run.

ORP.Compile Run.Mod/s ~

ORP.Compile M.Mod/s ~   # generate M.rsc
ORL.Link M ~            # generate M.bin

Run.RunRsc M.rsc ~      # execute code section of M.rsc
Run.RunBin M.bin ~      # execute pre-linked binary M.bin
