# kindlepy: scripts to get python 3.14 on a kindle paperwhite 3
It does just that.
## Prereqs
* A jailbroken PW3 (preferrably with winterbreak, that's what I tested it with)
* Python 3.14 (host)
* A msul cross-toolchain for the PW3 installed at `~/x-tools/arm-kindlepw3-linux-musleabi` (you can find mine [here](https://github.com/hackifiery/arm-kindlepw3-linux-musleabi))
## How to build it from source
### 1. Clone it
```sh
git clone https://github.com/hackifiery/kindlepy
```
### 2. Grab the sources
Put whatever source code of the sub-version of python 3.14 you want in the directory you cloned this repo in
### 3. Build it
This repo automates the cross-compilation for you. Just run:
```sh
./build.sh
```
* If you don't like any of the paths in the script, just modify the variables at the top.
### 4. Depoy it
Let's say you mounted your PW3 on `/mnt/kindle` and want to install it to `/mnt/us/python`. Then you would do:
```sh
sudo cp -r kindle-python/ /mnt/kindle/python
```
This installs it to /mnt/us/python. If you chose a different path and want to install `pip`, edit the `setup-pip.sh` accordingly (will be automated in a future release).
* Note that we don't copy it to `/mnt/kindle/mnt/us/python`, because when the kindle enters USB mode, the root of the "drive" always points to `/mnt/us`, so we don't need to append that to the path.
* If you have any previous installations of python there, make sure to remove it first.
* If you encounter any `cp: cannot create symbolic link '/mnt/kindle/python/bin/[whatever]': Operation not permitted`, safely ignore it; it happens because the `/mnt/us` partition uses the old FAT32, which doesn't support the symlinks python creates.
### 5. Run it
Now, you can just add `/mnt/us/python/bin` to your PATH and run `python3.14` from there.
### 6. Setup pip
Just run `setup-pip.sh` (from the kindle) and you're done. if it is successful, you can delete it safely.
