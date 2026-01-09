#!/bin/sh
set -e

### CONFIG ############################################################

SYSROOT=~/x-tools/arm-kindlepw3-linux-musleabi/arm-kindlepw3-linux-musleabi/sysroot
HOST=arm-kindlepw3-linux-musleabi
BUILD=x86_64-linux-gnu
PREFIX=/usr
OUTDIR=kindle-python

export CC=${HOST}-gcc
export AR=${HOST}-ar
export RANLIB=${HOST}-ranlib
export STRIP=${HOST}-strip

########################################################################

echo "[*] Cleaning previous build"
make distclean || true
rm -f config.cache
rm -rf sources

mkdir sources
cd sources

echo "[*] Installing zlib"
wget https://zlib.net/current/zlib.tar.gz
tar -xf zlib*
cd zlib-*/
CC=arm-kindlepw3-linux-musleabi-gcc \
CFLAGS="-Os -fPIC -march=armv7-a -mfloat-abi=softfp" \
AR=arm-kindlepw3-linux-musleabi-ar \
RANLIB=arm-kindlepw3-linux-musleabi-ranlib \
./configure \
    --prefix=$SYSROOT/usr \

make -j$(nproc)
sudo env "PATH=$PATH" make install
sudo rm $SYSROOT/usr/lib/libz.so* #make sure only static binaries are found
cd ..

echo "[*] Installing libffi"
wget https://github.com/libffi/libffi/releases/download/v3.5.2/libffi-3.5.2.tar.gz
tar -xf libffi*
cd libffi-*/

./configure \
    --host=arm-kindlepw3-linux-musleabi \
    --prefix=$SYSROOT/usr \
    --disable-shared \
    --enable-static
make -j$(nproc)
sudo env "PATH=$PATH" make install
cd ..

echo "[*] Installing openssl"

wget https://github.com/openssl/openssl/releases/download/openssl-3.6.0/openssl-3.6.0.tar.gz
tar -xf openssl*
cd openssl-*/
export CFLAGS="--sysroot=$SYSROOT -Os -fPIC -march=armv7-a -mfloat-abi=softfp"
export LDFLAGS="--sysroot=$SYSROOT -pthread"
./Configure linux-armv4 threads no-shared no-async \
    --prefix=/usr \
    --openssldir=/etc/ssl \
    -DOPENSSL_NO_SECURE_MEMORY

unset CFLAGS
unset LDFLAGS

make -j$(nproc)
sudo env "PATH=$PATH" make DESTDIR="$SYSROOT" install

cd ../..

echo "[*] Writing config.site"
cat > config.site <<'EOF'
ac_cv_file__dev_ptmx=yes
ac_cv_file__dev_ptc=no
ac_cv_func_fork=yes
ac_cv_func_vfork=yes
ac_cv_func_execv=yes
EOF

export CONFIG_SITE=$PWD/config.site

echo "[*] Writing Modules/Setup.local"
cat > Modules/Setup.local <<EOF
zlib zlibmodule.c \
    -I$SYSROOT/usr/include \
    -L$SYSROOT/usr/lib -lz
_ssl _ssl.c \
    -I$SYSROOT/usr/include \
    -L$SYSROOT/usr/lib \
    -lssl -lcrypto -lpthread
_ctypes \
    _ctypes/_ctypes.c \
    _ctypes/callbacks.c \
    _ctypes/callproc.c \
    _ctypes/stgdict.c \
    _ctypes/cfield.c \
    -I$SYSROOT/usr/include \
    -L$SYSROOT/usr/lib \
    -lffi -ldl
*static*
*disabled*
_asyncio
_uuid
_sqlite3
_readline
_tkinter
_dbm
_gdbm
_nis
_lzma
_zstd
ossaudiodev
lzma
zstd
readline
EOF


echo "[*] Configuring Python 3.14"
./configure \
  --host=${HOST} \
  --build=${BUILD} \
  --prefix=${PREFIX} \
  --enable-shared \
  --disable-test-modules \
  --with-build-python=python3 \
  --disable-ipv6 \
  ac_cv_lib_ffi_ffi_call=no \
  ac_cv_header_ffi_h=no \
  CFLAGS="--sysroot=${SYSROOT} -Os -fPIC -march=armv7-a -mfloat-abi=softfp" \
  LDFLAGS="--sysroot=${SYSROOT}"

echo "[*] Building"
make -j$(nproc) HOSTPYTHON=python3

echo "[*] Staging install"
rm -rf stage
make DESTDIR=$PWD/stage install

echo "[*] Assembling output directory"
rm -rf ${OUTDIR}
mkdir -p ${OUTDIR}
mv stage/usr/* ${OUTDIR}/

echo "[*] Copying musl runtime"
cp -f ${SYSROOT}/lib/ld-musl-arm.so.1 ${OUTDIR}/lib/
cp -f ${SYSROOT}/usr/lib/libc.so ${OUTDIR}/lib/

echo "[*] Patching ELF interpreter and rpath"
patchelf \
  --set-interpreter /mnt/us/python/lib/ld-musl-arm.so.1 \
  ${OUTDIR}/bin/python3.14

patchelf \
  --set-rpath '$ORIGIN/../lib' \
  ${OUTDIR}/bin/python3.14

patchelf \
  --set-rpath '$ORIGIN' \
  ${OUTDIR}/lib/libpython3.14.so*

echo "[*] Stripping binaries"
${STRIP} \
  ${OUTDIR}/bin/python3.14 \
  ${OUTDIR}/lib/libpython3.14.so*

echo "[*] Patching scripts"
patch --strip=0 < kindle.patch
rm kindle-python/bin/idle3.14

cp $SYSROOT/usr/lib/libffi.so.8 kindle-python/lib/

echo "[*] Setting up pip"
touch kindle-python/setup-pip.sh
cat <<EOF > kindle-python/setup-pip.sh
set -e
/mnt/us/python/bin/python3.14 /mnt/us/python-stuff/get-pip.py --no-warn-script-location
echo "pip setup done. you can delete this safely."
EOF
echo "[✓] Build complete: ${OUTDIR}"
