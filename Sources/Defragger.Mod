MODULE Defragger;
  IMPORT SYSTEM, Kernel, Disk, FileDir, DefragFiles, Display, Fonts;

  CONST FileInfoPerSector = 28;

  TYPE
    FileInfoSector = RECORD
      names: ARRAY FileInfoPerSector OF FileDir.FileName;
      count, firstSector, sector, filler: INTEGER;
      lengths: ARRAY FileInfoPerSector OF INTEGER;
    END;

  VAR fileInfo: FileInfoSector;

  PROCEDURE DrawText(text: ARRAY OF CHAR; x, y: INTEGER);
  VAR
    dx, xx, yy, t1, t2, patAdr, i: INTEGER;
  BEGIN
    i := 0;
    WHILE text[i] # 0X DO
      Fonts.GetPat(Fonts.Default, text[i], dx, xx, yy, t1, t2, patAdr);
      Display.CopyPattern(Display.white, patAdr, x + xx, y + yy, Display.replace);
      INC(x, dx);
      INC(i)
    END
  END DrawText;

  PROCEDURE ShowRestartMessage;
  BEGIN
    Display.ReplConst(Display.white, 20, 20, 170, 30, Display.replace);
    Display.ReplConst(Display.black, 22, 22, 166, 26, Display.replace);
    DrawText("Defrag finished. Please restart.", 30, 30);
    Kernel.Install(SYSTEM.ADR(ShowRestartMessage), 0);
    REPEAT SYSTEM.PUT(-64, Kernel.Time() + 1000) UNTIL FALSE
  END ShowRestartMessage;

  PROCEDURE Trim*;
  BEGIN Disk.TrimAllSectorsAfter(Disk.LastUsedSector())
  END Trim;

  PROCEDURE EnumAll(name: FileDir.FileName; adr: LONGINT; VAR cont: BOOLEAN);
    VAR len: INTEGER;
  BEGIN
    DefragFiles.Old(name); len := DefragFiles.Length(); DefragFiles.Close();
    fileInfo.names[fileInfo.count] := name;
    fileInfo.lengths[fileInfo.count] := len;
    INC(fileInfo.count);
    IF fileInfo.count = FileInfoPerSector THEN
      Disk.PutSector(fileInfo.sector, fileInfo);
      INC(fileInfo.sector, 29);
      fileInfo.count := 0
    END
  END EnumAll;

  PROCEDURE Defrag*;
  VAR
    R: DefragFiles.Rider;
    dp: FileDir.DirPage;
    buf: FileDir.DataSector;
    lastUsedSector, currSector, pos, len, fileno: INTEGER;
  BEGIN
    fileInfo.firstSector := Disk.LastUsedSector() + 29; fileInfo.count := 0;
    fileInfo.sector := fileInfo.firstSector;
    FileDir.Enumerate("", EnumAll);
    Disk.PutSector(fileInfo.sector, fileInfo);
    lastUsedSector := fileInfo.sector;
    currSector := lastUsedSector + 29; fileno := 0; pos := 0;
    Disk.GetSector(fileInfo.firstSector, fileInfo);
    WHILE fileno < fileInfo.count DO
      DefragFiles.Old(fileInfo.names[fileno]);
      len := 0;
      DefragFiles.SetAtZero(R);
      DefragFiles.ReadByte(R, buf[pos]);
      WHILE ~R.eof DO
        INC(pos); INC(len);
        IF pos = FileDir.SectorSize THEN
          Disk.PutSector(currSector, buf);
          INC(currSector, 29);
          pos := 0
        END;
        DefragFiles.ReadByte(R, buf[pos]);
      END;
      DefragFiles.Close();
      ASSERT(fileInfo.lengths[fileno] = len);
      INC(fileno);
      IF fileno = FileInfoPerSector THEN
        Disk.GetSector(fileInfo.sector + 29, fileInfo);
        fileno := 0
      END
    END;
    IF pos # 0 THEN
      WHILE pos < FileDir.SectorSize DO buf[pos] := 0; INC(pos) END;
      Disk.PutSector(currSector, buf);
    END;
    FOR pos := 0 TO FileDir.SectorSize - 1 DO buf[pos] := 0 END;
    Disk.PutSector(FileDir.DirRootAdr, buf);
    Disk.GetSector(FileDir.DirRootAdr, dp);
    dp.mark := FileDir.DirMark;
    Disk.PutSector(FileDir.DirRootAdr, dp);
    Disk.InitSecMap;
    currSector := lastUsedSector + 29; fileno := 0; pos := 0;
    Disk.GetSector(fileInfo.firstSector, fileInfo);
    Disk.GetSector(currSector, buf); INC(currSector, 29);
    WHILE fileno < fileInfo.count DO
      len := fileInfo.lengths[fileno];
      DefragFiles.New(fileInfo.names[fileno]);
      DefragFiles.SetAtZero(R);
      WHILE len > 0 DO
        DefragFiles.WriteByte(R, buf[pos]);
        INC(pos); DEC(len);
        IF pos = FileDir.SectorSize THEN
          Disk.GetSector(currSector, buf); INC(currSector, 29);
          pos := 0;
        END;
      END;
      DefragFiles.Register();
      INC(fileno);
      IF fileno = FileInfoPerSector THEN
        Disk.GetSector(fileInfo.sector + 29, fileInfo);
        fileno := 0
      END
    END;
    Trim; ShowRestartMessage
  END Defrag;

END Defragger.
