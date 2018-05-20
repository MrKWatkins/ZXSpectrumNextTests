This demo puts the ULA over Layer2. It fills Layer2 with some data and then changes the ULA palette so paper 7 is the transparent colour.

You should see the Layer2 image as the overlying white paper should be transparent.

Not sure what colour the border should be - should the border take use the ink palette values or the paper palette values for it's colour? And should the border ever be transparent? If ink then it should stay white as we have not redefined white ink. If it takes the paper value then it should be magenta unless the border can be transparent, in which case it should be the default background colour, presumably black?