#!/bin/sh

build() {
	cd "${1}"
	shift
	skip=$1
	shift
	if [ -f CMakeLists.txt ]; then
		if [ -d build ]; then
			if [ $skip -eq 0 ]; then
				rm -rf build
				mkdir build
			fi
		else
			mkdir build
		fi
		cd build
		if [ $skip -eq 0 ]; then
			cmake .. $@
			make -j`nproc`
		fi
		make install
		ldconfig
		cd ../..
	elif [ -f autogen.sh ]; then
		./autogen.sh
		./configure $@
		make -j`nproc`
		make install
		ldconfig
		cd ..
	else
		./configure $@
		make -j`nproc`
		make install
		ldconfig
		cd ..
	fi
}


# install apt dependencies
apt -y install build-essential git vim flex bison cmake libusb-1.0-0-dev pkg-config libfftw3-dev libliquid-dev libboost-system-dev libboost-thread-dev python3 python3-setuptools python3-mako libpython3-dev python3-numpy swig zstd netcat-openbsd libsndfile-dev automake autoconf libtool pkg-config libsamplerate-dev sox libprotobuf-dev protobuf-compiler libudev-dev libicu-dev libboost-program-options-dev qt5-qmake libpulse0 libfaad2 libopus0 libpulse-dev libfaad-dev libopus-dev wget direwolf libgtest-dev libopenblas64-dev libopenblas-dev python3-venv zlib1g-dev libxml2-dev libjansson-dev sqlite3 libsqlite3-dev libconfig++-dev libzmq3-dev libgoogle-perftools-dev libncurses-dev libboost-dev gfortran libcurl4-openssl-dev libitpp-dev imagemagick dablin libpng-dev libtiff-dev libjemalloc-dev libnng-dev libzstd-dev libhdf5-dev libomp-dev wsjtx libhamlib-dev js8call

# create venv
[ -d /opt/openwebrx ] || mkdir -p /opt/openwebrx
QWRXPY=/opt/openwebrx/env/bin/python3
if [ ! -d /opt/openwebrx/env ]; then
	python3 -m venv /opt/openwebrx/env
	$QWRXPY -m pip install mako paho-mqtt
fi
. /opt/openwebrx/env/bin/activate

# build csdr
if [ ! -d csdr ]; then
git clone https://github.com/luarvique/csdr.git csdr
build csdr
fi

# build pycsdr
if [ ! -d pycsdr ]; then
git clone https://github.com/luarvique/pycsdr.git pycsdr
cd pycsdr
$QWRXPY setup.py install install_headers
# missing headers, manually install
mkdir -p /opt/openwebrx/env/include/pycsdr
install -m 0644 src/buffer.hpp /opt/openwebrx/env/include/pycsdr
install -m 0644 src/bufferreader.hpp /opt/openwebrx/env/include/pycsdr
install -m 0644 src/module.hpp /opt/openwebrx/env/include/pycsdr
install -m 0644 src/pycsdr.hpp /opt/openwebrx/env/include/pycsdr
install -m 0644 src/reader.hpp /opt/openwebrx/env/include/pycsdr
install -m 0644 src/sink.hpp /opt/openwebrx/env/include/pycsdr
install -m 0644 src/source.hpp /opt/openwebrx/env/include/pycsdr
install -m 0644 src/writer.hpp /opt/openwebrx/env/include/pycsdr
cd ..
fi

# build csdr-eti
if [ ! -d csdr-eti ]; then
	git clone https://github.com/luarvique/csdr-eti.git csdr-eti
	build csdr-eti
fi

# build pycsdr-eti
if [ ! -d pycsdr-eti ]; then
	git clone https://github.com/luarvique/pycsdr-eti.git pycsdr-eti
	cd pycsdr-eti
	$QWRXPY setup.py install install_headers
	cd ..
fi

# build js8py
if [ ! -d js8py ]; then
git clone -b master https://github.com/jketterl/js8py.git
cd js8py
$QWRXPY setup.py install
cd ..
fi

