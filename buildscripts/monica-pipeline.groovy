pipeline {
  agent none
  parameters {
    // select versioning methode 
    choice(choices: ['NONE', 'PATCH', 'MINOR', 'MAYOR'], 
    description: '''Increase semanic version number (<mayor>.<minor>.<patch>.<build>) (1.2.34.1234). Build number will always increase. 
- increment patch version if backwards compatible big fixes are introduced
- increment minor version if new backwards compatible functionality is introduced to the public API
- increment major version if any backwards incompatible changes are introduced to the public API''', 
      name: 'INCREASE_VERSION')
    // select workspace cleaning mode 
    // NO_CLEANUP may cause issues. Test only.
    choice(choices: ['CLEAN_GIT_CHECKOUT', 'NO_CLEANUP', 'CLEANUP_WORKSPACE'], 
    description: '''
CLEAN_GIT_CHECKOUT - will remove the checkout and build folders and build a new version
NO_CLEANUP - quick and dirty! rebuild. Do a git pull and rebuild. This is for testing only!!!
CLEANUP_WORKSPACE - wipe clean the workspace(including vcpkg) - Build will take long!''', 
      name: 'CLEANUP')
    // create a git tag
    booleanParam(defaultValue: true, 
      description: 'tag build in git', 
      name: 'TAG_BUILD')
    // add a nice message to the git tag
    string(defaultValue: 'automatic version increased by jenkins', 
      description: '(optional) enter your tag message if you increased the build version', 
      name: 'TAG_MESSAGE') 
  }
  stages {   
        stage('parallel stage') {
            parallel {
                stage('BuildLinux') {
                    // build it on a debian linux node 
                    agent { label 'debian' }
                    steps {
                        cleanUpAll(params.CLEANUP == 'CLEANUP_WORKSPACE')
                        // git checkout and optional cleanup
                        doGitCheckout(params.CLEANUP == 'CLEAN_GIT_CHECKOUT')
                        // create vcpkg package directory 
                        doVcpkgCheckout()            
                        script 
                        {
                            // create a symlink to the boost folder installed in jenkins
                            if ( !fileExists('boost') )
                            {
                                def returnValueSymlink = sh returnStatus: true, script: 'ln -s ../../boost boost '
                                if (returnValueSymlink != 0)
                                {
                                    currentBuild.result = 'FAILURE'
                                }
                            }
                        }
                        // increase build version, but do not commit it, this will happen later, if the build is successfull
                        script
                        {
                            increaseVersionStr(false, false, "", params.INCREASE_VERSION, 'zalffpmbuild')     
                        }
                        // create cmake project in folder monica/_cmake_linux
                        script 
                        {
                            dir('monica')
                            {
                                sh returnStatus: true, script: 'sh update_linux.sh'
                            }
                        }
                        // compile project
                        script 
                        {
                            dir('monica/_cmake_linux')
                            {
                                def returnValueMake = sh returnStatus: true, script: 'make'
                                if (returnValueMake != 0)
                                {
                                    currentBuild.result = 'FAILURE'
                                }
                            }
                        }
                        script 
                        {
                            // get full version string for folder name
                            def fullVersionStr = getFullVersionNumber()
                            // extract linux executables and copy, tar zip into an artifact
                            sh returnStatus: true, script: "sh build-pipeline/buildscripts/pack-monica-artifact.sh $fullVersionStr"
                        }
                    }
                    post 
                    {
                        // if everything went well, there should be an artifact to store. 
                        // if will be stored to jenkins master and can be retrieved by other jobs, or downloaded from jenkins job website
                        success 
                        {
                            archiveArtifacts artifacts: 'deployartefact/*.tar.gz', fingerprint: true
                        }
                    }
                }
                // build on windows node
                stage('BuildWindows') {
                    agent { label 'windows' }
                    steps 
                    {
                        cleanUpAll(params.CLEANUP == 'CLEANUP_WORKSPACE')
                        // git checkout and optional cleanup
                        doGitCheckout(params.CLEANUP == 'CLEAN_GIT_CHECKOUT')
                        // create vcpkg package directory 
                        doVcpkgCheckout()               
                        script 
                        {
                            if ( !fileExists('boost') )
                            {
                                // create symlink to boost
                                def returnValueSymlink = bat returnStatus: true, script: 'if exist boost ( echo \"boost link already exist \" ) else (  mklink /D boost ..\\..\\boost )'
                                if (returnValueSymlink != 0)
                                {
                                    currentBuild.result = 'FAILURE'
                                }
                            }
                        }
                        // increase build version, but do not check-in
                        println('increase version number')
                        increaseVersionStr(false, false, "", params.INCREASE_VERSION, 'zalffpmbuild')   
                        println('Full version number:')
                        getFullVersionNumber() // yes, this is just debug output

                        // create cmake project in folder monica/_cmake_win32 and monica/_cmake_win64
                        script 
                        {
                            dir('monica')
                            {
                                bat returnStatus: true, script: 'call update_solution.cmd'
                                bat returnStatus: true, script: 'call update_solution_x64.cmd'
                            }
                        }
                        // compile project
                        script {
                            dir('monica') {
                                def returnValueBuild32 = bat returnStatus: true, script: 'msbuild _cmake_win32/monica.sln /p:Configuration=Release /p:Platform=\"Win32\"'
                                def returnValueBuild64 = bat returnStatus: true, script: 'msbuild _cmake_win64/monica.sln /p:Configuration=Release /p:Platform=\"x64\"'
                                if (returnValueBuild32 != 0 || returnValueBuild64 != 0)
                                {
                                    currentBuild.result = 'FAILURE'
                                }
                            }
                        }
                        // build installer - using installed NSIS on windows  
                        script 
                        {
                            def buildnumber = getBuildNumber()
                            def semanicVersionNumber = getVersionNumber()

                            dir('monica/installer')
                            {
                                def returnInstaller32 = bat returnStatus: true, script: "call run-installer-with-parameter.bat $semanicVersionNumber $buildnumber 86"
                                def returnInstaller64 =  bat returnStatus: true, script: "call run-installer-with-parameter.bat $semanicVersionNumber $buildnumber 64"
                                if (returnInstaller32 != 0 || returnInstaller64 != 0)
                                {
                                    currentBuild.result = 'FAILURE'
                                }
                            }
                        }
                    }
                    post 
                    {
                        // archivate installer 
                        success 
                        {
                            archiveArtifacts artifacts: 'monica/installer/*.exe', fingerprint: true
                        }
                    }
                }
            }
        }
        stage('commitVersion')
        {
            //this only happens if build was successfull
            agent any
            when 
            {
                expression { currentBuild.result != 'FAILURE' }
            }
            steps 
            {
                //cleanup workspace
                script 
                {
                    if (params.CLEANUP == 'CLEAN_GIT_CHECKOUT' || params.CLEANUP == 'CLEANUP_WORKSPACE') { 
                        if ( fileExists('build-pipeline') ) 
                        {
                            deleteDirectory('build-pipeline')
                        }
                        if ( fileExists('monica') ) 
                        {
                            deleteDirectory('monica')
                        }
                    }
                }
                // checkout monica
                checkout([$class: 'GitSCM', branches: [[name: '*/master']], 
                    doGenerateSubmoduleConfigurations: false, 
                    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'monica']], 
                    submoduleCfg: [], 
                    credentialsId: 'zalffpmbuild',
                    userRemoteConfigs: [[url: 'https://github.com/zalf-rpm/monica.git']]])
                // checkout build script
                checkout([$class: 'GitSCM', branches: [[name: '*/master']], 
                    doGenerateSubmoduleConfigurations: false, 
                    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'build-pipeline']], 
                    submoduleCfg: [], 
                    credentialsId: 'zalffpmbuild',
                    userRemoteConfigs: [[url: 'https://github.com/zalf-rpm/build-pipeline.git']]])      

                // increase version, commit + push to git, <optional> create tag 
                increaseVersionStr(true, params.TAG_BUILD, params.TAG_MESSAGE, params.INCREASE_VERSION, 'zalffpmbuild')                 
            }                
        }
    }
}
// get build number from version.h 
def getBuildNumber()
{
    def rootDir = pwd()
    def versionLib = load "${rootDir}/build-pipeline/buildscripts/version-lib.groovy"
    def buildNumber = versionLib.getVersionFromVersionFile(true, false, "monica/src/resource/version.h")
    return buildNumber
}
// get full version number from version.h 2.0.12.1235
def getFullVersionNumber()
{
    def rootDir = pwd()
    def versionLib = load "${rootDir}/build-pipeline/buildscripts/version-lib.groovy"
    def fullbuildNumber = versionLib.getVersionFromVersionFile(false, false, "monica/src/resource/version.h")
    return fullbuildNumber
}
// get semantic version number from version.h 2.0.12
def getVersionNumber()
{
    def rootDir = pwd()
    def versionLib = load "${rootDir}/build-pipeline/buildscripts/version-lib.groovy"
    def versionNumber = versionLib.getVersionFromVersionFile(false, true, "monica/src/resource/version.h")
    return versionNumber    
}

