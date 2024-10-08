cd ../../
if not exist vcpkg (
	git clone https://github.com/Microsoft/vcpkg.git
	cd vcpkg
	call bootstrap-vcpkg.bat
	cd ..
)

cd vcpkg
.\vcpkg install zeromq:x64-windows-static
.\vcpkg install capnproto:x64-windows-static
.\vcpkg install libsodium:x64-windows-static

cd ..