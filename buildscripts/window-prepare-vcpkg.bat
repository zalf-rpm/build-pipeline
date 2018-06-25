cd ../../
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
call "C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\vcvarsall.bat" x86
call bootstrap-vcpkg.bat
.\vcpkg install zeromq:x64-windows-static
.\vcpkg install zeromq:x86-windows-static
cd ..