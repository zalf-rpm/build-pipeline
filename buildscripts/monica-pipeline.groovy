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
    booleanParam(defaultValue: false, 
      description: '(optional) TAG build in git. Note: CREATE_RELEASE will create a TAG by default. ', 
      name: 'TAG_BUILD')
    // add a nice message to the git tag
    string(defaultValue: 'automatic version increased by jenkins', 
      description: '(optional) enter your tag message if you increased the build version', 
      name: 'TAG_MESSAGE') 
    // upload to archive
    booleanParam(defaultValue: false, 
      description: 'Upload to archive. (upload build artifacts to ZALF samba archive)', 
      name: 'UPLOAD_TO_ARCHIV')
    // create release 
    booleanParam(defaultValue: false, 
      description: 'Create git release.', 
      name: 'CREATE_RELEASE')
    // create release as draft
    booleanParam(defaultValue: false, 
      description: 'Create release as draft. It will not be visible for public use until manualy released on website',
      name: 'DRAFT')
    // mark release as not production ready
    booleanParam(defaultValue: false, 
      description: '''Mark release as 'pre-release'. Pre-release means that this code is production ready. ''',
      name: 'PRERELEASE')
    // push docker image on successfull build
    booleanParam(defaultValue: false, 
        description: 'Push/upload docker image (to https://hub.docker.com/r/zalfrpm)', 
        name: 'PUSH_DOCKER_IMAGE')
    // if PUSH_DOCKER_IMAGE is true, push as latest version 
    booleanParam(defaultValue: true, 
        description: 'Push docker image with Tag "latest" (zalfrpm/monica-cluster:latest)', 
        name: 'LATEST')
    // if PUSH_DOCKER_IMAGE is true, push with current version number
    booleanParam(defaultValue: true, 
        description: 'push docker image with Tag "version number" (e.g. zalfrpm/monica-cluster:2.0.3.148)', 
        name: 'VERSION')
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
                        script 
                        {
                            boolean doCleanupFirst = params.CLEANUP == 'CLEANUP_WORKSPACE' || params.CLEANUP == 'CLEAN_GIT_CHECKOUT'
                            checkoutGitRepository('build-pipeline', doCleanupFirst, 'zalffpmbuild_basic')
                            checkoutGitRepository('monica', doCleanupFirst, 'zalffpmbuild_basic')
                            checkoutGitRepository('util', doCleanupFirst, 'zalffpmbuild_basic')
                            checkoutGitRepository('sys-libs', doCleanupFirst, 'zalffpmbuild_basic')                            
                        }


                        // create vcpkg package directory 
                        doVcpkgCheckout()            
                        // script 
                        // {
                        //     // create a symlink to the boost folder installed in jenkins
                        //     if ( !fileExists('boost') )
                        //     {
                        //         def returnValueSymlink = sh returnStatus: true, script: 'ln -s ../../boost boost '
                        //         if (returnValueSymlink != 0)
                        //         {
                        //             currentBuild.result = 'FAILURE'
                        //         }
                        //     }
                        // }
                        // increase build version, but do not commit it, this will happen later, if the build is successfull
                        script
                        {
                            increaseVersionStr(false, false, "", params.INCREASE_VERSION, 'zalffpmbuild_basic', "", "")     
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
                            dir('deployartefact')
                            {
                                stash includes: '*.tar.gz', name: 'linux_executables'                                
                            }
                            archiveArtifacts artifacts: 'deployartefact/*.tar.gz', fingerprint: true
                        }
                    }
                }
                // build on windows node
                stage('BuildWindows') {
                    agent { label 'windows' }
                    steps 
                    {
                        script
                        {
                            boolean doCleanupFirst = params.CLEANUP == 'CLEANUP_WORKSPACE' || params.CLEANUP == 'CLEAN_GIT_CHECKOUT'

                            cleanUpAll(params.CLEANUP == 'CLEANUP_WORKSPACE')
                            // git checkout and optional cleanup
                            checkoutGitRepository('build-pipeline', doCleanupFirst, 'zalffpmbuild_basic')
                            checkoutGitRepository('monica', doCleanupFirst, 'zalffpmbuild_basic')
                            checkoutGitRepository('util', doCleanupFirst, 'zalffpmbuild_basic')
                            checkoutGitRepository('sys-libs', doCleanupFirst, 'zalffpmbuild_basic')
                            checkoutGitRepository('monica-parameters', doCleanupFirst, 'zalffpmbuild_basic')                            
                        }

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
                        increaseVersionStr(false, false, "", params.INCREASE_VERSION, 'zalffpmbuild_basic', "", "")   
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
                            dir('monica/installer')
                            {
                               stash includes: '*.exe', name: 'win_installer'                             
                            }
                            archiveArtifacts artifacts: 'monica/installer/*.exe', fingerprint: true
                        }
                    }
                }
            }
        }
        stage('commitVersion')
        {
            // has to be executed on linux, because this step is using sshagent, 
            // which need some libs (Apache Tomcat Native libraries) to run - which I'm to lazy to install :P 
            agent { label 'debian' }
            //this only happens if build was successfull
            when 
            {
                expression { currentBuild.result != 'FAILURE' }
            }
            steps 
            {
                //cleanup workspace
                script 
                {
                    boolean doCleanupFirst = params.CLEANUP == 'CLEANUP_WORKSPACE' || params.CLEANUP == 'CLEAN_GIT_CHECKOUT'
                    // checkout version in monica
                    def outVarMap = checkoutGitRepository('monica', doCleanupFirst, 'zalffpmbuild_basic')
                    // checkout build script
                    checkoutGitRepository('build-pipeline', doCleanupFirst, 'zalffpmbuild_basic')

                    // increase version, commit + push to git, <optional> create tag     
                    increaseVersionStr(true, params.TAG_BUILD, params.TAG_MESSAGE, params.INCREASE_VERSION, 'zalffpmbuild_basic', outVarMap.GIT_AUTHOR_NAME, outVarMap.GIT_AUTHOR_EMAIL)             
                }
            }                
        }
        stage ('test in docker')
        {
            agent { label 'debian' }
            when 
            {
                expression { currentBuild.result != 'FAILURE' }
            }
            steps 
            {
                build job: 'monica.pipeline.testing', 
                    propagate: true,
                    parameters: [   booleanParam( name: 'PUSH_DOCKER_IMAGE', value: params.PUSH_DOCKER_IMAGE),
                                    booleanParam( name: 'LATEST', value: params.LATEST),
                                    booleanParam( name: 'VERSION', value: params.VERSION),
                                    string(name: 'MONICA_BUILD_NUMBER', value: env.BUILD_NUMBER)]
            }
        }
        stage('parallel deployment') {
            parallel {
                stage('archiving')
                {
                    agent { label 'debian' }
                    when 
                    {
                        expression { currentBuild.result != 'FAILURE' && params.UPLOAD_TO_ARCHIV }
                    }
                    steps 
                    { 
                        script 
                        {
                            // checkout pipeline scripts and monica version
                            boolean doCleanupFirst = params.CLEANUP == 'CLEANUP_WORKSPACE' || params.CLEANUP == 'CLEAN_GIT_CHECKOUT'
                            checkoutGitRepository('monica', doCleanupFirst, 'zalffpmbuild_basic')
                            checkoutGitRepository('build-pipeline', doCleanupFirst, 'zalffpmbuild_basic')
                            def storageFolder = 'tostorage'
                            def archivFolder = "../../archiv" // this should be a mounted folder
                            sh "rm -rf $storageFolder"
                            sh "mkdir -p $storageFolder"
                            dir(storageFolder)
                            {
                                unstash 'win_installer'
                                unstash 'linux_executables'
                            }  

                            def buildFolder = 'monica_' + getFullVersionNumber()
                            def versionFolder = "workversion"
                            if (params.INCREASE_VERSION != 'NONE')
                            {
                                versionFolder = 'monica_' + getVersionNumber()
                            }
                            sh "sh build-pipeline/buildscripts/move-artifacts-to-archive.sh $versionFolder $buildFolder $storageFolder $archivFolder"                    
                        }          
                    }
                }
                stage ('Create Git release') {
                    agent { label 'debian' }
                    when 
                    {
                        expression { currentBuild.result != 'FAILURE' && params.CREATE_RELEASE }
                    }
                    steps 
                    {
                        build job: 'monica.pipeline.release', propagate: true,
                                    parameters: [   booleanParam( name: 'DRAFT', value: params.DRAFT),
                                                    booleanParam( name: 'PRERELEASE', value: params.PRERELEASE),
                                                    string(name: 'MONICA_BUILD_NUMBER', value: env.BUILD_NUMBER)]
                    }
                }
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
def increaseVersionStr(doCommit, tagBuildParam, buildMessageParam, increaseVersionParam, credentials, author, email)
{
    def rootDir = pwd()
    def versionLib = load "${rootDir}/build-pipeline/buildscripts/version-lib.groovy"
    def versionStr = versionLib.incrementVersionFile(increaseVersionParam, "monica/src/resource/version.h")
    if (doCommit)
    {
        versionLib.commitVersionFileToGit(versionStr, "src/resource/version.h",  "github.com/zalf-rpm/monica", "monica", credentials, author, email)       
    }
    if (doCommit && tagBuildParam)
    {
        versionLib.createGitTag(versionStr, buildMessageParam,  "github.com/zalf-rpm/monica", "monica", credentials, author, email)   
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

// checkout git repository 
def checkoutGitRepository(repositoryName, cleanWorkspace, credentials)
{
    // cleanup workspace
    if (cleanWorkspace) { 
        if ( fileExists("$repositoryName") ) {
            deleteDirectory("$repositoryName")
        }
    }

    def outVarMap = checkout([$class: 'GitSCM', branches: [[name: '*/master']], 
    doGenerateSubmoduleConfigurations: false, 
    extensions: [   [$class: 'RelativeTargetDirectory', relativeTargetDir: repositoryName], 
                    [$class: 'LocalBranch', localBranch: "**"]], 
    submoduleCfg: [], 
    credentialsId: credentials,
    userRemoteConfigs: [[url: "https://github.com/zalf-rpm/$repositoryName"]]])

    return outVarMap
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