// increase version, git commit + push, do tag (only if also commited)
def increaseVersionStr(doCommit, tagBuildParam, buildMessageParam, increaseVersionParam, credentialsId)
{
    def rootDir = pwd()
    def versionLib = load "${rootDir}/build-pipeline/buildscripts/version-lib.groovy"
    def versionStr = versionLib.incrementVersionFile(increaseVersionParam, "monica/src/resource/version.h")
    if (doCommit)
    {
        versionLib.commitToGit(versionStr, "src/resource/version.h", "monica", credentialsId)       
    }
    if (doCommit && tagBuildParam)
    {
        versionLib.createGitTag(versionStr, buildMessageParam, credentialsId)
    }     
    return versionStr
}

// cleanup the workspace or folder this methode is called in
// NOTE: Windows file handling can be a bit bitchy. If something keeps file handles on any files or folder that are to be deleted,
//      the function will not fail. The folders will exist till the file handle is gone.
//      This may cause unintended behavior or fails the job.
def cleanUpAll(cleanWorkspace) 
{
    if (cleanWorkspace)
    {
        deleteDir()
    }
}

def doGitCheckout(cleanWorkspace)
{
    // cleanup workspace
    if (cleanWorkspace) { 
        if ( fileExists('build-pipeline') ) {
            deleteDirectory('build-pipeline')
        }
        if ( fileExists('monica') ) {
            deleteDirectory('monica')
        }
        if ( fileExists('util') ) {
            deleteDirectory('util')
        }
        if ( fileExists('sys-libs') ) {
            deleteDirectory('sys-libs')
        }
        if ( fileExists('monica-parameters') ) {
            deleteDirectory('monica-parameters')
        }
    }
  // Get code from a GitHub repository
  checkout([$class: 'GitSCM', branches: [[name: '*/master']], 
    doGenerateSubmoduleConfigurations: false, 
    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'build-pipeline']], 
    submoduleCfg: [], 
    credentialsId: 'zalffpmbuild',
    userRemoteConfigs: [[url: 'https://github.com/zalf-rpm/build-pipeline.git']]])
  checkout([$class: 'GitSCM', branches: [[name: '*/master']], 
    doGenerateSubmoduleConfigurations: false, 
    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'monica']], 
    submoduleCfg: [], 
    credentialsId: 'zalffpmbuild',
    userRemoteConfigs: [[url: 'https://github.com/zalf-rpm/monica.git']]])
  checkout([$class: 'GitSCM', branches: [[name: '*/master']], 
    doGenerateSubmoduleConfigurations: false, 
    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'util']], 
    submoduleCfg: [], 
    credentialsId: 'zalffpmbuild',
    userRemoteConfigs: [[url: 'https://github.com/zalf-rpm/util.git']]])
  checkout([$class: 'GitSCM', branches: [[name: '*/master']], 
    doGenerateSubmoduleConfigurations: false, 
    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'sys-libs']], 
    submoduleCfg: [], 
    credentialsId: 'zalffpmbuild',
    userRemoteConfigs: [[url: 'https://github.com/zalf-rpm/sys-libs']]])
  checkout([$class: 'GitSCM', branches: [[name: '*/master']], 
    doGenerateSubmoduleConfigurations: false, 
    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'monica-parameters']], 
    submoduleCfg: [], 
    credentialsId: 'zalffpmbuild',
    userRemoteConfigs: [[url: 'https://github.com/zalf-rpm/monica-parameters']]])
}

// checkout vcpkg
def doVcpkgCheckout()
{
    if (isUnix())
    {
        dir('build-pipeline/buildscripts') {
            sh returnStatus: true, script: 'sh ./linux-prepare-vcpkg.sh'
        }
    }
    else
    {
        dir('build-pipeline/buildscripts') {
            bat returnStatus:true, script: 'call window-prepare-vcpkg.bat'
        }
    }
}

// delete dir replacement... has the same issues with blocked handles
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
