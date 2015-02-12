fc_minetest-protect
================

Protector mod for minetest
based on glomie's mod, remade by Zeg9 and reworked by TenPlus1 to support minetest 0.4.9 and include protected doors and chests.

Modified by False_Chicken for personal server use. Use however you would like.

Original Forum Link: https://forum.minetest.net/viewtopic.php?f=11&t=9376

Released under WTFPL


NEW FEATURES: 

- Keys

	- All protection doors and the chest now require keys to be protected from players opening them.


- Crafting And Using Keys


To craft a key place three steel ingots in the crafting area. Current recipe is shapeless. This will give you a blank key.

To use a blank key it must be initialized. To do so left click (punch) with it. A prompt will
appear asking you to name the key (Press enter to confirm or esc to cancel.). This will name the key
and give it a secret code that is unique to the key. Meaning that just naming another key the same
name will not allow that key to open the door/chest. 

After this step you can punch with the now initialized "Normal Key" to see its name printed in the chat area.

You may now right click (place) on the door/chest to lock it with they key. You will see a "Key Set!" message in the
chat area.

Please take note of the currently known bugs below.

- KNOWN BUGS:
	
	None at the moment.


- TODO/WISHLIST:

	1. Way to copy keys. I am thinking a new machine like node to do this.
	- Integrate the protection blocks into some sort of economy system and make the size configurable from the formspec.
		The cost should be scaled based on how many blocks total you protect. Think rent.
