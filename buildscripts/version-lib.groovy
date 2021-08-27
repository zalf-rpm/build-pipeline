def commitVersionFileToGit(versionString, relVersionFilePath, reporsitory_Url, gitCheckoutFolder, credentials, branch, authorName, authorEmail)
{
    dir(gitCheckoutFolder)
    {
        withCredentials([string(credentialsId: credentials, variable: 'GITHUB_ACCESS_TOKEN')]) 
        {
            def gitCommitCmd = """git commit $relVersionFilePath -m \"auto commit version file version $versionString\" """
            def setAuthor = """git config --global user.name \"$authorName\" """
            def setEmail = """git config --global user.email $authorEmail """
            //old def pushToGit = """git push https://${GIT_USERNAME}:${GIT_PASSWORD}@$reporsitory_Url $branch"""
            def pushToGit = """git push https://${GITHUB_ACCESS_TOKEN}@${reporsitory_Url}.git ${branch}"""
            if (isUnix())
            { 
                sh setAuthor
                sh setEmail
                sh gitCommitCmd
                sh pushToGit 
            }
            else
            {
                bat setAuthor
                bat setEmail
                bat gitCommitCmd
                bat pushToGit   
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
    versionStr = versionStr.trim()
    return versionStr
}

def createGitTag(versionString, message, reporsitory_Url, gitCheckoutFolder, credentials, branch, authorName, authorEmail)
{
    // create tag if message and tag id are given. 
    if (versionString != "" && message != "")
    {
        dir(gitCheckoutFolder)
        {          
            withCredentials([string(credentialsId: credentials, variable: 'GITHUB_ACCESS_TOKEN')]) 
            {
                def gitTagCmd = """git tag -a \"v.$versionString\" -m "$message" """
                print(gitTagCmd)
                def setAuthor = """git config --global user.name \"$authorName\" """
                def setEmail = """git config --global user.email $authorEmail """
                //def pushToGit = """git push https://${GIT_USERNAME}:${GIT_PASSWORD}@$reporsitory_Url $branch"""
                def pushToGit = """git push https://${GITHUB_ACCESS_TOKEN}@${reporsitory_Url}.git ${branch}"""
        
                if (isUnix())
                { 
                    sh setAuthor
                    sh setEmail
                    sh gitTagCmd
                    sh pushToGit
                }
                else
                {
                    bat setAuthor
                    bat setEmail
                    bat gitTagCmd
                    bat pushToGit
                }        
            }
        }
    }
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