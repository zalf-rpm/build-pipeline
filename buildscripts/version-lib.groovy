// Workaround deleteDir() is not always working properly
def deleteDirectory(directory)
{
    returnStdout = ""
    if (isUnix())
    {
        returnStdout = sh returnStdout: true, script: "rm -rf \"$directory\""
    }
    else
    {
        returnStdout = bat returnStdout: true, script: "rmdir /s /q \"$directory\""
    }
    print(returnStdout)
}

def commitToGit(versionString, relFilePathInCheckout, gitCheckoutFolder, credentialsId, author, authorEmail)
{
    dir(gitCheckoutFolder)
    {
        sshagent (credentials: [credentialsId])
        {
            if (isUnix())
            { 
                sh "git config --global user.name \"$author\""
                sh "git config --global user.email $authorEmail"
                String out = sh returnStdout: true, script: "git commit $relFilePathInCheckout -m \"auto commit version file with $versionString\" "
                print("Commited: ready to push")
                print(out)

                //String result = sh returnStdout: true, script: 'git push origin master'      
                //print(result)
            }
            else
            {
                bat "git config --global user.name \"$author\""
                bat "git config --global user.email $authorEmail"
                String out = sh returnStdout: true, script: "git commit $relFilePathInCheckout -m \"auto commit version file with $versionString\" "
                print("Commited: ready to push")
                print(out)

                //String result = bat returnStdout: true, script: 'git push origin master'      
                //print(result)
            }
        }
    }
}

def incrementVersionFile(increaseVersion, filename)
{
    def varIncrementParameters = "false false false "
    def tagMessage = ""
    def versionStr = ""

    if (increaseVersion == 'PATCH')
    {
        varIncrementParameters = "false false true "
    } else if (increaseVersion == 'MINOR')
    {
        varIncrementParameters = "false true false "
    } else if (increaseVersion == 'MAYOR')
    {
        varIncrementParameters = "true false false "
    }  
        
    if (isUnix())
    { 
        versionStr = sh returnStdout: true, script: "python build-pipeline/buildscripts/incrementversion.py $filename $varIncrementParameters"
    }
    else
    {
        versionStr = bat returnStdout: true, script: "python build-pipeline/buildscripts/incrementversion.py $filename $varIncrementParameters"
    }
    return versionStr
}


def createGitTag(versionString, message, credentialsId, gitCheckoutFolder, author, authorEmail)
{
    def result = false
    if (versionString != "")
    {
        dir(gitCheckoutFolder)
        {
            print(versionString)
            if (isUnix())
            { 
                //result = sh returnStatus: true, script: "echo tag -a $versionString -m $message"
                sshagent([credentialsId]) 
                {
                    sh "git config --global user.name \"$author\""
                    sh "git config --global user.email $authorEmail"
                    result = sh returnStatus: true, script: "git tag -a $versionString -m \"$message\""
                }
            }
            else
            {
                //result = bat returnStatus: true, script: "echo tag -a $versionString -m $message"
                sshagent([credentialsId]) 
                {
                    bat "git config --global user.name \"$author\""
                    bat "git config --global user.email $authorEmail"
                    result = bat returnStatus: true, script: "git tag -a $versionString -m \"$message\""
                }
            }        
        }
    }
    return result
}

def getVersionFromVersionFile(buildNumberOnly, semanticVersionOnly, headerfilePath)
{
    def result = ""
    def root = pwd()
    String fileContents = readFile "${root}/${headerfilePath}"
    def lines = fileContents.split("\n")
    int versionMayorLine = 0
    int versionMinorLine = 0
    int versionRevisionLine = 0
    int versionBuildLine = 0

    for (line in lines) 
    {
        if (line.startsWith("#define VERSION_MAJOR "))
        {
            versionMayorLine = (line - ~'#define VERSION_MAJOR +').toInteger()   
        }
        if (line.startsWith("#define VERSION_MINOR "))
        {
            versionMinorLine = (line - ~'#define VERSION_MINOR +').toInteger()
        }
        if (line.startsWith("#define VERSION_REVISION "))
        {
            versionRevisionLine = (line - ~'#define VERSION_REVISION +').toInteger()          
        }
        if (line.startsWith("#define VERSION_BUILD "))
        {
            versionBuildLine = (line - ~'#define VERSION_BUILD +').toInteger()      
        }
    }
    if (semanticVersionOnly)
    {
        result = versionMayorLine + "." + versionMinorLine  + "." + versionRevisionLine
    }
    else if (buildNumberOnly)
    {
        result = versionBuildLine
    }
    else
    {
        result = versionMayorLine + "." + versionMinorLine  + "." + versionRevisionLine + "." + versionBuildLine
    }
    print(result)

    return result
}


return this