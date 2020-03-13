MODULE Run; (*AP 13.3.20 Run standalone programs M.rsc or pre-linked binaries M.bin / Extended Oberon*)
  IMPORT SYSTEM, Kernel, Files, Modules, Texts, Oberon;
  CONST maxCode = 8000; maxBin = 8000; LNK = 15; TrapAdr = 04H;
    MOV = 40000000H; IOR = 40060000H;  (*F1 register instructions*)
    C4 = 10H; C16 = 10000H; C20 = 100000H; C28 = 10000000H; U = 20000000H; (*modifier bit*)

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
  BEGIN GetArg(S);
    Texts.WriteString(W, "System.RunRsc ");
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

  PROCEDURE Trap1(VAR a: INTEGER; b, c, d: INTEGER);  (*trap routine installed by RunBin*)
    VAR u, v, w: INTEGER;
  BEGIN u := SYSTEM.REG(LNK); SYSTEM.GET(u - 4, v); w := v DIV 10H MOD 10H; (*trap number*)
    LED(w + 192); REPEAT UNTIL FALSE
  END Trap1;

  PROCEDURE RunBin*;  (*load and execute pre-linked binary  M.bin*)
    VAR Start, binStart, i, x, y, im: INTEGER;
      M, p: Modules.Module;
      body: Modules.Command;
      F: Files.File; R: Files.Rider;
      S: Texts.Scanner;
  BEGIN GetArg(S);
    Texts.WriteString(W, "System.RunBin ");
    IF S.class = Texts.Name THEN (*name of binary file*)
      Texts.WriteString(W, S.s); Texts.Append(Oberon.Log, W.buf);
      F := Files.Old(S.s);
      IF F # NIL THEN
        IF Files.Length(F) < maxBin * 4 THEN
          Files.Set(R, F, 8); Files.ReadInt(R, binStart);
          Files.Set(R, F, 0); Files.ReadInt(R, x); i := 0;
          WHILE ~R.eof DO bin[i] := x; INC(i); Files.ReadInt(R, x) END ;
          Texts.WriteInt(W, i*4, 6); (*bytes*) Texts.Append(Oberon.Log, W.buf);
          Start := SYSTEM.ADR(bin);
          p := SYSTEM.VAL(Modules.Module, Start + bin[5]); (*current root of the links of loaded  modules / root*)
          WHILE p # NIL DO (*fixup*) M := p;
            IF M.next # NIL THEN M.next := SYSTEM.VAL(Modules.Module, SYSTEM.VAL(INTEGER, M.next) - binStart + Start) END ;
            p := M.next;
            M.data := M.data - binStart + Start;
            M.code := M.code - binStart + Start;
            M.imp := M.imp - binStart + Start;
            i := M.code;
            WHILE i < M.imp DO SYSTEM.GET(i, x);
              IF (x DIV C28 * C28 = MOV+U) & (x DIV C20 MOD C4 = 1) THEN (*fixed up MOV+U+B instruction*)
                SYSTEM.GET(i+4, y); im := x MOD C16 * C16 + y MOD C16 - binStart + Start; (*relocate*)
                SYSTEM.PUT(i, x DIV C16 * C16 + im DIV C16);
                SYSTEM.PUT(i+4, y DIV C16 * C16 + im MOD C16); INC(i, 4)
              END ;
              INC(i, 4)
            END ;
            M.cmd := M.cmd - binStart + Start;
            i := M.imp;
            WHILE i < M.cmd DO SYSTEM.GET(i, x); SYSTEM.PUT(i, x - binStart + Start); INC(i, 4) END ;
            M.ent := M.ent - binStart + Start;
            M.ptr := M.ptr - binStart + Start;
            M.pvr := M.pvr - binStart + Start
          END ;
          Kernel.Install(SYSTEM.ADR(Trap1), Start + TrapAdr); (*install trap*)
          body := SYSTEM.VAL(Modules.Command, Start); body (*call initialization body of the top module*)
        ELSE Texts.WriteString(W, " program too long")
        END
      ELSE Texts.WriteString(W, " failed")
      END ;
      EndLine
    END
  END RunBin;

BEGIN Texts.OpenWriter(W)
END Run.
