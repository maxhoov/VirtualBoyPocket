# Virtual Boy for Analogue Pocket

An experimental openFPGA port by maxhoov, based on Jamie Blanks' VirtualBoy_MiSTer RTL and Analogue core-template 1.3.0.

The first public release is **0.1.0**. 

## Features

- V810 CPU, VIP and VSU; 40 MHz system clock with a 20 MHz CPU clock enable.
- Data slot 0 loads ROMs up to 16 MiB into Pocket mobile SDRAM through 32-bit writes, with ROM mirroring.
- Data slot 1 provides 8 KiB cartridge SRAM. Missing saves are initialized to FF; persistence is managed through openFPGA.
- 384 x 224 video at approximately 50.08 Hz. Display modes: left eye red (default), right eye red, red/cyan anaglyph, and left eye white.
- 48 kHz, 16-bit stereo I2S audio; Pocket and Dock controller input.
- ROM download FIFO overflow prevents startup and sets an error indicator.

Pocket has only 308 M10K blocks. MiSTer's three-frame display buffer exceeds that capacity, so this port uses the upstream direct VRAM scanout path. Tearing and synchronization between the two eyes require further hardware testing.

The 64 KiB work RAM resides in Pocket's external SRAM. To accommodate the device's 55 ns timing, the adapter extends some CPU memory accesses; the port is not yet cycle-exact to the original hardware. Cartridge save RAM remains on-chip.

## Building and installation

Use Quartus Prime Lite with Cyclone V support. The development environment uses 25.1std. The target device and pin assignments follow the template's 5CEBA4F23C8 configuration. Adjust the tool path for your installation:

```powershell
./build.ps1 -QuartusBin 'X:\QuartusPrime-25.1\quartus\bin64'
```

The script generates `release/` only after compilation and timing-summary checks pass. It reverses the bits within every RBF byte: **renaming `.rbf` to `.rbf_r` is not sufficient**.

To install a release, merge the contents of the installation ZIP into the SD card root. For a local build, merge the contents of `release/` instead:

```text
Cores/maxhoov.VirtualBoy/         Core bitstream and configuration
Platforms/virtualboy.json         Platform metadata
Platforms/_images/virtualboy.bin  Platform image
Assets/virtualboy/common/         Your legally obtained .vb/.vboy/.bin ROMs
```

Back up saves before testing. Save files are 8192 bytes; homebrew using nonstandard save sizes has not been validated. Do not power off while a save is being written.

### Platform image

The `virtualboy.bin` image installed at `Platforms/_images/virtualboy.bin` comes from [spiritualized1997's openFPGA-Platform-Art-Set](https://github.com/spiritualized1997/openFPGA-Platform-Art-Set). Credit for this artwork belongs to that project. The upstream project permits openFPGA developers to use its platform images with their cores on Analogue's openFPGA.

## Controls

The Pocket D-pad always maps to the Virtual Boy's left D-pad. Start and Select map to the original buttons of the same names.

| Mode     | VB A/B | VB right D-pad                                        | VB L/R            |
| -------- | ------ | ----------------------------------------------------- | ----------------- |
| Standard | A/B    | X: up, Y: left; Dock right stick: all four directions | L/R or Dock L2/R2 |
| Dual-pad | R/L    | X/B/Y/A: up/down/left/right                           | Dock L2/R2        |

Pocket does not have enough buttons to map every original control independently. Full controls require a Dock controller with a right stick and L2/R2. Input mapping and display settings are persistent. 

## Limitations

MiSTer save states, cheats, TAS, SNAC, link functionality and sleep are not enabled. Save persistence, long sessions, Dock operation and display-mode edge cases need further hardware validation. No game ROMs are included.

## Credits and license

The imported Virtual Boy RTL is copyright Jamie Blanks. See [LICENSE](LICENSE); original copyright notices are retained in the source files. The platform shell is based on the Analogue template.

Protocol references: [data slots](https://www.analogue.co/developer/docs/core-definition-files/data-json), [audio/video and bus communication](https://www.analogue.co/developer/docs/bus-communication), [external hardware](https://www.analogue.co/developer/docs/external-hardware), and [core packaging](https://www.analogue.co/developer/docs/packaging-a-core).