# build csdr-sstv
if [ ! -d csdr-sstv ]; then
git clone https://github.com/jketterl/csdr-sstv csdr-sstv
sed -i "s/Csdr::csdr/Csdr::csdr++/" csdr-sstv/src/CMakeLists.txt
build csdr-sstv
fi

# build pycsdr-sstv
if [ ! -d pycsdr-sstv ]; then
git clone https://github.com/jketterl/pycsdr-sstv pycsdr-sstv
cd pycsdr-sstv
$QWRXPY setup.py install install_headers
cd ..
fi

# build owrx_connector
if [ ! -d owrx_connector ]; then
git clone https://github.com/luarvique/owrx_connector.git
build owrx_connector
fi

# build codecserver
if [ ! -d codecserver ]; then
git clone -b master https://github.com/jketterl/codecserver.git
build codecserver
adduser --system --group --no-create-home --home /nonexistent --quiet codecserver
usermod -aG dialout codecserver
mkdir -p /usr/local/etc/codecserver
cat << EOF > /usr/local/etc/codecserver/codecserver.conf
# unix domain socket server for local use
[server:unixdomainsockets]
socket=/tmp/codecserver.sock

# tcp server for use over network
[server:tcp]
#port=1073
#bind=::

# example config for an USB-3000 or similar device
#[device:dv3k]
#driver=ambe3k
#tty=/dev/ttyUSB0
#baudrate=921600
EOF
chown -R codecserver:codecserver /usr/local/etc/codecserver
systemctl daemon-reload
systemctl enable codecserver
systemctl restart codecserver
fi

# build digiham
if [ ! -d digiham ]; then
git clone -b master https://github.com/jketterl/digiham.git digiham
build digiham
fi

# build pydigiham
if [ ! -d pydigiham ]; then
git clone -b master https://github.com/jketterl/pydigiham.git pydigiham
cd pydigiham
$QWRXPY setup.py install
cd ..
fi

# build codec2
if [ ! -d codec2 ]; then
	git clone https://github.com/drowe67/codec2.git codec2
	build codec2
	install -m 0755 codec2/build/src/freedv_rx /usr/local/bin
fi

# build blaze-lib
if [ ! -d blaze-3.8.2 ]; then
wget https://bitbucket.org/blaze-lib/blaze/downloads/blaze-3.8.2.tar.gz
tar -xzvf blaze-3.8.2.tar.gz
build blaze-3.8.2
fi

# build m17-cxx-demod
if [ ! -d m17-cxx-demod ]; then
git clone https://github.com/mobilinkd/m17-cxx-demod.git
build m17-cxx-demod
fi

# build drm
if [ ! -d dream ]; then
	wget https://downloads.sourceforge.net/project/drm/dream/2.1.1/dream-2.1.1-svn808.tar.gz
	tar -xzvf dream-2.1.1-svn808.tar.gz
	cd dream
	qmake -qt=qt5 CONFIG+=console
	make -j`nproc`
	make install
	ldconfig
	cd ..
fi

# build redsea
if [ ! -d redsea ]; then
	git clone https://github.com/luarvique/redsea.git redsea
	build redsea
fi

# build csdr-cwskimmer
if [ ! -d csdr-cwskimmer ]; then
	git clone https://github.com/luarvique/csdr-cwskimmer.git csdr-cwskimmer
	cd csdr-cwskimmer
	make
	install -m 0755 csdr-cwskimmer /usr/local/bin
	cd ..
fi

# build nrsc5
if [ ! -d nrsc5 ]; then
	git clone https://github.com/luarvique/nrsc5 nrsc5
	build nrsc5
fi

# build multimon-ng
if [ ! -d multimon-ng ]; then
	git clone https://github.com/luarvique/multimon-ng multimon-ng
	build multimon-ng
fi

# build libacars
if [ ! -d libacars ]; then
git clone https://github.com/szpajder/libacars libacars
build libacars
fi

# build dumphfdl
if [ ! -d dumphfdl ]; then
git clone https://github.com/szpajder/dumphfdl dumphfdl
build dumphfdl
fi

