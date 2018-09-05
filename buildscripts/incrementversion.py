# parameter <version file path> <incrementMayor true/false> <incrementMinor true/false> <incrementRevision true/false>
# IMPORTANT NOTE: Do not add output to this file
# this script must just return one line of version

from shutil import move
from os import remove, close
import sys

headerfile = sys.argv[1] #version.h
incrementMayor = sys.argv[2] # bool increase mayor version
incrementMinor = sys.argv[3] # bool increase minor version
incrementRevision = sys.argv[4] # bool increase revision/patch version

#read current version from version.h
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

currentMayorVersion = int(versionMayorLine)		
currentMinorVersion = int(versionMinorLine)
currentRevisionVersion = int(versionRevisionLine)
currentBuildNumber = int(versionBuildLine)
versionBuildLine = currentBuildNumber + 1   #always increment the build number

if (incrementMayor == "true"):
	versionMayorLine = currentMayorVersion + 1
    versionMinorLine = 0 
    versionRevisionLine = 0

if (incrementMinor == "true"):
	versionMinorLine = currentMinorVersion + 1
	versionRevisionLine = 0

if (incrementRevision == "true"):
	versionRevisionLine = currentRevisionVersion + 1
	
#update version.h with new version
oldPath = headerfile
newPath = "{}tmp".format(headerfile)

newFile = open(newPath,'w')
oldFile = open(oldPath)
for line in oldFile:
    line1 = line.replace("#define VERSION_MAJOR               {}".format(currentMayorVersion),"#define VERSION_MAJOR               {}".format(versionMayorLine))
    line2 = line1.replace("#define VERSION_MINOR               {}".format(currentMinorVersion),"#define VERSION_MINOR               {}".format(versionMinorLine))
    line3 = line2.replace("#define VERSION_REVISION            {}".format(currentRevisionVersion),"#define VERSION_REVISION            {}".format(versionRevisionLine))
    line4 = line3.replace("#define VERSION_BUILD               {}".format(currentBuildNumber),"#define VERSION_BUILD               {}".format(versionBuildLine))
    newFile.write(line4)

newFile.close()
oldFile.close()

remove(oldPath)

move(newPath, oldPath)
#return only one version line to be used by jenkins pipeline script 
print("{}.{}.{}.{}".format(versionMayorLine, versionMinorLine, versionRevisionLine, versionBuildLine))
sys.stdout.flush()