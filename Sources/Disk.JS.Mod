MODULE Disk;  (*NW/PR  11.4.86 / 27.12.95 / 4.2.2014 / AP 12.12.20 Extended Oberon, adapted for JS emulator *)
  IMPORT SYSTEM;
  CONST SectorLength* = 1024;
    FSoffset = 0H;
    mapsize = 10000H; (*1K sectors, 64MB*)

  TYPE Sector* = ARRAY SectorLength OF BYTE;

  VAR NofSectors*: INTEGER;
    sectorMap: ARRAY mapsize DIV 32 OF SET;

(* ---------- Disk storage management ----------*)

  PROCEDURE InitSecMap*;
    VAR i: INTEGER;
  BEGIN NofSectors := 0;
    FOR i := 0 TO 4 DO sectorMap[i] := {0 .. 31} END ;           (*mark blocks 0-159 (=5*32 = 160 blocks) as allocated*)
    FOR i := 5 TO mapsize DIV 32 - 1 DO sectorMap[i] := {} END   (*mark blocks 160-65536 (=64K-160 blocks) as unallocated*)
  END InitSecMap;

  PROCEDURE LastUsedSector*(): INTEGER;
  VAR i, j, secno: INTEGER;
  BEGIN
    i := mapsize DIV 32 - 1;
    WHILE sectorMap[i] = {} DO DEC(i) END;
    FOR j := 0 TO 31 DO
      IF j IN sectorMap[i] THEN secno := i * 32 + j END;
    END;
  RETURN secno * 29
  END LastUsedSector;

  PROCEDURE MarkSector*(sec: INTEGER);
  BEGIN sec := sec DIV 29; ASSERT(SYSTEM.H(0) = 0);
    INCL(sectorMap[sec DIV 32], sec MOD 32); INC(NofSectors)
  END MarkSector;

  PROCEDURE FreeSector*(sec: INTEGER);
  BEGIN sec := sec DIV 29; ASSERT(SYSTEM.H(0) = 0);
    EXCL(sectorMap[sec DIV 32], sec MOD 32); DEC(NofSectors)
  END FreeSector;

  PROCEDURE AllocSector*(hint: INTEGER; VAR sec: INTEGER);
    VAR s: INTEGER;
  BEGIN (*find free sector, starting after hint*)
    hint := hint DIV 29; ASSERT(SYSTEM.H(0) = 0); s := hint;
    REPEAT INC(s);
      IF s = mapsize THEN s := 1 END ;
    UNTIL ~(s MOD 32 IN sectorMap[s DIV 32]);
    INCL(sectorMap[s DIV 32], s MOD 32); INC(NofSectors); sec := s * 29
  END AllocSector;

  PROCEDURE GetSector*(src: INTEGER; VAR dst: Sector);
  BEGIN src := src DIV 29; ASSERT(SYSTEM.H(0) = 0);
    src := src + FSoffset DIV 2;
    SYSTEM.PUT(-28, SYSTEM.ADR(dst));
    SYSTEM.PUT(-28, 080000000H + src)
  END GetSector;

  PROCEDURE PutSector*(dst: INTEGER; VAR src: Sector);
  BEGIN dst := dst DIV 29; ASSERT(SYSTEM.H(0) =  0);
    dst := dst + FSoffset DIV 2;
    SYSTEM.PUT(-28, SYSTEM.ADR(src));
    SYSTEM.PUT(-28, 0C0000000H + dst)
  END PutSector;

  PROCEDURE TrimAllSectorsAfter*(sec: INTEGER);
  BEGIN sec := sec DIV 29; ASSERT(SYSTEM.H(0) = 0);
    sec := sec + FSoffset DIV 2 + 1;
    SYSTEM.PUT(-28, 3FFFFFFFH);
    SYSTEM.PUT(-28, 0C0000000H + sec);
  END TrimAllSectorsAfter;

  PROCEDURE Init*;
  BEGIN InitSecMap
  END Init;

END Disk.
