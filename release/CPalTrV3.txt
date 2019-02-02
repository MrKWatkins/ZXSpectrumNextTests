This test puts the ULA over Layer2. It fills Layer2 with some data.
Then it sets INK mask to 7 and PAPER 7 ULANext colour to transparent ($E3), but it keeps
ULANext colours OFF (!), requesting classic ZX48 ULA display.
It also sets transparency-fallback colour to raw cyan ($1F).

You should see the full white paper+border and nothing of underlying Layer2 image, as
the ULANext white->transparent-pink should be not happening.
