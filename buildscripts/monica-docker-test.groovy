pipeline {
    agent none
    stages {  
        stage('build-cluster-image') {
            agent { label 'dockerInstalled' }
            environment { 
                ARTIFACT_PATH = "monica/artifact"
                def rootDir = pwd()
                EXECUTABLE_SOURCE = "$rootDir/monica/monica-executables"
            }
            steps {
                checkoutGitRepository('build-pipeline', true)
                checkoutGitRepository('monica', true)
                checkoutGitRepository('monica-parameters', true)
                checkoutGitRepository('util', true)    

                // extract executables
                sh "rm -rf monica/artifact"
                sh "mkdir -p monica/artifact"

                step ([$class: 'CopyArtifact',
                        projectName: 'monica.pipeline',
                        filter: "deployartefact/monica_*.tar.gz",
                        target: env.ARTIFACT_PATH]);
                sh "sh build-pipeline/buildscripts/extract-monica-executables.sh $env.ARTIFACT_PATH/deployartefact $env.EXECUTABLE_SOURCE"

                script {
                    def VERSION_NUMBER = getVersion("$env.ARTIFACT_PATH/deployartefact"); 
                    def dockerfilePathMonica = './monica'

                    def clusterImage = docker.build("monica-cluster:$VERSION_NUMBER", "-f $dockerfilePathMonica/Dockerfile --build-arg EXECUTABLE_SOURCE=monica-executables/monica_$VERSION_NUMBER ./monica" ) 

                    def dockerfilePathTest = './build-pipeline/docker/dotnet-producer-consumer'
                    def testImage = docker.build("dotnet-producer-consumer:$VERSION_NUMBER", "-f $dockerfilePathTest/Dockerfile --build-arg EXECUTABLE_SOURCE=monica/monica-executables/monica_$VERSION_NUMBER .") 

                    def status = 1
                    clusterImage.withRun('--env monica_instances=1') { c ->
                        testImage.inside("--env LINKED_MONICA_SERVICE=${c.id} --link ${c.id}") {
                            sh "echo linked ${c.id}"
                            status = sh returnStatus: true, script: "build-pipeline/docker/dotnet-producer-consumer/start_producer_consumer.sh"
                        }
                    }                
                    if (status != 0) {
                        currentBuild.result = 'FAILURE'
                    }        
                }                     
            }
        }
    }
}

// checkout git repository 
def checkoutGitRepository(repositoryName, cleanWorkspace)
{
    // cleanup workspace
    if (cleanWorkspace) { 
        if ( fileExists("$repositoryName") ) {
            deleteDirectory("$repositoryName")
        }
    }

    checkout([$class: 'GitSCM', branches: [[name: '*/master']], 
    doGenerateSubmoduleConfigurations: false, 
    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "$repositoryName"]], 
    submoduleCfg: [], 
    credentialsId: 'zalffpmbuild',
    userRemoteConfigs: [[url: "https://github.com/zalf-rpm/$repositoryName"]]])
}

def getBuildNumber()
{
    def rootDir = pwd()
    def versionLib = load "${rootDir}/build-pipeline/buildscripts/version-lib.groovy"
    def buildNumber = versionLib.getVersionFromVersionFile(true, false, "monica/src/resource/version.h")
    return buildNumber
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

// get full version number from version.h 2.0.12.1235
def getFullVersionNumber()
{
    def rootDir = pwd()
    def versionLib = load "${rootDir}/build-pipeline/buildscripts/version-lib.groovy"
    def fullbuildNumber = versionLib.getVersionFromVersionFile(false, false, "monica/src/resource/version.h")
    return fullbuildNumber
}