# parameter <version file path> <incrementMayor true/false> <incrementMinor true/false> <incrementRevision true/false>


from shutil import move
from os import remove, close
import sys

headerfile = sys.argv[1]
incrementMayor = sys.argv[2]
incrementMinor = sys.argv[3]
incrementRevision = sys.argv[4]

#read current version from version.h
versionfile = [line.rstrip('\n') for line in open(headerfile)]
versionMayorLine = ""
versionMinorLine = ""
versionRevisionLine = ""

for line in versionfile:
    if line.startswith("#define VERSION_MAJOR               "):
        versionMayorLine = line.replace("#define VERSION_MAJOR               ", "")
		
    if (line.startswith("#define VERSION_MINOR               ")):
        versionMinorLine = line.replace("#define VERSION_MINOR               ", "")

    if (line.startswith("#define VERSION_REVISION            ")):
        versionRevisionLine = line.replace("#define VERSION_REVISION            ", "")

currentMayorVersion = int(versionMayorLine)		
currentMinorVersion = int(versionMinorLine)
currentRevisionVersion = int(versionRevisionLine)

if (incrementMayor == "true"):
	versionMayorLine = currentMayorVersion + 1

if (incrementMinor == "true"):
	versionMinorLine = currentMinorVersion + 1
	
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
    newFile.write(line3)

newFile.close()
oldFile.close()

remove(oldPath)

move(newPath, oldPath)
