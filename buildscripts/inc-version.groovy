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
    stringParam(defaultValue: 'automatic version increased by jenkins', 
      description: '(optional) enter your tag message if you increased the build version', 
      name: 'TAG_MESSAGE') 
  }
  stages {   
    stage('IncrementVersion') {
        agent any
            steps {
                script {
                    def varIncrementParameters = ""
                    def tagMessage = ""
                    if (params.INCREASE_VERSION == 'PATCH')
                    {
                        varIncrementParameters = "false false true "
                    } else if (params.INCREASE_VERSION == 'MINOR')
                    {
                        varIncrementParameters = "false true false "
                    } else if (params.INCREASE_VERSION == 'MAYOR')
                    {
                        varIncrementParameters = "true false false "
                    }
                    if (varIncrementParameters != "")
                    {
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
                        
                        def versionStr = ""
                        if (isUnix())
                        { 
                            versionStr = sh returnStdout: true, script: "python build-pipeline/buildscripts/incrementversion.py monica/src/resource/version.h $varIncrementParameters"
                        }
                        else
                        {
                            versionStr = bat returnStdout: true, script: "python build-pipeline/buildscripts/incrementversion.py monica/src/resource/version.h $varIncrementParameters"
                        }
                        if (params.TAG_BUILD)
                        {
                            createGitTag(versionStr, params.TAG_MESSAGE)
                        }
                    }
                }
            }
        }
    }
}

def createGitTag(versionString, message)
{
    result = false
    if (versionStr != "")
    {
        if (isUnix())
        { 
            result = sh returnStatus: true, script: "echo tag -a $versionString -m $message"
            //sh returnStatus: true, script: "git tag -a $versionString -m $message"
        }
        else
        {
            result = returnStatus: true, script: "echo tag -a $versionString -m $message"
            //bat returnStatus: true, script: "git tag -a $versionString -m $message"
        }        
    }
    return result
}