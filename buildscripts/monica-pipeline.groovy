pipeline {
  agent none
  parameters {
    gitParameter name: 'BRANCH_MONICA',
                type: 'PT_BRANCH',
                defaultValue: 'origin/master',
                useRepository: '.*monica'
    gitParameter name: 'BRANCH_UTIL',
                type: 'PT_BRANCH',
                defaultValue: 'origin/master',
                useRepository: '.*util'
    gitParameter name: 'BRANCH_BUILD_PIPELINE',
                type: 'PT_BRANCH',
                defaultValue: 'origin/master',
                useRepository: '.*build-pipeline'
    gitParameter name: 'BRANCH_PARAMETER',
                type: 'PT_BRANCH',
                defaultValue: 'origin/master',
                useRepository: '.*monica-parameters'
    gitParameter name: 'BRANCH_CAPNPROTO',
                type: 'PT_BRANCH',
                defaultValue: 'origin/master',
                useRepository: '.*mas-infrastructure'

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
    // if PUSH_DOCKER_IMAGE is true, push as test version 
    booleanParam(defaultValue: false, 
        description: 'Push docker image with Tag "test" (zalfrpm/monica-cluster:test-2.0.3.148)', 
        name: 'TEST')
    // if PUSH_DOCKER_IMAGE is true, push with current version number
    booleanParam(defaultValue: true, 
        description: 'push docker image with Tag "version number" (e.g. zalfrpm/monica-cluster:2.0.3.148)', 
        name: 'VERSION')
  }
  stages {  
        stage('parallel stage') {
            parallel {
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
                            checkoutGitRepository('build-pipeline', doCleanupFirst,  "${params.BRANCH_BUILD_PIPELINE}")
                            checkoutGitRepository('monica', doCleanupFirst,  "${params.BRANCH_MONICA}")
                            checkoutGitRepository('util', doCleanupFirst,  "${params.BRANCH_UTIL}")
                            checkoutGitRepository('monica-parameters', doCleanupFirst,  "${params.BRANCH_PARAMETER}")
                            checkoutGitRepository('mas-infrastructure', doCleanupFirst,  "${params.BRANCH_CAPNPROTO}")                             
                        }

                        // create vcpkg package directory 
                        doVcpkgCheckout()               

                        // increase build version, but do not check-in
                        println('increase version number')
                        increaseVersionStr(false, false, "", params.INCREASE_VERSION, 'gitapitoken2', "", "", "")   
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
                stage('build-cluster-image') {
                    agent { label 'dockerInstalled' }
                    when 
                    {
                        expression { currentBuild.result != 'FAILURE' }
                    }  
                    steps {
                        checkoutGitRepository('build-pipeline', true,  "${params.BRANCH_BUILD_PIPELINE}")
                        checkoutGitRepository('monica', true,  "${params.BRANCH_MONICA}")

                        script {
                            def VERSION_NUMBER = increaseVersionStr(false, false, "", params.INCREASE_VERSION, 'gitapitoken2', "", "", "")  
                            def dockerfilePathMonica = './monica'

                            def DOCKER_TAG = VERSION_NUMBER
                            if (!(params.BRANCH_MONICA == "origin/master" || params.BRANCH_MONICA == "master"))
                            {
                                if (params.BRANCH_MONICA ==~ /origin\/.*/)
                                {
                                    DOCKER_TAG = params.BRANCH_MONICA - ~"origin/" + "." + VERSION_NUMBER
                                }
                            }
                            sh "echo Docker Tag: $DOCKER_TAG"

                            docker.withRegistry('', "zalffpm_docker_basic") {

                                def VERSION_MAYOR = "false"
                                def VERSION_MINOR = "false"
                                def VERSION_PATCH = "false"
                                if (params.INCREASE_VERSION == 'PATCH')
                                {
                                    VERSION_PATCH = "true"
                                } else if (params.INCREASE_VERSION == 'MINOR')
                                {
                                    VERSION_MINOR = "true"
                                } else if (params.INCREASE_VERSION == 'MAYOR')
                                {
                                    VERSION_MAYOR = "true"
                                }  

                                def clusterImage = docker.build("zalfrpm/monica-cluster:$DOCKER_TAG", "-f $dockerfilePathMonica/Dockerfile --no-cache --build-arg VERSION_MAYOR=${VERSION_MAYOR} --build-arg VERSION_MINOR=${VERSION_MINOR} --build-arg VERSION_PATCH=${VERSION_PATCH} ./monica" ) 

                                def dockerfilePathTest = './build-pipeline/docker/dotnet-producer-consumer'
                                def testImage = docker.build("dotnet-producer-consumer:$DOCKER_TAG", "-f $dockerfilePathTest/Dockerfile --no-cache .") 

                                def climateFilePath = pwd() + "/monica/installer/Hohenfinow2"
                                def outPath = pwd() + "/out"
                                sh "rm -rf ${outPath}"
                                sh "mkdir ${outPath}"
                                sh "echo ${climateFilePath}"
                                def status = 1
                                clusterImage.withRun("--env monica_instances=1 --mount type=bind,source=${climateFilePath},target=/monica_data/climate-data") { c ->
                                    testImage.inside("--env LINKED_MONICA_SERVICE=${c.id} --link ${c.id} --mount type=bind,source=${outPath},target=/out") {
                                        sh "echo linked ${c.id}"
                                        status = sh returnStatus: true, script: "build-pipeline/docker/dotnet-producer-consumer/start_producer_consumer.sh"
                                    }
                                }          
                                // if mode is test, ignore status result, just push
                                if (params.TEST) {
                                    // push image to docker
                                    if (params.PUSH_DOCKER_IMAGE) {
                                        clusterImage.push("test-$DOCKER_TAG") 
                                    }
                                }
                                else {
                                    if (status != 0) {
                                        currentBuild.result = 'FAILURE'
                                    }        
                                    else {
                                        // push image to docker
                                        if (params.PUSH_DOCKER_IMAGE) {
                                            if (params.LATEST) {
                                                clusterImage.push('latest')
                                            }
                                            if (params.VERSION) {
                                                clusterImage.push() 
                                            }
                                        }
                                    }
                                }
                            }
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
                    def outVarMap = checkoutGitRepository('monica', doCleanupFirst,  "${params.BRANCH_MONICA}")
                    // checkout build script
                    checkoutGitRepository('build-pipeline', doCleanupFirst, "${params.BRANCH_BUILD_PIPELINE}")

                    def branch = params.BRANCH_MONICA
                    if (params.BRANCH_MONICA ==~ /origin\/.*/)
                    {
                        branch = params.BRANCH_MONICA - ~"origin/"
                    }
                    // increase version, commit + push to git, <optional> create tag     
                    increaseVersionStr(true, params.TAG_BUILD, params.TAG_MESSAGE, params.INCREASE_VERSION, 'gitapitoken2', branch, outVarMap.GIT_AUTHOR_NAME, outVarMap.GIT_AUTHOR_EMAIL)             
                }
            }                
        }
        stage('parallel deployment') {
            parallel {
                stage('Create Git release') {
                    agent { label 'debian' }  
                    when 
                    {
                        expression { currentBuild.result != 'FAILURE' && params.CREATE_RELEASE }
                    }
                    environment {
                        apiUrl = "https://api.github.com"
                        baseUrl = "https://github.com"
                        owner = "zalf-rpm"
                        repository = "monica"
                        artifact_path = "artifact/monica/installer"
                        credentials = 'git-zalf-rpm'
                        commitHistory = 'patchhistory.txt'
                    }
                    steps {
                        // copy artifacts from another job
                        // create artifact path 
                        sh "rm -rf $env.artifact_path"
                        sh "mkdir -p $env.artifact_path"
                        // copy artifact step
                        dir(env.artifact_path)
                        {
                            unstash "win_installer"
                        }

                        script {

                            dir("$env.artifact_path")
                            {
                                def version = "1.1.1"
                                def buildNr = "123"
                                def uploadFileNames = []
                                files = findFiles(glob: 'MONICA-Setup-*.exe')
                                for (file in files)
                                {
                                    print ("file to upload: $file")
                                    uploadFileNames << (file.name)
                                    // extract version and build number from installer filename
                                    if (file.name ==~ /MONICA-Setup-.*-x64-64bit-build.*.exe/)
                                    {
                                        buildNr = file.name - ~"MONICA-Setup-.*-x64-64bit-build"
                                        buildNr = buildNr - ~".exe" 
                                        version = file.name - ~"MONICA-Setup-"
                                        version = version - ~"-x64-64bit-build.*.exe"
                                    }
                                }
                                // release tag
                                def tag = version + "." + buildNr
                                // release name
                                def releaseName = "MONICA $version"
                                print("TAG:" + tag)
                                print("Release Name:" + releaseName)
                                print ("upload files" + uploadFileNames)

                                // extract git commit log starting from last release tag
                                def log = extractLog(env.apiUrl, env.owner, env.repository, env.baseUrl, env.credentials)
                                writeFile file: commitHistory, text: log
                                uploadFileNames << commitHistory
                                // send git REST api request to create a release
                                def uploadURL = createRelease(  env.apiUrl, 
                                                                env.owner, 
                                                                env.repository, 
                                                                env.credentials, 
                                                                tag, releaseName, 
                                                                params.DRAFT, 
                                                                params.PRERELEASE, 
                                                                "ToDo: patch notes")
                                if (uploadURL != "none")
                                {
                                    // remove parameter description
                                    uploadURL = uploadURL - ~/\{.*\}/
                                    for (asset in uploadFileNames)
                                    {
                                        // upload asset file
                                        uploadReleaseAsset(uploadURL, env.credentials, asset)                                
                                    }
                                }
                            }
                        }
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
def increaseVersionStr(doCommit, tagBuildParam, buildMessageParam, increaseVersionParam, credentials, branch, author, email)
{
    def rootDir = pwd()
    def versionLib = load "${rootDir}/build-pipeline/buildscripts/version-lib.groovy"
    def versionStr = versionLib.incrementVersionFile(increaseVersionParam, "monica/src/resource/version.h")
    if (doCommit)
    {
        versionLib.commitVersionFileToGit(versionStr, "src/resource/version.h",  "github.com/zalf-rpm/monica", "monica", credentials, branch, author, email)       
    }
    if (doCommit && tagBuildParam)
    {
        versionLib.createGitTag(versionStr, buildMessageParam,  "github.com/zalf-rpm/monica", "monica", credentials, branch, author, email)   
    }     
    return versionStr
}

def getVersion(folder)
{
    version = 'none'
    dir(folder)
    {
        files = findFiles(glob: 'monica_*.tar.gz' );
        for (file in files)
        {
            version = getVersionNumberFromFilename(file.name)
        } 
    }
    return version
}

def getVersionNumberFromFilename(filename)
{
    version = filename - ~'monica_'
    version = version - ~'.tar.gz'
    return version
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
def checkoutGitRepository(repositoryName, cleanWorkspace, branch)
{
    // cleanup workspace
    if (cleanWorkspace) { 
        if ( fileExists("$repositoryName") ) {
            deleteDirectory("$repositoryName")
        }
    }
    print("checkout branch: $branch")

    def outVarMap = checkout([$class: 'GitSCM',
    branches: [[name: "$branch"]], 
    doGenerateSubmoduleConfigurations: false, 
    extensions: [   [$class: 'RelativeTargetDirectory', relativeTargetDir: repositoryName], 
    [$class: 'LocalBranch', localBranch: "**"]], 
    submoduleCfg: [], 
    userRemoteConfigs: [[url: "https://github.com/zalf-rpm/$repositoryName" ]]])

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

// apiUrl -> https://api.github.com
// owner -> zalf-rpm
// repository -> monica
def createRelease(apiUrl, owner, repository, credentials, tag, releaseName, draft, prerelease, releaseDescription)
{

    postContent =  """{
        "tag_name": "${tag}",
        "target_commitish": "master",
        "name": "${releaseName}",
        "body": "${releaseDescription}",
        "draft": ${draft},
        "prerelease": ${prerelease}
    }"""
    print (postContent)

    response = httpRequest (
                    httpMode: 'POST',
                    url:"$apiUrl/repos/$owner/$repository/releases",
                    authentication: credentials, 
                    contentType: 'APPLICATION_JSON', 
                    requestBody: postContent
                    )
    

    if (response.status == 201)
    {
        print (response.content)
        props = readJSON text: response.content  
        // extract upload url for assets
        return props['upload_url']
    }
    else
    {
        return "none"
    }
}

def uploadReleaseAsset(uploadURL, credentials, assetName)
{
    withCredentials ([usernamePassword(credentialsId: credentials, passwordVariable: 'password', usernameVariable: 'username')])
    {
        def upload_url = "$uploadURL?name=$assetName"
        def filename = "./" + assetName
        def returnVal = sh  returnStatus: true, 
                           script: """curl -i --data-binary @"$filename" -H "Content-Type: application/octet-stream" $upload_url -u $username:$password """
    }
}    

// apiUrl -> https://api.github.com
// repoOwner -> zalf-rpm
// repository -> monica
// baseUrl -> https://github.com/
def extractLog(apiUrl, repoOwner, repository, baseUrl, credentials)
{
    if ( fileExists("${repository}.git") ) {
        dir("${repository}.git") {
            deleteDir()
        }
    }
    // get latest release
    def response = httpRequest (
                    httpMode: 'GET',
                    url:"$apiUrl/repos/$repoOwner/$repository/releases/latest",
                    authentication: credentials)
    print (response.content)
    props = readJSON text: response.content  
    def oldTag = props['tag_name']


    // clone only version control informations, no files
    def bareClone = "git clone --bare $baseUrl/$repoOwner/$repository"

    // get log from tag to head, '%s' just the subject 
    def getLog = "git log ${oldTag}.. --format=%s"
    def out = ""
    if (isUnix())
    {
        sh bareClone                           
        dir("${repository}.git")
        {
            out = sh returnStdout: true, script: getLog                            
        }
    }
    else
    {
        bat bareClone
        dir("${repository}.git")
        {
            out = bat returnStdout: true, script: getLog                            
        }
    }
    print (out)
    return out
}