def commitToGit(versionString, relFilePathInCheckout, gitCheckoutFolder)
{
    dir(gitCheckoutFolder)
    {
        String out = sh returnStdout: true, script: "git commit $relFilePathInCheckout --dry-run -m \"auto commit version file with $versionString\" "
        print(out)
        //sh returnStdout: true, script: 'git push origin master'      
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


def createGitTag(versionString, message)
{
    result = false
    if (versionString != "")
    {
        if (isUnix())
        { 
            result = sh returnStatus: true, script: "echo tag -a $versionString -m $message"
            //sh returnStatus: true, script: "git tag -a $versionString -m $message"
        }
        else
        {
            result = bat returnStatus: true, script: "echo tag -a $versionString -m $message"
            //bat returnStatus: true, script: "git tag -a $versionString -m $message"
        }        
    }
    return result
}

return this