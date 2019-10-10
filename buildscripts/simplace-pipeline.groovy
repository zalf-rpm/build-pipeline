pipeline {
  agent none
  parameters {
    string(defaultValue: "Version_4.3_final", 
        description: 'build verion from branch, or use enter "trunk"', 
        name: 'SIMPLACE_BRANCH')
    // push docker image on successfull build
    booleanParam(defaultValue: false, 
        description: 'Push/upload docker image (to https://hub.docker.com/r/zalfrpm)', 
        name: 'PUSH_DOCKER_IMAGE')
    // if PUSH_DOCKER_IMAGE is true, push as latest version 
    booleanParam(defaultValue: true, 
        description: 'Push docker image with Tag "latest" (zalfrpm/simplace-cluster:latest)', 
        name: 'LATEST')
    // if PUSH_DOCKER_IMAGE is true, push with current version number
    booleanParam(defaultValue: true, 
        description: 'push docker image with Tag "version number" (e.g. zalfrpm/monica-cluster:2.0.3.148)', 
        name: 'VERSION')
    booleanParam(defaultValue: false, 
        description: 'set java max heap size to 26G RAM! (HPC version only)', 
        name: 'HIGH_MEM_USAGE')
    // select workspace cleaning mode 
    // NO_CLEANUP may cause issues. Test only.
    choice(choices: ['CLEAN_GIT_CHECKOUT', 'NO_CLEANUP', 'CLEANUP_WORKSPACE'], 
    description: '''
CLEAN_GIT_CHECKOUT - will remove the checkout and build folders and build a new version
NO_CLEANUP - quick and dirty! rebuild. Do a git pull and rebuild. This is for testing only!!!
CLEANUP_WORKSPACE - wipe clean the workspace(including vcpkg) - Build will take long!''', 
        name: 'CLEANUP')
  }
  stages { 
      // build simplace jar on windows
    stage('BuildWindows') {
        agent { label 'windows' }
        environment {
            SVN_CREDS = credentials('simplace_run')
        }
        steps 
        {
            script {
                boolean doCleanupFirst = params.CLEANUP == 'CLEANUP_WORKSPACE' || params.CLEANUP == 'CLEAN_GIT_CHECKOUT'

                checkoutSVNRepository("lapclient", doCleanupFirst, "", "", "${params.SIMPLACE_BRANCH}")
                checkoutSVNRepository("simplace_core", doCleanupFirst, "", "", "${params.SIMPLACE_BRANCH}")
                checkoutSVNRepository("simplace_modules", doCleanupFirst, "", "", "${params.SIMPLACE_BRANCH}")
                checkoutSVNRepository("simplace_cloud", doCleanupFirst, "", "", "${params.SIMPLACE_BRANCH}")
                checkoutSVNRepository("simplace_run", doCleanupFirst, "${env.SVN_CREDS_USR}", "${env.SVN_CREDS_PSW}", "trunk")

                dir("lapclient")
                {
                    bat returnStatus: true, script: 'call console.bat'
                    bat returnStatus: true, script: 'xcopy ..\\simplace_core\\lib\\commons-logging-1.1.1.jar console\\lib\\ /Y /H'
                    bat returnStatus: true, script: 'xcopy ..\\simplace_cloud\\lib\\javax.servlet-api-3.0.1.jar console\\lib\\ /Y /H'
                    bat returnStatus: true, script: 'xcopy ..\\simplace_cloud\\lib\\webserver.jar console\\lib\\ /Y /H'
                }
                if (params.HIGH_MEM_USAGE) {
                    def CURRDir = pwd()
                    def file = new File("${CURRDir}/console/simplace")
                    def newConfig = file.text.replace('-Xmx10g', '-Xmx24g')
                    file.text = newConfig
                }
            }
        }
        post 
        {
            // store jar executables for next step 
            success 
            {
                dir('lapclient/console')
                {
                   stash excludes: 'simplace.exe', name: 'simplace_jar'                             
                }
            }
        }
    }
    stage('build-cluster-image') {
        agent { label 'dockerInstalled' }
        when 
        {
            expression { currentBuild.result != 'FAILURE' }
        }
        environment { 
            ARTIFACT_PATH = "simplace/artifact"
            def rootDir = pwd()
            TEST_PATH_WORK = "$rootDir/simplace/SIMPLACE_WORK"
            TEST_PATH_OUT = "$rootDir/simplace/out"
            TEST_PATH_DATA = "$rootDir/simplace/data"
            TEST_PATH_PROJECTS = "$rootDir/simplace/projects"
            SVN_CREDS = credentials('simplace_run')
            SIMPLACE_RUN_URL = "svn://svn.simplace.net/svn/simplace_run/trunk/simulation/SimulationExperimentTemplate"
        }            
        steps {
            checkoutGitRepository('build-pipeline', true, 'zalffpmbuild_basic', "master")
            // prepare test scenario
            sh "rm -rf $env.TEST_PATH_WORK"
            sh "mkdir -p $env.TEST_PATH_WORK"
            sh "rm -rf $env.TEST_PATH_OUT"
            sh "mkdir -p $env.TEST_PATH_OUT"
            sh "touch ${env.TEST_PATH_OUT}/myoutput.txt"
            sh "rm -rf $env.TEST_PATH_DATA"
            sh "mkdir -p $env.TEST_PATH_DATA"
            sh "touch ${env.TEST_PATH_DATA}/mydata.txt"
            sh "rm -rf $env.TEST_PATH_PROJECTS"
            sh "mkdir -p $env.TEST_PATH_PROJECTS"
            sh "touch ${env.TEST_PATH_PROJECTS}/myproject.txt"

            sh "svn checkout ${env.SIMPLACE_RUN_URL} ${env.TEST_PATH_WORK}/SimulationExperimentTemplate --username ${env.SVN_CREDS_USR} --password ${env.SVN_CREDS_PSW}"

            // extract executables
            sh "rm -rf $env.ARTIFACT_PATH"
            sh "mkdir -p $env.ARTIFACT_PATH"
            dir(env.ARTIFACT_PATH)
            {
                unstash "simplace_jar"
            }

            script {
                
                def VERSION_NUMBER = "${currentBuild.number}" // TODO: replace by a checked in number
                def dockerfilePath = './build-pipeline/docker/simplace-hpc'
                def DOCKER_TAG = VERSION_NUMBER
                if (params.SIMPLACE_BRANCH ==~ /Version_.*/)
                {
                    if (params.HIGH_MEM_USAGE) {
                        DOCKER_TAG = params.SIMPLACE_BRANCH - ~"Version_" + ".HM." + VERSION_NUMBER
                    } else {
                        DOCKER_TAG = params.SIMPLACE_BRANCH - ~"Version_" + "." + VERSION_NUMBER
                    }
                }


                sh "echo Docker Tag: $DOCKER_TAG"
                docker.withRegistry('', "zalffpm_docker_basic") {
                    def clusterImage = docker.build("zalfrpm/simplace-hpc:$DOCKER_TAG", "-f $dockerfilePath/Dockerfile --no-cache --build-arg EXECUTABLE_SOURCE=$env.ARTIFACT_PATH ." ) 
                    def SIMPLACE_WORKDIR = "/simplace/SIMPLACE_WORK"
                    def OUTDIR = "/outputs"
                    def DATADIR = "/data"
                    def PROJECTDIR = "/projects"

                    def SOLUTION = "SimulationExperimentTemplate/solution/Lintul5.sol.xml"
                    def PROJECT = "SimulationExperimentTemplate/project/Lintul5All.proj.xml"
                    def status = 1
                    clusterImage.inside("--mount type=bind,source=${env.TEST_PATH_WORK},target=${SIMPLACE_WORKDIR} --mount type=bind,source=${env.TEST_PATH_OUT},target=${OUTDIR} --mount type=bind,source=${env.TEST_PATH_DATA},target=${DATADIR} --mount type=bind,source=${env.TEST_PATH_PROJECTS},target=${PROJECTDIR}") {
                        status = sh returnStatus: true, script: "build-pipeline/docker/simplace-hpc/simplace_start.sh $SOLUTION $PROJECT true 1 8 false"
                    }
            
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

// checkout git repository 
def checkoutSVNRepository(repositoryName, cleanWorkspace, user, password, branch)
{
    // cleanup workspace
    if (cleanWorkspace) { 
        if ( fileExists("$repositoryName") ) {
            dir ("$repositoryName") {
                deleteDir()
            }
        }
    }
    print("checkout branch: $branch")

    def url = "svn://svn.simplace.net/svn/$repositoryName/branches/$branch"

    if (branch == "trunk") {
        url = "svn://svn.simplace.net/svn/$repositoryName/trunk"
    }
    if (user!= "" && password != "") {
        if (isUnix()) {
            sh "svn checkout ${url} ${repositoryName} --username ${user} --password ${password}"
        }
        else {
            bat "svn checkout ${url} ${repositoryName} --username ${user} --password ${password}"
        }
    } else {
        if (isUnix()) {
            sh "svn checkout ${url} ${repositoryName}"
        }
        else {
            bat "svn checkout ${url} ${repositoryName}"
        }
    }
    // may be... in a far future... someone fixes this plugin
    // def outVarMap = checkout([$class: 'SubversionSCM', 
    //       additionalCredentials: [], 
    //       excludedCommitMessages: '', 
    //       excludedRegions: '', 
    //       excludedRevprop: '', 
    //       excludedUsers: '', 
    //       filterChangelog: false, 
    //       ignoreDirPropChanges: false, 
    //       includedRegions: '', 
    //       locations: [[credentialsId: credentials, 
    //                    depthOption: 'infinity', 
    //                    ignoreExternalsOption: true, 
    //                    local: repositoryName, 
    //                    remote: url]], 
    //       workspaceUpdater: [$class: 'UpdateUpdater']])

}

// checkout git repository 
def checkoutGitRepository(repositoryName, cleanWorkspace, credentials, branch)
{
    // cleanup workspace
    if (cleanWorkspace) { 
        if ( fileExists("$repositoryName") ) {
            dir ("$repositoryName") {
                deleteDir()
            }
        }
    }
    print("checkout branch: $branch")

    def outVarMap = checkout([$class: 'GitSCM',
    branches: [[name: "$branch"]], 
    doGenerateSubmoduleConfigurations: false, 
    extensions: [   [$class: 'RelativeTargetDirectory', relativeTargetDir: repositoryName], 
    [$class: 'LocalBranch', localBranch: "**"]], 
    submoduleCfg: [], 
    userRemoteConfigs: [[url: "https://github.com/zalf-rpm/$repositoryName", credentialsId: credentials ]]])

    return outVarMap
}