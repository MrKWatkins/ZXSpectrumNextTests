The test disables interrupts and does "halt", the machine should freeze there with
GREEN BORDER and full WHITE PAPER = OK.

If the halt is passed and further instructions are executed, the BORDER will turn RED.

If the interrupt handler will get executed, the attributes at end of 2/3 of screen
will get damaged, as the stack pointer points there.
