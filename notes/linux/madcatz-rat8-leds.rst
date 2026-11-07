.. meta::
   :description:
      Turn off or set the RGB LEDs of the Mad Catz R.A.T. 8+ mouse on Linux,
      without Windows, using a small Python tool over hidraw.
   :keywords:
      Mad Catz, R.A.T. 8+, RAT 8+, Linux, RGB, LED, mouse, hidraw, 12cf:0c05

:Publish Date: 2026-09-21

**********************************
Mad Catz R.A.T. 8+ LEDs on Linux
**********************************

.. article-info::
    :date: Sep 21, 2026
    :read-time: 2 min read

I got a (second) Mad Catz R.A.T. 8+.
OK mouse (I'm used to it), but it ships with an ugly RGB rainbow on all four profiles.

The vendor app is Windows only.
`libratbag <https://github.com/libratbag/libratbag>`_ and
`OpenRGB <https://openrgb.org>`_ do not know this mouse.
The settings live in the mouse, so the usual advice is to borrow a Windows box once.
Which I do not have.

So I wrote a small py script `rat8-leds <https://github.com/epheo/rat8-leds>`_.
One Python file, standard lib only, talking to the mouse over hidraw.


Usage
=====

.. code-block:: bash

   git clone https://github.com/epheo/rat8-leds && cd rat8-leds

   ./rat8-leds.py info                  # firmware, active slot, LED mode per slot
   ./rat8-leds.py backup ~/rat8-backup  # do this first

   ./rat8-leds.py off                                  # all slots dark
   ./rat8-leds.py static                               # all slots dim white
   ./rat8-leds.py static --slot 2 --color ffb000       # one slot, dim yellow
   ./rat8-leds.py static --brightness 12 --color ffffff  # 0-255, default 32

   ./rat8-leds.py restore ~/rat8-backup  # back to what backup saved

The mouse has 4 profile slots, 0 to 3.
The profile button cycles them.
Without ``--slot``, all 4 are written.

The result is saved in the mouse.
Run it once.
It survives a replug and follows the mouse to any computer.


Permissions
===========

The tool only needs read and write access to the hidraw node of the mouse.
Run it as root, or install the udev rule from the repo and replug.
The rule grants access to the user logged in at the local seat, not over SSH:

.. code-block:: bash

   sudo cp 70-rat8.rules /etc/udev/rules.d/
   sudo udevadm control --reload


How it works
============

The mouse is configured with HID feature reports on its second USB interface.
Each slot is a 733-byte profile protected by a checksum.
The LED settings are three 191-byte blocks, one per zone, starting at offset 160.

The tool reads the slot, changes only the LED bytes, writes it back and asks the mouse to reload.
The mouse checks the checksum and acknowledges the write.

The vendor app has no off mode.
``off`` is a static colour at brightness 0.

The protocol comes from reading the vendor Windows app.
It is documented in the
`README <https://github.com/epheo/rat8-leds#protocol>`_,
for whoever wants to bring this mouse to libratbag or OpenRGB.


Caveats
=======

* Tested only on my mouse, USB ``12cf:0c05``, firmware 18.
* It writes to the mouse flash. Run ``backup`` first. ``restore`` writes that backup back.
* The R.A.T. 2+, 6+ and PRO X3 share the ``12cf`` vendor ID.
  The protocol is probably close. Untested.
  If you own one, open an issue on the repo.
