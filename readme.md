### **Description**

Displays a bar on screen that allows quick access to enchanting, jewelcrafting, and inscription professions by presenting a Disenchant/Prospect/Mill button and all of the breakable items you have for that profession next to it. Also displays a bar for any locked junkboxes in your inventory if you're a Rogue. This allows one-click access for breaking down items instead of finding the item in your bag, clicking the appropriate profession/skill button, and clicking the item for each and every item you want to break. For prospecting and milling, you will see the number of items you have alongside the number of times you can break it. In the prospecting screenshot on the right, the player has 169 total Saronite Ore in his bags which will allow for 33 total prospects.

### **Usage**

By default, if you have the appropriate profession and items in your inventory, a bar will appear with the profession ability followed by any items that are eligible for breaking. You can hold shift to drag the bar around if you want to move it. Clicking the profession button will activate that ability (disenchant/prospect/mill) and clicking an item will break it. You don't have to click the profession button first as simply clicking the item will automatically break it down.

### **Configuration**

Typing */brk* will open the configuration settings (or you can get to it from Blizzard's Interface options) which consist of:

* **Hide if no breakables**: this will control whether you see the profession button or not when nothing breakable is detected
* **Max number to display**: this controls the highest number of items that you will see next to your profession button. If this is 5 but you have 10 breakable items in your bags, you will only see 5 at a time.
* **Show soulbound items**: aimed at enchanters, this controls whether or not you will see items that are soulbound as breakable items or not.


### **Known issues**
* If you have more than 5 of a breakable item but split into stacks all smaller than 5, the game will say you do not have enough items to break. The default UI now has a built-in button to compress stacks that should solve this issue.
* If you know Mass Milling for a specific type of herb, the current alpha will try to use this ability and fail. I am in the process of leveling a scribe up high enough to debug this problem.
