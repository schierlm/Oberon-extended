MODULE Run;  (*Run standalone programs M.rsc or pre-linked binaries M.bin / AP 14.3.20 Extended Oberon*)
  IMPORT SYSTEM, Files, Modules, Texts, Oberon, ORL;
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

  PROCEDURE RunRsc*;  (*extract, load and execute code section of standalone program  M.rsc*)
    VAR len, entry, res: INTEGER;
      body: Modules.Command;
      F: Files.File;
      S: Texts.Scanner;
  BEGIN GetArg(S); Texts.WriteString(W, "Run.RunRsc ");
    IF S.class = Texts.Name THEN (*name of object file*)
      Texts.WriteString(W, S.s); Texts.Append(Oberon.Log, W.buf);
      ORL.Extract(S.s, code, len, entry, res);  (*extract code section from M.rsc*)
      IF res = ORL.noerr THEN Texts.WriteString(W, " done");
        body := SYSTEM.VAL(Modules.Command, SYSTEM.ADR(code) + entry); body
      ELSIF res = ORL.nofile THEN Texts.WriteString(W, " failed")
      ELSIF res = ORL.badfile THEN Texts.WriteString(W, " input file format error")
      ELSIF res = ORL.nospace THEN Texts.WriteString(W, " program too long")
      END ;
      EndLine
    END
  END RunRsc;

  PROCEDURE RunBin*;  (*load and execute pre-linked binary  M.bin*)
    VAR newStart, i, x: INTEGER;
      start: Modules.Command;
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
          ORL.Relocate(bin, newStart); Texts.WriteString(W, " done");
          start := SYSTEM.VAL(Modules.Command, newStart); start (*branch to initialization body of top module*)
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