# build dumpvdl2
if [ ! -d dumpvdl2 ]; then
git clone https://github.com/szpajder/dumpvdl2 dumpvdl2
build dumpvdl2
fi

# build acarsdec
if [ ! -d acarsdec ]; then
git clone https://github.com/TLeconte/acarsdec acarsdec
build acarsdec
fi

# build dump1090-fa
if [ ! -d dump1090-fa ]; then
git clone https://github.com/flightaware/dump1090 dump1090-fa
cd dump1090-fa
make -j`nproc` all
make wisdom.local
install -m 0755 dump1090 /usr/local/bin
install -m 0755 view1090 /usr/local/bin
install -d /usr/local/share/dump1090-fa
install -d /usr/local/share/dump1090-fa/bladerf
install -d /usr/local/lib/dump1090-fa
install -d /usr/local/etc/dump1090-fa
install -m 0755 bladerf/* /usr/local/share/dump1090-fa/bladerf
install -m 0755 debian/start-dump1090-fa /usr/local/share/dump1090-fa
install -m 0755 debian/generate-wisdom /usr/local/share/dump1090-fa
install -m 0755 debian/upgrade-config /usr/local/share/dump1090-fa
install -m 0644 debian/dump1090-fa.default /usr/local/share/dump1090-fa
install -m 0755 starch-benchmark /usr/local/lib/dump1090-fa
install -m 0644 wisdom.local /usr/local/etc/dump1090-fa
ln -s dump1090-fa /usr/local/share/dump1090
ln -s dump1090-fa /usr/local/lib/dump1090
ln -s dump1090-fa /usr/local/etc/dump1090
cd ..
fi

# build mbelib
if [ ! -d mbelib ]; then
git clone https://github.com/szechyjs/mbelib mbelib
build mbelib
fi

# build dsd
if [ ! -d dsd ]; then
git clone https://github.com/szechyjs/dsd dsd
build dsd
fi

# build msk144decoder
if [ ! -d msk144decoder ]; then
git clone --recurse-submodules https://github.com/alexander-sholohov/msk144decoder msk144decoder
build msk144decoder
fi

# build satdump
if [ ! -d satdump ]; then
git clone https://github.com/SatDump/SatDump satdump
build satdump 0 -DBUILD_GUI=OFF
fi

# buidl rtl_433
if [ ! -d rtl_433 ]; then
git clone https://github.com/merbanan/rtl_433 rtl_433
build rtl_433
fi

# add aprs-symbols
[ -d /usr/share/aprs-symbols ] || git clone https://github.com/hessu/aprs-symbols /usr/share/aprs-symbols

# prepare openwebrx environment
adduser --system --group --no-create-home --home /nonexistent --quiet owrx
usermod -aG codecserver owrx
usermod -aG plugdev owrx
chown -R owrx:owrx /opt/openwebrx
if [ ! -d /var/lib/openwebrx ]; then
	mkdir -p /var/lib/openwebrx
	chown owrx:owrx /var/lib/openwebrx
fi
if [ ! -f /var/lib/openwebrx/users.json ]; then
echo [] > /var/lib/openwebrx/users.json
chown owrx:owrx /var/lib/openwebrx/users.json
chmod 0600 /var/lib/openwebrx/users.json
fi

# grab openwebrx
if [ ! -d /opt/openwebrx/core ]; then
git clone https://github.com/luarvique/openwebrx.git /opt/openwebrx/core
chown -R owrx:owrx /opt/openwebrx/core
fi

# create openwebrx systemd
if [ ! -f /etc/systemd/system/openwebrx.service ]; then
cat << EOF > /etc/systemd/system/openwebrx.service
[Unit]
Description=OpenWebRX WebSDR receiver

[Service]
Type=simple
User=owrx
Group=owrx
WorkingDirectory=/opt/openwebrx/core
ExecStart=${QWRXPY} /opt/openwebrx/core/openwebrx.py
Restart=always
Environment="HOME=/tmp"

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
fi

echo "Preparation completed!"
