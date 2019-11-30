The results of tests are green/red rectangles covering the "#" spots:

Visible Layer 2 (NextReg 0x12)
### write-over-ROM 16kiB
### write-over-ROM 48kiB
### read-over-ROM 16kiB (data)
### read-over-ROM 48kiB (data)
  # read-over-ROM (code)
  # read-over-ROM (IM1 in L2)

Shadow Layer 2  (NextReg 0x13)
### write-over-ROM 16kiB
### write-over-ROM 48kiB
### read-over-ROM 16kiB (data)
### read-over-ROM 48kiB (data)
  # read-over-ROM (code)
  # read-over-ROM (IM1 in L2)

The result rectangle is 6x8 pixels, divided into four 6x2px blocks.
Green is OK, Red is failure. If all tests did pass, the final
BORDER is Green, otherwise it is Red (other colours of border mean
the test is still running, and if that takes more than 0.5s, it's
stuck, not reaching final stage of test).

Banks 8,9,10 are used for visible Layer2, banks 11,12,13 are used for "shadow" access
and banks 14,15,16 are used as RAM in the $0000..$BFFF region to verify writes are
landing only to the desired bank and not also underlying one.

Meaning of four 6x2px blocks in the result rectangle:

* write-over-ROM 16/48kiB:
 - first two (each different 8kiB page): "write didn't affect original RAM paged under L2"
 - second two (each different 8kiB page): "write did land into Layer 2 bank"
 - each 6x8 rectangle belongs to one third of Layer 2

* read-over-ROM 16/48kiB:
 - first two (each different 8kiB page): "read did reach Layer 2 bank"
 - second two (each different 8kiB page): "write did land into underlying RAM bank"
 - each 6x8 rectangle belongs to one third of Layer 2

* read-over-ROM (code)
 - full rectangle Red = unexpected ROM (this test needs "cp $21 : ret nc" code at $007D)
 - first  block is Layer2 mode: "none paging" => ROM code did run (this *must* work ;))
 - second block is Layer2 mode: "read-over paging" => Layer 2 code did run
 - third  block is Layer2 mode: "write-over paging" => ROM code did run
 - fourth block is Layer2 mode: "read+write over" => Layer 2 code did run
 (only first 8kiB page is part of the test)

* read-over-ROM (IM1 in L2)
 - each block is one interrupt fired, the test is waiting for four interrupts = full green
 (if some block is not green, there was either interrupt not fired,
  or the handler in the Layer2 was not used to handle it)
 (only first 8kiB page is part of the test)
