MODULE M3;  (*no asterisk after the keyword MODULE*)
  IMPORT SYSTEM, M0, M1, M2;  (*import constants only for RunRsc*)
  VAR i0, i1, i2: INTEGER;

BEGIN
  i0 := M0.C0; SYSTEM.PUT(8, i0);   (*10 decimal = A hexadecimal*)
  i1 := M1.C1; SYSTEM.PUT(12, i1);  (*11 decimal = B hexadecimal*)
  i2 := M2.C2; SYSTEM.PUT(16, i2)   (*12 decimal = C hexadecimal*)
END M3.

ORP.Compile Run.Mod/s M0.Mod/s M1.Mod/s M2.Mod/s M3.Mod/s ~
ORL.Link M3 ~

Run.RunRsc M3.rsc ~
Run.RunBin M3.bin ~  

Tools.Inspect 0 ~

-> this yields this output

  ........ ........ 0000000A 0000000B 0000000C ........


# The above experiment either runs a pre-linked binary
# or a single object file M.rsc which imports constants
# only from three other modules M0, M1 and M2.
#
# Note that in this test, there is no asterisk after the key word MODULE,
# so M3 is not comiled as a standalone program. This is just so that M3
# does not jump to memory address 0 at the end.
#
# But one CAN compile module M3 also WITH the asterisk - the only
# difference are the modified start and ending sequence.
#
# Thus, there is no reason why this wouldn't work with the boot loader.
#
