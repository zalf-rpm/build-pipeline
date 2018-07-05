pipeline {
  agent none
  parameters {
    choice(choices: ['PATCH', 'MINOR', 'MAYOR', 'NONE'], 
    description: '''increase semanic version number (<mayor>.<minor>.<patch>) (1.2.34)
- increment patch version if backwards compatible big fixes are introduced
- increment minor version if new backwards compatible functionality is introduced to the public API
- increment major version if any backwards incompatible changes are introduced to the public API''', 
      name: 'INCREASE_VERSION')
    booleanParam(defaultValue: true, 
      description: 'cleanup workspace and do a clean build', 
      name: 'CLEAN_WORKSPACE')
    booleanParam(defaultValue: true, 
      description: 'tag build in git', 
      name: 'TAG_BUILD')
    string(defaultValue: 'automatic version increased by jenkins', 
      description: '(optional) enter your tag message if you increased the build version', 
      name: 'TAG_MESSAGE') 
  }
  stages {   
    stage('IncrementVersion') {
        agent any
            steps {
                script {
                    // checkout monica
                    checkout([$class: 'GitSCM', branches: [[name: '*/master']], 
                        doGenerateSubmoduleConfigurations: false, 
                        extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'monica']], 
                        submoduleCfg: [], 
                        userRemoteConfigs: [[url: 'https://github.com/zalf-rpm/monica.git']]])
                    // checkout build script
                    checkout([$class: 'GitSCM', branches: [[name: '*/master']], 
                        doGenerateSubmoduleConfigurations: false, 
                        extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'build-pipeline']], 
                        submoduleCfg: [], 
                        userRemoteConfigs: [[url: 'https://github.com/zalf-rpm/build-pipeline.git']]])        
                    
                    def versionStr = incrementVersionFile(params.INCREASE_VERSION, "monica/src/resource/version.h")
                    SendMailToRequestor()
                    if (params.TAG_BUILD)
                    {
                        createGitTag(versionStr, params.TAG_MESSAGE)
                    }
                    
                }
            }
        }
    }
}
def SendMailToRequestor()
{
    emailext attachLog: true, body: '$DEFAULT_CONTENT', subject: '$DEFAULT_SUBJECT', recipientProviders: [requestor()]
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