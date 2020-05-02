Source in folder: Tests/Sprites/Transparency/

This demo creates a sprite from colour indexes 1 and 2. It then sets index 2 to be the transparent colour.

Top-Left (◰) and Bottom-Right (◲) squares should be transparent = WHITE
(if RED, sprite transparency failed).

Top-Right and Bottom-Left (▞) squares should be GREEN
(if YELLOW, the sprite transparency index did not read as the default $E3 value)
