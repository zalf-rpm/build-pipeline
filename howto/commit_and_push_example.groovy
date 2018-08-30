//
// example script for checkout from git master branch
// do some file changes on an existing file, 
// and commit these changes
// push changes with username:password authentication (your user needs push permission)
// this script contains some debug print output to better understand what is happening

pipeline {
    agent {label 'linux'}
    stages {   
        stage('stage') {
            environment 
            {
                reporsitory_Url = 'github.com/zalf-rpm/build-pipeline.git' // written without 'https://' - it will be added later
                checkoutFolder = 'build-pipeline' 
                credentials = 'zalffpmbuild_basic' // must be available thru jenkins
                
                fileName = 'committest.txt'
                filePath = 'build-pipeline/howto'
                
            }
            steps {
                script {
                    // cleanup left overs from previous builds
                    deleteDir()
                
                    def outVarMap = checkoutRepository(reporsitory_Url, checkoutFolder, credentials)
                    print (outVarMap)
                    autorEmail = outVarMap.GIT_AUTHOR_EMAIL // get default email from git plugin - as defined in jenkins configuration
                    autorName = outVarMap.GIT_AUTHOR_NAME // get default git user from git plugin - as defined in jenkins configuration
        
                    print("Email: " + autorEmail)   
                    print("Autor: " + autorName)

                    // use withCredentials to pass username and password
                    withCredentials([usernamePassword(credentialsId: credentials, passwordVariable: 'GIT_PASSWORD', usernameVariable: 'GIT_USERNAME')]) {
                        // switch to where the file is located, that needs to be changed
                        dir(filePath)
                        {
                            // read file
                            def test = readFile file: fileName
                            print ("$filename: $test")
                            // write file
                            writeFile file: fileName, text: "Buildnumber: $env.BUILD_NUMBER"
                            // read it again to seed if the output has changed 
                            def testafter = readFile file: fileName
                            print ("changed $filename: $testafter")
                            
                            def setAuthor = """git config --global user.name \"$autorName\" """
                            def setEmail = """git config --global user.email $autorEmail """
                            def gitCommitCmd = """git commit $fileName -m \"autocommit\" """

                            sh setAuthor
                            sh setEmail
                            sh script: gitCommitCmd
                        }
                        dir (checkoutFolder)
                        {
                            // echo current branch, which should be master
                            def branchName = sh returnStdout: true, script:"git branch"
                            print(branchName)

                            def pushToMaster = """git push https://${GIT_USERNAME}:${GIT_PASSWORD}@$reporsitory_Url master"""
                            sh script: pushToMaster
                        }

                    }
                }
            }
        }
    }
}

// checkout git repository <reporsitory_Url>
// into folder <checkoutFolder>
// use access credential id <credentials>
// returns map of git plugin variables and informaton about the checkout
def checkoutRepository(reporsitory_Url, checkoutFolder, credentials)
{
    // ! without "[$class: 'LocalBranch', localBranch: "**"]]," you will get a repository with a detached head when committing 
    def outVar = checkout([$class: 'GitSCM', branches: [[name: '*/master']], 
                    doGenerateSubmoduleConfigurations: false, 
                    extensions: [   [$class: 'RelativeTargetDirectory', relativeTargetDir: checkoutFolder], 
                                    [$class: 'LocalBranch', localBranch: "**"]], 
                    submoduleCfg: [], 
                    credentialsId: credentials,
                    userRemoteConfigs: [[url: "https://$reporsitory_Url"]]])
    return outVar
}

