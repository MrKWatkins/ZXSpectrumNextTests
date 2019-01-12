In this test the X/Y offset of Layer2 is tested.

Layer2 is enabled, filled with colour 1 (set to $FC, set as global transparent colour)
ULA classic is under Layer2, white paper, blue ink

There are five horizontal and five vertical 40px lines draw in the ULA layer.

All of these are surrounded by light-blue "dotted" lines in Layer2, and at the ends
of ULA lines blue-ish black 20px lines in Layer2 connect (starting with 2px overdraw
and drifting away by 1px per line (having gap at fourth and fifth line).

There are also X/Y axis "rulers" starting in original [0,0] point, they are going
by 8 (light blue) / 32 (blueish black tip) pixels.

The point is, those lines connect correctly thanks to the X/Y scroll set to [201,45],
without X/Y HW scroll implemented the Layer2 lines are all over place.
