cd ../../
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
call bootstrap-vcpkg.bat
.\vcpkg install zeromq:x64-windows-static
.\vcpkg install zeromq:x86-windows-static
.\vcpkg install boost-python:x86-windows-static
.\vcpkg install boost-python:x64-windows-static
cd ..