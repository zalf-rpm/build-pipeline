# parameter <version file path> <optional: -build OR -semantic>
# without optional -build or -semantic parameter, output will be full version string  
# IMPORTANT NOTE: Do not add output to this file
# this script must just return one line of version

from shutil import move
from os import remove, close
import sys

headerfile = sys.argv[1] #version.h
semanticVersionOnly = False
buildNumberOnly = False

for arg in sys.argv:
    if (arg == "-semantic"):
        semanticVersionOnly = True
    if (arg == "-build"):
        buildNumberOnly = True

versionfile = [line.rstrip('\n') for line in open(headerfile)]
versionMayorLine = ""
versionMinorLine = ""
versionRevisionLine = ""
versionBuildLine = ""

for line in versionfile:
    if line.startswith("#define VERSION_MAJOR               "):
        versionMayorLine = line.replace("#define VERSION_MAJOR               ", "")
		
    if (line.startswith("#define VERSION_MINOR               ")):
        versionMinorLine = line.replace("#define VERSION_MINOR               ", "")

    if (line.startswith("#define VERSION_REVISION            ")):
        versionRevisionLine = line.replace("#define VERSION_REVISION            ", "")

    if (line.startswith("#define VERSION_BUILD               ")):
        versionBuildLine = line.replace("#define VERSION_BUILD               ", "")

#return only one version line to be used by jenkins pipeline script 
if (semanticVersionOnly):
    print("{}.{}.{}".format(versionMayorLine, versionMinorLine, versionRevisionLine))
elif (buildNumberOnly):
    print("{}".format(versionBuildLine))
else:
    print("{}.{}.{}.{}".format(versionMayorLine, versionMinorLine, versionRevisionLine, versionBuildLine))
