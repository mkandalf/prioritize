prioritize
==========

Market-based email inboxes.


Usage
=========
Install extension:
- In Chrome: Tools > Extensions
- Check 'Developer mode' box
- Load unpacked extension > pick client/ folder
- To reload, click 'Reload' link under extension

Set Up server
=============

* `createdb priority`
* `createuser -P -s -e value` (used password `value` when prompted)
* `python migrate.py`
