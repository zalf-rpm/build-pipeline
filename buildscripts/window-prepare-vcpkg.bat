cd ../../
if not exist vcpkg (
	git clone https://github.com/Microsoft/vcpkg.git
	cd vcpkg
	call bootstrap-vcpkg.bat
	cd ..
)

cd vcpkg
.\vcpkg install zeromq:x64-windows-static
.\vcpkg install zeromq:x86-windows-static
cd ..