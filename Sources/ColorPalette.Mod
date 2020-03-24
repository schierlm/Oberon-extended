MODULE ColorPalette;
  IMPORT Display, Viewers, Oberon, MenuViewers, TextFrames;

  CONST Menu = "System.Close  System.Copy  System.Grow";

  PROCEDURE DrawPalette(F: Display.Frame);
    VAR s, w, x, y: INTEGER;
  BEGIN
    IF F.W < F.H THEN w := F.W ELSE w := F.H END ;
    s := w DIV 4;
    Display.ReplConst(Display.black, F.X, F.Y, F.W, F.H, Display.replace);
    FOR x := 0 TO 3 DO
      FOR y := 0 TO 3 DO
        Display.ReplConst((3-y) * 4 + x, F.X + x * s, F.Y + y * s, s, s, Display.replace);
      END
    END
  END DrawPalette;

  PROCEDURE Handler(F: Display.Frame; VAR M: Display.FrameMsg);
    VAR F0: Display.Frame;
  BEGIN
    IF M IS Oberon.InputMsg THEN
      IF M(Oberon.InputMsg).id = Oberon.track THEN
        Oberon.DrawMouseArrow(M(Oberon.InputMsg).X, M(Oberon.InputMsg).Y)
      END
    ELSIF M IS Viewers.ViewerMsg THEN
      IF (M(Viewers.ViewerMsg).id = Viewers.restore) OR (M(Viewers.ViewerMsg).id = Viewers.modify) THEN
        F.Y := M(Viewers.ViewerMsg).Y; F.H := M(Viewers.ViewerMsg).H; DrawPalette(F)
      END
    ELSIF M IS Oberon.ControlMsg THEN
      IF M(Oberon.ControlMsg).id = Oberon.neutralize THEN Oberon.RemoveMarks(F.X, F.Y, F.W, F.H) END
    ELSIF M IS Oberon.CopyMsg THEN
      NEW(F0); F0^ := F^; M(Oberon.CopyMsg).F := F0
    END
  END Handler;

  PROCEDURE Draw*;
    VAR V: Viewers.Viewer; X, Y: INTEGER; F: Display.Frame;
  BEGIN
    NEW(F); F.handle := Handler;
    Oberon.AllocateUserViewer(Oberon.Par.vwr.X, X, Y);
    V := MenuViewers.New(TextFrames.NewMenu("ColorPalette", Menu), F, TextFrames.menuH, X, Y)
  END Draw;

END ColorPalette.
